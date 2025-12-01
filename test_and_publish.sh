#!/usr/bin/env bash
#
# Build-Verify-Publish Pipeline for vLLM CPU wheels
#
# This script implements a safe publishing workflow:
# 1. Build wheel(s)
# 2. Verify wheel integrity (ZIP, structure, metadata, twine check)
# 3. If verification fails, rebuild and verify again
# 4. Publish to production PyPI
# 5. Create GitHub release (only if PyPI publish succeeds)
#
# Usage:
#   ./test_and_publish.sh [OPTIONS]
#
# Options:
#   --variant=NAME           Variant to build
#                            Values: noavx512, avx512, avx512vnni, avx512bf16, amxbf16, all
#                            Default: noavx512 (maps to vllm-cpu package)
#
#   --vllm-versions=VERSION  vLLM version(s) to build
#                            Accepts: single (0.11.0) or multiple (0.10.0,0.10.1,0.11.0)
#                            Default: none (required)
#
#   --python-versions=3.X    Python version(s) to build
#                            Accepts: single (3.12), multiple (3.10,3.11,3.12), range (3.10-3.13),
#                            or "auto" to detect from vLLM's pyproject.toml
#                            Default: 3.13
#
#   --builder=TYPE           Build method
#                            Values: native, docker
#                            Default: native
#                              native: Build directly on host system using build_wheels.sh
#                              docker: Build in Docker using docker-buildx.sh
#
#   --platform=PLATFORM      Target platform for docker builds
#                            Values: auto, linux/amd64, linux/arm64
#                            Default: auto
#                            Note: Only used when --builder=docker
#
#   --dist-dir=DIR           Output directory for wheels
#                            Default: dist
#
#   --max-jobs=N             Parallel build jobs
#                            Default: CPU count (nproc)
#
#   --skip-build             Skip building, use existing wheels in --dist-dir
#                            Default: disabled (builds wheels)
#
#   --skip-github            Skip GitHub release creation
#                            Default: disabled (creates GitHub releases)
#
#   --update-readme          Update README inside existing wheels (no rebuild)
#                            Extracts wheel, replaces README, repackages
#                            Does NOT upload to PyPI - only updates local wheels
#                            Useful for updating badges/docs without full rebuild
#
#   --version-suffix=SUFFIX  Add version suffix for re-uploading (e.g., .post1, .post2, .dev1)
#                            Required when re-uploading previously deleted wheels
#                            PyPI has an immutable filename policy - once used, cannot be re-uploaded
#                            Only .postN and .devN are valid (PEP 440 compliant)
#                            Example: --version-suffix=.post1 turns 0.11.0 into 0.11.0.post1
#
#   --dry-run                Show what would be done without doing it
#                            Default: disabled
#
#   --help                   Show this help
#
# Environment Variables:
#   PYPI_TOKEN or PYPI_API_TOKEN  Default PyPI API token (fallback for all variants)
#   PYPI_TOKEN_CPU                Token for vllm-cpu package
#   PYPI_TOKEN_AVX512             Token for vllm-cpu-avx512 package
#   PYPI_TOKEN_AVX512VNNI         Token for vllm-cpu-avx512vnni package
#   PYPI_TOKEN_AVX512BF16         Token for vllm-cpu-avx512bf16 package
#   PYPI_TOKEN_AMXBF16            Token for vllm-cpu-amxbf16 package
#   DEBUG=1                       Enable debug logging
#
# Examples:
#   # Build and publish vllm-cpu for multiple Python versions
#   ./test_and_publish.sh --variant=noavx512 --vllm-versions=0.11.0 --python-versions=3.10-3.13
#
#   # Build all variants
#   ./test_and_publish.sh --variant=all --vllm-versions=0.11.0
#
#   # Dry run to see what would be built/published
#   ./test_and_publish.sh --variant=avx512bf16 --vllm-versions=0.11.0,0.11.1 --dry-run
#
#   # Use existing wheels, skip build
#   ./test_and_publish.sh --skip-build --vllm-versions=0.11.0
#
#   # Update README in existing wheels without rebuilding
#   ./test_and_publish.sh --update-readme --variant=all --vllm-versions=0.11.0
#
#   # Re-upload previously deleted wheel with .rebuild1 suffix
#   ./test_and_publish.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.rebuild1
#
#   # Auto-detect Python versions from vLLM's pyproject.toml
#   ./test_and_publish.sh --variant=noavx512 --vllm-versions=0.11.2 --python-versions=auto
#
# Multi-wheel Support:
#   When --variant=all, all 5 CPU variants will be built, verified, and published.
#   GitHub releases will be created for each wheel (unless --skip-github is specified).

set -euo pipefail

# Bash version check
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: This script requires Bash 4.0 or higher" >&2
    exit 1
fi

# Readonly constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly SCRIPT_VERSION="3.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'

# Load .env file if it exists (for PYPI_TOKEN, etc.)
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    # shellcheck source=/dev/null
    set -a  # Export all variables
    source "$SCRIPT_DIR/.env"
    set +a

    # Support both naming conventions: PYPI_API_TOKEN and PYPI_TOKEN
    if [[ -z "${PYPI_TOKEN:-}" ]] && [[ -n "${PYPI_API_TOKEN:-}" ]]; then
        export PYPI_TOKEN="$PYPI_API_TOKEN"
    fi
fi

# Configuration
AUTO_INSTALL=1  # Auto-install missing dependencies by default
VARIANT="noavx512"  # User-facing short name, converted to vllm-cpu internally
VLLM_VERSION=""
PYTHON_VERSION="3.13"
declare -a PYTHON_VERSIONS=()  # Array of Python versions (populated from PYTHON_VERSION)
VERSION_SUFFIX=""  # Optional version suffix (e.g., ".post1", ".post2") for re-uploads
BUILDER="native"  # Build method: native or docker
PLATFORM="auto"   # Target platform for docker builds
DIST_DIR="dist"   # Output directory for wheels
MAX_JOBS=$(nproc)
SKIP_BUILD=0
SKIP_GITHUB=0
UPDATE_README=0   # Update README in existing wheels (no rebuild, no upload)
DRY_RUN=0

# Derived values
WHEEL_PATH=""
PACKAGE_NAME=""
DETECTED_VERSION=""

# Multi-wheel support
declare -a WHEEL_PATHS=()
declare -a PACKAGE_NAMES=()
declare -a DETECTED_VERSIONS=()

# Logging functions
log_info() { echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${GREEN}[SUCCESS]${NC} $*" >&2; }
log_warning() { echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${YELLOW}[WARNING]${NC} $*" >&2; }
log_error() { echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${CYAN}[STEP]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] [DEBUG] $*" >&2 || true; }

# Validate Python version format
validate_python_version() {
    local version="$1"
    if [[ ! "$version" =~ ^3\.(9|1[0-9])$ ]]; then
        log_error "Invalid Python version: $version (must be 3.9-3.19)"
        return 1
    fi
    return 0
}

# Parse --python-versions parameter (supports comma-separated list, range, or "auto")
# When "auto" is specified, Python versions will be detected from vLLM's pyproject.toml
parse_python_versions() {
    local input="$1"
    PYTHON_VERSIONS=()  # Clear array

    # Check for "auto" mode - defer to vLLM's requires-python
    if [[ "$input" == "auto" ]]; then
        log_info "Python version auto-detection enabled - will detect from vLLM's pyproject.toml"
        PYTHON_VERSIONS=("auto")
        return 0
    fi

    # Check if it's a range (e.g., "3.9-3.13")
    if [[ "$input" =~ ^3\.([0-9]+)-3\.([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"

        if [[ $start -gt $end ]]; then
            log_error "Invalid range: start version must be <= end version"
            return 1
        fi

        log_info "Using Python 3.$start through 3.$end"
        for ((i=start; i<=end; i++)); do
            PYTHON_VERSIONS+=("3.$i")
        done
    else
        # Comma-separated list (e.g., "3.9,3.10,3.11")
        IFS=',' read -ra versions <<< "$input"
        for ver in "${versions[@]}"; do
            ver=$(echo "$ver" | tr -d ' ')  # Remove whitespace
            if ! validate_python_version "$ver"; then
                return 1
            fi
            PYTHON_VERSIONS+=("$ver")
        done
    fi

    log_info "Python versions for testing: ${PYTHON_VERSIONS[*]}"
    return 0
}

# Get supported Python versions for a specific vLLM version
# Automatically fetches requires-python from vLLM's pyproject.toml for that version
# Returns: space-separated list of supported Python versions
#
# How it works:
#   1. Fetches pyproject.toml from GitHub for the specific vLLM version tag
#   2. Parses the requires-python field (e.g., ">=3.10,<3.14")
#   3. Filters requested Python versions against this constraint
#   4. Falls back to hardcoded defaults if fetch fails
#
get_supported_python_versions() {
    local vllm_ver="$1"
    shift
    local requested_versions=("$@")
    local supported_versions=()

    # Try to fetch requires-python from upstream vLLM for this version
    local requires_python=""
    local pyproject_url="https://raw.githubusercontent.com/vllm-project/vllm/v${vllm_ver}/pyproject.toml"

    # Fetch and parse requires-python (with timeout and silent failure)
    if command -v curl &>/dev/null; then
        local pyproject_content
        pyproject_content=$(curl -sfL --max-time 5 "$pyproject_url" 2>/dev/null || echo "")
        if [[ -n "$pyproject_content" ]]; then
            # Extract requires-python = ">=3.X,<3.Y" or requires-python = ">=3.X"
            requires_python=$(echo "$pyproject_content" | grep -E '^requires-python\s*=' | head -1 | sed 's/.*"\(.*\)".*/\1/' | tr -d ' ')
        fi
    fi

    # If fetch failed, use hardcoded fallback based on known vLLM history
    if [[ -z "$requires_python" ]]; then
        log_debug "Could not fetch requires-python for vLLM $vllm_ver, using fallback"
        # Parse vLLM version for fallback logic
        local major minor patch
        IFS='.' read -r major minor patch _ <<< "$vllm_ver"
        patch="${patch:-0}"

        # Fallback: Python 3.13 added in 0.10.2
        if [[ "$major" -eq 0 ]] && [[ "$minor" -lt 10 ]]; then
            requires_python=">=3.10,<3.13"
        elif [[ "$major" -eq 0 ]] && [[ "$minor" -eq 10 ]] && [[ "$patch" -lt 2 ]]; then
            requires_python=">=3.10,<3.13"
        else
            requires_python=">=3.10,<3.14"  # Default for newer versions
        fi
    fi

    log_debug "vLLM $vllm_ver requires-python: $requires_python"

    # Parse the constraint to extract min and max Python versions
    local min_py="" max_py=""

    # Extract minimum (>=3.X or >3.X)
    if [[ "$requires_python" =~ \>=([0-9]+\.[0-9]+) ]]; then
        min_py="${BASH_REMATCH[1]}"
    elif [[ "$requires_python" =~ \>([0-9]+\.[0-9]+) ]]; then
        # >3.10 means 3.11+, but we'll just use the next minor for simplicity
        local tmp="${BASH_REMATCH[1]}"
        local tmp_minor="${tmp#*.}"
        min_py="3.$((tmp_minor + 1))"
    fi

    # Extract maximum (<3.X or <=3.X)
    if [[ "$requires_python" =~ \<([0-9]+\.[0-9]+) ]]; then
        max_py="${BASH_REMATCH[1]}"
    elif [[ "$requires_python" =~ \<=([0-9]+\.[0-9]+) ]]; then
        # <=3.13 means 3.13 is included, so max is 3.14
        local tmp="${BASH_REMATCH[1]}"
        local tmp_minor="${tmp#*.}"
        max_py="3.$((tmp_minor + 1))"
    fi

    # Default min/max if not specified
    min_py="${min_py:-3.10}"
    max_py="${max_py:-3.99}"  # No upper limit if not specified

    local min_minor="${min_py#*.}"
    local max_minor="${max_py#*.}"

    # Filter requested versions
    for py_ver in "${requested_versions[@]}"; do
        local py_minor="${py_ver#*.}"

        if [[ "$py_minor" -ge "$min_minor" ]] && [[ "$py_minor" -lt "$max_minor" ]]; then
            supported_versions+=("$py_ver")
        else
            log_warning "Skipping Python $py_ver for vLLM $vllm_ver (requires-python: $requires_python)"
        fi
    done

    # Return the filtered versions
    echo "${supported_versions[*]}"
}

# Get all supported Python versions for a vLLM version (for --python-versions=auto mode)
# Unlike get_supported_python_versions which filters, this returns ALL versions vLLM supports
# Returns: space-separated list of all supported Python versions
get_auto_python_versions() {
    local vllm_ver="$1"

    # Try to fetch requires-python from upstream vLLM for this version
    local requires_python=""
    local pyproject_url="https://raw.githubusercontent.com/vllm-project/vllm/v${vllm_ver}/pyproject.toml"

    log_info "Auto-detecting Python versions for vLLM $vllm_ver..."

    # Fetch and parse requires-python (with timeout and silent failure)
    if command -v curl &>/dev/null; then
        local pyproject_content
        pyproject_content=$(curl -sfL --max-time 10 "$pyproject_url" 2>/dev/null || echo "")
        if [[ -n "$pyproject_content" ]]; then
            # Extract requires-python = ">=3.X,<3.Y" or requires-python = ">=3.X"
            requires_python=$(echo "$pyproject_content" | grep -E '^requires-python\s*=' | head -1 | sed 's/.*"\(.*\)".*/\1/' | tr -d ' ')
        fi
    fi

    # If fetch failed, error out - we need accurate Python version info
    if [[ -z "$requires_python" ]]; then
        log_error "Could not fetch requires-python for vLLM $vllm_ver from GitHub"
        log_error "URL attempted: $pyproject_url"
        log_error "Please check network connectivity or specify --python-versions explicitly"
        echo ""  # Return empty to signal failure
        return 1
    fi

    log_info "vLLM $vllm_ver requires-python: $requires_python"

    # Parse the constraint to extract min and max Python versions
    local min_py="" max_py=""

    # Extract minimum (>=3.X or >3.X)
    if [[ "$requires_python" =~ \>=([0-9]+\.[0-9]+) ]]; then
        min_py="${BASH_REMATCH[1]}"
    elif [[ "$requires_python" =~ \>([0-9]+\.[0-9]+) ]]; then
        local tmp="${BASH_REMATCH[1]}"
        local tmp_minor="${tmp#*.}"
        min_py="3.$((tmp_minor + 1))"
    fi

    # Extract maximum (<3.X or <=3.X)
    if [[ "$requires_python" =~ \<([0-9]+\.[0-9]+) ]]; then
        max_py="${BASH_REMATCH[1]}"
    elif [[ "$requires_python" =~ \<=([0-9]+\.[0-9]+) ]]; then
        local tmp="${BASH_REMATCH[1]}"
        local tmp_minor="${tmp#*.}"
        max_py="3.$((tmp_minor + 1))"
    fi

    # Validate we got both min and max
    if [[ -z "$min_py" ]]; then
        log_error "Could not parse minimum Python version from: $requires_python"
        echo ""
        return 1
    fi
    # If no max specified, use a reasonable upper bound (current Python + 1)
    max_py="${max_py:-3.15}"

    local min_minor="${min_py#*.}"
    local max_minor="${max_py#*.}"

    # Generate all versions in range (max is exclusive)
    local versions=()
    for ((i=min_minor; i<max_minor; i++)); do
        versions+=("3.$i")
    done

    # Build space-separated string explicitly
    local version_str="${versions[*]}"
    log_info "Auto-detected Python versions for vLLM $vllm_ver: $version_str (${#versions[@]} versions)"

    # Return space-separated versions on a single line
    printf '%s\n' "$version_str"
}

# Check if a variant supports a given platform architecture
# Returns 0 (true) if variant supports the platform, 1 (false) otherwise
# Args:
#   $1: variant name (e.g., "vllm-cpu", "vllm-cpu-avx512")
#   $2: platform (e.g., "linux/amd64", "linux/arm64", "x86_64", "aarch64")
#
variant_supports_platform() {
    local variant="$1"
    local platform="$2"

    # Normalize variant name to full form
    case "$variant" in
        noavx512) variant="vllm-cpu" ;;
        avx512) variant="vllm-cpu-avx512" ;;
        avx512vnni) variant="vllm-cpu-avx512vnni" ;;
        avx512bf16) variant="vllm-cpu-avx512bf16" ;;
        amxbf16) variant="vllm-cpu-amxbf16" ;;
    esac

    # Normalize platform to architecture
    local arch=""
    case "$platform" in
        linux/amd64|x86_64|amd64) arch="x86_64" ;;
        linux/arm64|aarch64|arm64) arch="aarch64" ;;
        auto|"") return 0 ;;  # Auto means any platform is ok
        all) return 0 ;;  # All platforms means variant should be checked individually
        *)
            log_warning "Unknown platform: $platform, assuming supported"
            return 0
            ;;
    esac

    # Get supported platforms from build_config.json
    local platforms_json
    platforms_json=$(jq -r ".builds.\"${variant}\".platforms // []" "$SCRIPT_DIR/build_config.json" 2>/dev/null)

    if [[ -z "$platforms_json" ]] || [[ "$platforms_json" == "[]" ]] || [[ "$platforms_json" == "null" ]]; then
        # If no platforms defined, assume x86_64 only for safety
        [[ "$arch" == "x86_64" ]] && return 0 || return 1
    fi

    # Check if architecture is in the platforms array
    if echo "$platforms_json" | jq -e ". | index(\"$arch\")" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Filter variants array by platform
# Returns variants that support the given platform
# Args:
#   $1: platform (e.g., "linux/amd64", "linux/arm64")
#   $@: variants to filter
#
filter_variants_by_platform() {
    local platform="$1"
    shift
    local variants=("$@")
    local filtered=()

    # If platform is auto or empty, return all variants
    if [[ "$platform" == "auto" ]] || [[ -z "$platform" ]]; then
        echo "${variants[*]}"
        return
    fi

    for variant in "${variants[@]}"; do
        if variant_supports_platform "$variant" "$platform"; then
            filtered+=("$variant")
        else
            log_info "Skipping $variant for platform $platform (not supported)"
        fi
    done

    echo "${filtered[*]}"
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Get sudo command if available and needed
get_sudo_cmd() {
    if [[ $EUID -eq 0 ]]; then
        echo ""
    elif command -v sudo &>/dev/null; then
        echo "sudo"
    else
        echo ""
    fi
}

# Install Python tools (twine, build, wheel, uv)
install_python_tools() {
    log_info "Installing Python tools (twine, build, wheel)..."

    # Try pip first
    if command -v pip &>/dev/null; then
        pip install --user twine build wheel 2>/dev/null && return 0
    fi

    # Try pip3
    if command -v pip3 &>/dev/null; then
        pip3 install --user twine build wheel 2>/dev/null && return 0
    fi

    # Try uv if available
    if command -v uv &>/dev/null; then
        uv pip install twine build wheel 2>/dev/null && return 0
    fi

    log_error "Failed to install Python tools"
    return 1
}

# Install uv package manager
install_uv() {
    log_info "Installing uv package manager..."

    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        export PATH="$HOME/.cargo/bin:$PATH"
        log_success "uv installed successfully"
        return 0
    else
        log_error "Failed to install uv"
        return 1
    fi
}

# Install GitHub CLI
install_gh() {
    local distro="$1"
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    log_info "Installing GitHub CLI..."

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            # Add GitHub CLI repository
            $sudo_cmd mkdir -p -m 755 /etc/apt/keyrings 2>/dev/null || true
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $sudo_cmd tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
            $sudo_cmd chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $sudo_cmd tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y gh
            ;;
        fedora)
            $sudo_cmd dnf install -y gh
            ;;
        centos|rhel|rocky|almalinux)
            $sudo_cmd yum install -y gh 2>/dev/null || {
                # Manual install for older systems
                curl -fsSL https://github.com/cli/cli/releases/download/v2.40.1/gh_2.40.1_linux_amd64.tar.gz | tar xz
                $sudo_cmd mv gh_*/bin/gh /usr/local/bin/
                rm -rf gh_*
            }
            ;;
        arch|manjaro)
            $sudo_cmd pacman -Sy --noconfirm github-cli
            ;;
        opensuse*|sles)
            $sudo_cmd zypper install -y gh
            ;;
        *)
            log_warning "Cannot install GitHub CLI for $distro"
            log_info "Install manually from: https://cli.github.com/"
            return 1
            ;;
    esac

    log_success "GitHub CLI installed successfully"
}

# Install jq
install_jq() {
    local distro="$1"
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    log_info "Installing jq..."

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y jq
            ;;
        fedora)
            $sudo_cmd dnf install -y jq
            ;;
        centos|rhel|rocky|almalinux)
            $sudo_cmd yum install -y jq
            ;;
        arch|manjaro)
            $sudo_cmd pacman -Sy --noconfirm jq
            ;;
        opensuse*|sles)
            $sudo_cmd zypper install -y jq
            ;;
        *)
            log_error "Unsupported distribution for jq installation: $distro"
            return 1
            ;;
    esac

    log_success "jq installed successfully"
}

# Install curl
install_curl() {
    local distro="$1"
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    log_info "Installing curl..."

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y curl
            ;;
        fedora)
            $sudo_cmd dnf install -y curl
            ;;
        centos|rhel|rocky|almalinux)
            $sudo_cmd yum install -y curl
            ;;
        arch|manjaro)
            $sudo_cmd pacman -Sy --noconfirm curl
            ;;
        opensuse*|sles)
            $sudo_cmd zypper install -y curl
            ;;
        *)
            log_error "Unsupported distribution for curl installation: $distro"
            return 1
            ;;
    esac

    log_success "curl installed successfully"
}

# Install git
install_git() {
    local distro="$1"
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    log_info "Installing git..."

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y git
            ;;
        fedora)
            $sudo_cmd dnf install -y git
            ;;
        centos|rhel|rocky|almalinux)
            $sudo_cmd yum install -y git
            ;;
        arch|manjaro)
            $sudo_cmd pacman -Sy --noconfirm git
            ;;
        opensuse*|sles)
            $sudo_cmd zypper install -y git
            ;;
        *)
            log_error "Unsupported distribution for git installation: $distro"
            return 1
            ;;
    esac

    log_success "git installed successfully"
}

# Check all dependencies and install if missing
check_and_install_dependencies() {
    log_step "Checking dependencies..."

    local distro
    distro=$(detect_distro)
    log_info "Detected distribution: $distro"

    local missing_deps=()

    # Check curl (needed for API calls and downloads)
    if ! command -v curl &>/dev/null; then
        log_warning "curl is not installed"
        missing_deps+=("curl")
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            install_curl "$distro" || log_warning "Failed to install curl"
        fi
    else
        log_success "curl: $(curl --version 2>/dev/null | head -1)"
    fi

    # Check git
    if ! command -v git &>/dev/null; then
        log_warning "git is not installed"
        missing_deps+=("git")
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            install_git "$distro" || log_warning "Failed to install git"
        fi
    else
        log_success "git: $(git --version 2>/dev/null)"
    fi

    # Check jq
    if ! command -v jq &>/dev/null; then
        log_warning "jq is not installed"
        missing_deps+=("jq")
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            install_jq "$distro" || log_warning "Failed to install jq"
        fi
    else
        log_success "jq: $(jq --version 2>/dev/null)"
    fi

    # Check zip (needed for --update-readme)
    if ! command -v zip &>/dev/null; then
        log_warning "zip is not installed (needed for --update-readme)"
        missing_deps+=("zip")
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            case "$distro" in
                debian|ubuntu) sudo apt-get install -y zip >/dev/null 2>&1 || log_warning "Failed to install zip" ;;
                fedora|rhel|centos) sudo dnf install -y zip >/dev/null 2>&1 || log_warning "Failed to install zip" ;;
                arch) sudo pacman -S --noconfirm zip >/dev/null 2>&1 || log_warning "Failed to install zip" ;;
            esac
        fi
    else
        log_success "zip: $(zip --version 2>/dev/null | head -1)"
    fi

    # Check unzip (needed for --update-readme)
    if ! command -v unzip &>/dev/null; then
        log_warning "unzip is not installed (needed for --update-readme)"
        missing_deps+=("unzip")
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            case "$distro" in
                debian|ubuntu) sudo apt-get install -y unzip >/dev/null 2>&1 || log_warning "Failed to install unzip" ;;
                fedora|rhel|centos) sudo dnf install -y unzip >/dev/null 2>&1 || log_warning "Failed to install unzip" ;;
                arch) sudo pacman -S --noconfirm unzip >/dev/null 2>&1 || log_warning "Failed to install unzip" ;;
            esac
        fi
    else
        log_success "unzip: $(unzip -v 2>/dev/null | head -1)"
    fi

    # Check uv (optional but recommended)
    if ! command -v uv &>/dev/null; then
        log_warning "uv is not installed (optional, but recommended)"
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            install_uv || log_warning "Failed to install uv (builds will use pip instead)"
        fi
    else
        log_success "uv: $(uv --version 2>/dev/null)"
    fi

    # Check twine
    if ! command -v twine &>/dev/null; then
        log_warning "twine is not installed"
        missing_deps+=("twine")
        if [[ $AUTO_INSTALL -eq 1 ]]; then
            install_python_tools || log_warning "Failed to install Python tools"
        fi
    else
        log_success "twine: $(twine --version 2>/dev/null | head -1)"
    fi

    # Check gh (optional - for GitHub releases)
    if ! command -v gh &>/dev/null; then
        log_warning "GitHub CLI (gh) is not installed (optional - needed for GitHub releases)"
        if [[ $AUTO_INSTALL -eq 1 ]] && [[ $SKIP_GITHUB -eq 0 ]]; then
            install_gh "$distro" || log_warning "Failed to install GitHub CLI (GitHub releases will be skipped)"
        fi
    else
        log_success "gh: $(gh --version 2>/dev/null | head -1)"
    fi

    # Final check
    local critical_missing=0

    if ! command -v curl &>/dev/null; then
        log_error "curl is required but not installed"
        critical_missing=1
    fi

    if ! command -v git &>/dev/null; then
        log_error "git is required but not installed"
        critical_missing=1
    fi

    if ! command -v twine &>/dev/null; then
        log_error "twine is required but not installed"
        log_info "Install with: pip install twine"
        critical_missing=1
    fi

    if [[ $critical_missing -eq 1 ]]; then
        log_error "Critical dependencies are missing"
        return 1
    fi

    log_success "All critical dependencies are installed"
    return 0
}

# Normalize variant name (convert short names to full vllm-cpu-* format)
normalize_variant() {
    local input_variant="$1"

    case "$input_variant" in
        noavx512)
            echo "vllm-cpu"
            ;;
        avx512)
            echo "vllm-cpu-avx512"
            ;;
        avx512vnni)
            echo "vllm-cpu-avx512vnni"
            ;;
        avx512bf16)
            echo "vllm-cpu-avx512bf16"
            ;;
        amxbf16)
            echo "vllm-cpu-amxbf16"
            ;;
        all)
            echo "all"
            ;;
        # Allow full names too
        vllm-cpu|vllm-cpu-avx512|vllm-cpu-avx512vnni|vllm-cpu-avx512bf16|vllm-cpu-amxbf16)
            echo "$input_variant"
            ;;
        *)
            log_error "Invalid variant: $input_variant"
            log_error "Valid variants: noavx512, avx512, avx512vnni, avx512bf16, amxbf16, all"
            return 1
            ;;
    esac
}

# Cleanup function
cleanup() {
    local exit_code=$?
    exit "$exit_code"
}
trap cleanup EXIT ERR INT TERM

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --variant=*)
                local input_variant="${1#*=}"
                VARIANT=$(normalize_variant "$input_variant") || exit 1
                shift
                ;;
            --vllm-version=*|--vllm-versions=*)
                VLLM_VERSION="${1#*=}"
                shift
                ;;
            --python-version=*|--python-versions=*)
                PYTHON_VERSION="${1#*=}"
                shift
                ;;
            --builder=*)
                BUILDER="${1#*=}"
                if [[ "$BUILDER" != "native" ]] && [[ "$BUILDER" != "docker" ]]; then
                    log_error "Invalid builder: $BUILDER (must be 'native' or 'docker')"
                    exit 1
                fi
                shift
                ;;
            --platform=*)
                PLATFORM="${1#*=}"
                shift
                ;;
            --dist-dir=*)
                DIST_DIR="${1#*=}"
                shift
                ;;
            --max-jobs=*)
                MAX_JOBS="${1#*=}"
                shift
                ;;
            --skip-build)
                SKIP_BUILD=1
                shift
                ;;
            --skip-github)
                SKIP_GITHUB=1
                shift
                ;;
            --update-readme)
                UPDATE_README=1
                log_info "README update mode enabled - will update existing wheels (no rebuild, no upload)"
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --version-suffix=*)
                VERSION_SUFFIX="${1#*=}"
                # Validate suffix format (must start with . and be .postN or .devN format)
                # Note: Only .post and .dev are PEP 440 compliant for PyPI uploads
                if ! [[ "$VERSION_SUFFIX" =~ ^\.(post|dev)[0-9]+$ ]]; then
                    log_error "Invalid version suffix: $VERSION_SUFFIX"
                    log_info "Suffix must be .postN or .devN format (e.g., .post1, .post2, .dev1)"
                    log_info "Note: Only .post and .dev are PEP 440 compliant for PyPI uploads"
                    exit 1
                fi
                log_info "Version suffix enabled: $VERSION_SUFFIX"
                shift
                ;;
            --help)
                grep '^#' "$0" | grep -v '#!/' | sed 's/^# //'
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Build wheel using native or docker builder
# Skips build if wheel already exists locally (unless --skip-build is used to skip entirely)
build_wheel() {
    if [[ $SKIP_BUILD -eq 1 ]]; then
        log_info "Skipping build (--skip-build specified)"
        return 0
    fi

    # Check if we actually need to build (based on pre-flight check)
    if [[ ${#BUILDS_NEEDED[@]} -eq 0 ]]; then
        log_info "No builds needed - all wheels already exist locally"
        return 0
    fi

    log_info "Building ${#BUILDS_NEEDED[@]} wheel(s) for variant: $VARIANT (using $BUILDER builder)"

    # For builds, we need to determine which specific versions/python combos to build
    # Extract unique variant+version combinations that need building
    local versions_to_build=()
    local python_vers_to_build=()

    for item in "${BUILDS_NEEDED[@]}"; do
        # item format: "package_name:version:python_ver"
        local pkg="${item%%:*}"
        local rest="${item#*:}"
        local ver="${rest%%:*}"
        local pyver="${rest#*:}"

        # Only build if this matches our current variant
        local current_pkg
        current_pkg=$(normalize_variant "$VARIANT") || continue

        if [[ "$pkg" == "$current_pkg" ]] || [[ "$VARIANT" == "all" ]]; then
            # Add to build list if not already present
            if [[ ! " ${versions_to_build[*]} " =~ " ${ver} " ]]; then
                versions_to_build+=("$ver")
            fi
            if [[ ! " ${python_vers_to_build[*]} " =~ " ${pyver} " ]]; then
                python_vers_to_build+=("$pyver")
            fi
        fi
    done

    if [[ ${#versions_to_build[@]} -eq 0 ]]; then
        log_info "No versions need building for variant: $VARIANT"
        return 0
    fi

    # Join arrays for command
    local versions_str
    versions_str=$(IFS=,; echo "${versions_to_build[*]}")
    local python_str
    python_str=$(IFS=,; echo "${python_vers_to_build[*]}")

    log_info "Versions to build: $versions_str"
    log_info "Python versions: $python_str"

    local build_cmd=""

    if [[ "$BUILDER" == "docker" ]]; then
        # Docker buildx builder
        build_cmd="./docker-buildx.sh --variant=$VARIANT"
        build_cmd="$build_cmd --vllm-versions=$versions_str"
        build_cmd="$build_cmd --python-versions=$python_str"
        build_cmd="$build_cmd --platform=$PLATFORM"
        build_cmd="$build_cmd --max-jobs=$MAX_JOBS"
        build_cmd="$build_cmd --output-dir=$DIST_DIR"
        [[ -n "$VERSION_SUFFIX" ]] && build_cmd="$build_cmd --version-suffix=$VERSION_SUFFIX"
    else
        # Native builder (default)
        build_cmd="./build_wheels.sh --variant=$VARIANT"
        build_cmd="$build_cmd --vllm-versions=$versions_str"
        build_cmd="$build_cmd --python-versions=$python_str"
        build_cmd="$build_cmd --max-jobs=$MAX_JOBS"
        build_cmd="$build_cmd --output-dir=$DIST_DIR"
        [[ -n "$VERSION_SUFFIX" ]] && build_cmd="$build_cmd --version-suffix=$VERSION_SUFFIX"
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would run: $build_cmd"
        return 0
    fi

    log_info "Running: $build_cmd"
    if ! eval "$build_cmd"; then
        log_error "Wheel build failed"
        return 1
    fi

    # Wheels are now stored in platform subdirectories: dist/linux_amd64/, dist/linux_arm64/
    # Count wheels in platform directories
    local wheel_count=0
    for subdir in "$DIST_DIR/linux_amd64" "$DIST_DIR/linux_arm64"; do
        if [[ -d "$subdir" ]]; then
            shopt -s nullglob
            local subdir_wheels=("$subdir"/*.whl)
            shopt -u nullglob
            wheel_count=$((wheel_count + ${#subdir_wheels[@]}))
        fi
    done

    if [[ $wheel_count -eq 0 ]]; then
        log_warning "No wheels found in $DIST_DIR/linux_*/"
    else
        log_success "Found $wheel_count wheel(s) in platform directories"

        # Collect all built wheels for verification
        local built_wheels=()
        for subdir in "$DIST_DIR/linux_amd64" "$DIST_DIR/linux_arm64"; do
            if [[ -d "$subdir" ]]; then
                shopt -s nullglob
                for whl in "$subdir"/*.whl; do
                    built_wheels+=("$whl")
                done
                shopt -u nullglob
            fi
        done

        # Verify built wheels
        if [[ ${#built_wheels[@]} -gt 0 ]]; then
            log_info "Verifying built wheels..."
            if ! verify_wheels_parallel "${built_wheels[@]}"; then
                log_error "Wheel verification failed after build"
                return 1
            fi
        fi
    fi

    log_success "Wheel built successfully"
}

# Detect version from vLLM git repository
detect_version_from_git() {
    log_info "Detecting version from vLLM git repository..."

    local workspace="./build"
    local vllm_dir="$workspace/vllm"

    # Check if vLLM repo exists from build
    if [[ ! -d "$vllm_dir/.git" ]]; then
        log_warning "vLLM git repository not found at $vllm_dir"
        return 1
    fi

    # Get version from git tags
    local git_version
    git_version=$(cd "$vllm_dir" && git describe --tags --abbrev=0 2>/dev/null)

    if [[ -z "$git_version" ]]; then
        log_warning "Could not get version from git tags"
        return 1
    fi

    # Remove 'v' prefix if present
    git_version="${git_version#v}"

    if [[ -n "$git_version" ]]; then
        DETECTED_VERSION="$git_version"
        log_info "Detected version from git: $DETECTED_VERSION"
        return 0
    fi

    return 1
}

# Find all wheels in dist directory
find_all_wheels() {
    log_info "Locating all wheels in $DIST_DIR/ directory..."

    shopt -s nullglob
    local wheels=("$DIST_DIR"/*.whl)
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        log_error "No wheels found in $DIST_DIR/ directory"
        return 1
    fi

    log_info "Found ${#wheels[@]} wheel(s)"

    # Clear arrays
    WHEEL_PATHS=()
    PACKAGE_NAMES=()
    DETECTED_VERSIONS=()

    # Process each wheel
    local wheel
    for wheel in "${wheels[@]}"; do
        local package_name
        local version

        package_name=$(basename "$wheel" | sed 's/-[0-9].*//' | tr '_' '-')
        version=$(basename "$wheel" | sed -n 's/.*-\([0-9][0-9.]*\)-.*/\1/p')

        WHEEL_PATHS+=("$wheel")
        PACKAGE_NAMES+=("$package_name")
        DETECTED_VERSIONS+=("$version")

        log_info "  - $(basename "$wheel")"
        log_info "    Package: $package_name, Version: $version"
    done

    # Set single-wheel variables for backward compatibility
    if [[ ${#WHEEL_PATHS[@]} -gt 0 ]]; then
        WHEEL_PATH="${WHEEL_PATHS[0]}"
        PACKAGE_NAME="${PACKAGE_NAMES[0]}"
        DETECTED_VERSION="${DETECTED_VERSIONS[0]}"
    fi

    return 0
}

# Find the wheel file and extract version (single variant)
find_wheel() {
    log_info "Locating wheel for variant: $VARIANT"

    shopt -s nullglob
    local wheels=("$DIST_DIR"/*"${VARIANT//-/_}"*.whl)

    if [[ ${#wheels[@]} -eq 0 ]]; then
        log_error "No wheel found for variant: $VARIANT"
        log_error "Expected pattern: $DIST_DIR/*${VARIANT//-/_}*.whl"
        return 1
    fi

    if [[ ${#wheels[@]} -gt 1 ]]; then
        log_warning "Multiple wheels found, using newest: ${wheels[-1]}"
    fi

    WHEEL_PATH="${wheels[-1]}"
    PACKAGE_NAME=$(basename "$WHEEL_PATH" | sed 's/-[0-9].*//' | tr '_' '-')

    # Extract version from wheel filename
    # Format: package_name-VERSION-pythonXY-pythonXY-platform.whl
    DETECTED_VERSION=$(basename "$WHEEL_PATH" | sed -n 's/.*-\([0-9][0-9.]*\)-.*/\1/p')

    if [[ -z "$DETECTED_VERSION" ]]; then
        log_warning "Could not extract version from wheel filename"
        # Try to get version from git repository
        detect_version_from_git || log_warning "Will detect version from installed package later"
    else
        log_info "Detected version from wheel: $DETECTED_VERSION"
    fi

    # Populate arrays for consistency
    WHEEL_PATHS=("$WHEEL_PATH")
    PACKAGE_NAMES=("$PACKAGE_NAME")
    DETECTED_VERSIONS=("$DETECTED_VERSION")

    log_info "Found wheel: $WHEEL_PATH"
    log_info "Package name: $PACKAGE_NAME"
}

# Validate all wheels with twine
validate_all_wheels() {
    log_info "Validating ${#WHEEL_PATHS[@]} wheel(s) with twine..."

    if [[ $DRY_RUN -eq 1 ]]; then
        for wheel in "${WHEEL_PATHS[@]}"; do
            log_info "[DRY RUN] Would run: twine check $wheel"
        done
        return 0
    fi

    if ! command -v twine &> /dev/null; then
        log_error "twine not found. Install with: pip install twine"
        return 1
    fi

    local failed=0
    local wheel
    for wheel in "${WHEEL_PATHS[@]}"; do
        log_info "Validating $(basename "$wheel")..."
        # Capture twine output to check for actual errors vs metadata warnings
        local twine_output
        if twine_output=$(twine check "$wheel" 2>&1); then
            log_success "✓ $(basename "$wheel")"
        else
            # Check if it's just a metadata warning (license-expression, etc.)
            # These are PEP 639 fields that older PyPI/twine may not recognize
            if echo "$twine_output" | grep -qE "license-expression|license-file"; then
                log_warning "Metadata warning for $wheel (PEP 639 fields - safe to ignore)"
                log_warning "  $twine_output"
            else
                log_error "Validation failed for $wheel"
                log_error "  $twine_output"
                failed=1
            fi
        fi
    done

    if [[ $failed -eq 1 ]]; then
        log_error "Some wheels failed validation"
        return 1
    fi

    log_success "All wheels validated successfully"
}

# Validate wheel with twine (single wheel)
validate_wheel() {
    log_info "Validating wheel with twine..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would run: twine check $WHEEL_PATH"
        return 0
    fi

    if ! command -v twine &> /dev/null; then
        log_error "twine not found. Install with: pip install twine"
        return 1
    fi

    if ! twine check "$WHEEL_PATH"; then
        log_error "Wheel validation failed"
        return 1
    fi

    log_success "Wheel validation passed"
}

# Comprehensive wheel verification (structure, ZIP integrity, required files)
verify_wheel_integrity() {
    local wheel_path="$1"
    local verbose="${2:-0}"  # 0 = quiet, 1 = verbose

    if [[ ! -f "$wheel_path" ]]; then
        log_error "Wheel not found: $wheel_path"
        return 1
    fi

    local wheel_name
    wheel_name=$(basename "$wheel_path")
    local errors=0

    # 1. Check ZIP integrity
    if ! unzip -t "$wheel_path" &>/dev/null; then
        log_error "  ✗ ZIP integrity check failed: $wheel_name"
        return 1
    fi
    [[ $verbose -eq 1 ]] && log_info "  ✓ ZIP integrity OK"

    # 2. Check wheel filename format
    # Format: {distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl
    if [[ ! "$wheel_name" =~ ^[a-zA-Z0-9_]+-[0-9]+\.[0-9]+.*-cp[0-9]+-.*\.whl$ ]]; then
        log_error "  ✗ Invalid wheel filename format: $wheel_name"
        ((errors++))
    else
        [[ $verbose -eq 1 ]] && log_info "  ✓ Filename format OK"
    fi

    # 3. Check required files exist inside wheel
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    unzip -q "$wheel_path" -d "$temp_dir" 2>/dev/null

    # Check for .dist-info directory
    local dist_info_dir
    dist_info_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "*.dist-info" | head -1)

    if [[ -z "$dist_info_dir" ]]; then
        log_error "  ✗ Missing .dist-info directory: $wheel_name"
        ((errors++))
    else
        [[ $verbose -eq 1 ]] && log_info "  ✓ .dist-info directory exists"

        # Check METADATA file
        if [[ ! -f "$dist_info_dir/METADATA" ]]; then
            log_error "  ✗ Missing METADATA file: $wheel_name"
            ((errors++))
        else
            [[ $verbose -eq 1 ]] && log_info "  ✓ METADATA file exists"

            # Verify METADATA has required fields
            local has_name has_version
            has_name=$(grep -c "^Name:" "$dist_info_dir/METADATA" || echo 0)
            has_version=$(grep -c "^Version:" "$dist_info_dir/METADATA" || echo 0)

            if [[ $has_name -eq 0 ]]; then
                log_error "  ✗ METADATA missing 'Name' field: $wheel_name"
                ((errors++))
            fi
            if [[ $has_version -eq 0 ]]; then
                log_error "  ✗ METADATA missing 'Version' field: $wheel_name"
                ((errors++))
            fi
        fi

        # Check WHEEL file
        if [[ ! -f "$dist_info_dir/WHEEL" ]]; then
            log_error "  ✗ Missing WHEEL file: $wheel_name"
            ((errors++))
        else
            [[ $verbose -eq 1 ]] && log_info "  ✓ WHEEL file exists"
        fi

        # Check RECORD file
        if [[ ! -f "$dist_info_dir/RECORD" ]]; then
            log_error "  ✗ Missing RECORD file: $wheel_name"
            ((errors++))
        else
            [[ $verbose -eq 1 ]] && log_info "  ✓ RECORD file exists"

            # Verify RECORD entries match actual files (sample check)
            local record_count file_count
            record_count=$(wc -l < "$dist_info_dir/RECORD")
            file_count=$(find "$temp_dir" -type f | wc -l)

            # RECORD should have roughly same number of entries as files
            # (RECORD itself is listed with empty hash, so counts should match)
            if [[ $record_count -lt $((file_count - 5)) ]]; then
                log_warning "  ⚠ RECORD entries ($record_count) much less than files ($file_count)"
            fi
        fi

        # Check README content exists (for PyPI display)
        # Modern wheels (PEP 566+) embed README in METADATA, not as separate file
        if [[ -f "$dist_info_dir/README.md" ]]; then
            # Legacy: README.md as separate file
            [[ $verbose -eq 1 ]] && log_info "  ✓ README.md exists (separate file)"
            local readme_size
            readme_size=$(wc -c < "$dist_info_dir/README.md")
            if [[ $readme_size -lt 100 ]]; then
                log_warning "  ⚠ README.md is very small ($readme_size bytes)"
            fi
        elif [[ -f "$dist_info_dir/METADATA" ]]; then
            # Modern: Check if README is embedded in METADATA
            # METADATA has headers, then blank line, then description (README content)
            local metadata_lines desc_lines
            metadata_lines=$(wc -l < "$dist_info_dir/METADATA")
            # Count lines after the first blank line (description section)
            desc_lines=$(awk '/^$/{found=1; next} found{count++} END{print count+0}' "$dist_info_dir/METADATA")
            if [[ $desc_lines -gt 10 ]]; then
                [[ $verbose -eq 1 ]] && log_info "  ✓ README embedded in METADATA ($desc_lines description lines)"
            else
                log_warning "  ⚠ METADATA has minimal description ($desc_lines lines) - PyPI description may be empty"
            fi
        else
            log_warning "  ⚠ Missing README/METADATA - PyPI description may be empty"
        fi
    fi

    # 4. Check for vllm module
    local vllm_dir
    vllm_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "vllm" | head -1)
    if [[ -z "$vllm_dir" ]]; then
        log_error "  ✗ Missing vllm module directory: $wheel_name"
        ((errors++))
    else
        [[ $verbose -eq 1 ]] && log_info "  ✓ vllm module exists"

        # Check for __init__.py
        if [[ ! -f "$vllm_dir/__init__.py" ]]; then
            log_error "  ✗ Missing vllm/__init__.py: $wheel_name"
            ((errors++))
        fi
    fi

    # 5. Run twine check for PyPI compatibility
    if command -v twine &>/dev/null; then
        local twine_output
        if twine_output=$(twine check "$wheel_path" 2>&1); then
            [[ $verbose -eq 1 ]] && log_info "  ✓ twine check passed"
        else
            # Check if it's just a PEP 639 metadata warning (license-expression, license-file)
            if echo "$twine_output" | grep -qE "license-expression|license-file"; then
                [[ $verbose -eq 1 ]] && log_warning "  ⚠ twine check: PEP 639 metadata warning (safe to ignore)"
            else
                log_error "  ✗ twine check failed: $wheel_name"
                log_error "    $twine_output"
                ((errors++))
            fi
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Wheel verification failed with $errors error(s): $wheel_name"
        return 1
    fi

    return 0
}

# Verify multiple wheels in parallel
verify_wheels_parallel() {
    local wheels=("$@")
    local num_wheels=${#wheels[@]}

    if [[ $num_wheels -eq 0 ]]; then
        log_warning "No wheels to verify"
        return 0
    fi

    local parallel_jobs=$MAX_JOBS
    if [[ $parallel_jobs -gt $num_wheels ]]; then
        parallel_jobs=$num_wheels
    fi
    if [[ $parallel_jobs -gt 8 ]]; then
        parallel_jobs=8
    fi

    log_info "Verifying $num_wheels wheel(s) (using $parallel_jobs parallel jobs)..."

    # Create temp directory for tracking results
    local results_dir
    results_dir=$(mktemp -d)
    trap "rm -rf '$results_dir'" RETURN

    # Process wheels in parallel
    local running=0

    for wheel in "${wheels[@]}"; do
        while [[ $running -ge $parallel_jobs ]]; do
            wait -n 2>/dev/null || true
            running=$(jobs -r | wc -l)
        done

        (
            local wheel_name
            wheel_name=$(basename "$wheel")
            if verify_wheel_integrity "$wheel" 0; then
                touch "$results_dir/success_${wheel_name}"
                log_success "  ✓ $wheel_name"
            else
                touch "$results_dir/failed_${wheel_name}"
            fi
        ) &

        ((running++))
    done

    wait

    # Count results
    local success_count failed_count
    success_count=$(find "$results_dir" -name "success_*" 2>/dev/null | wc -l)
    failed_count=$(find "$results_dir" -name "failed_*" 2>/dev/null | wc -l)

    if [[ $failed_count -gt 0 ]]; then
        log_error "Verification failed: $failed_count wheel(s) invalid"
        for f in "$results_dir"/failed_*; do
            if [[ -f "$f" ]]; then
                local failed_wheel="${f#$results_dir/failed_}"
                log_error "  - $failed_wheel"
            fi
        done
        return 1
    fi

    log_success "All $success_count wheel(s) verified successfully"
    return 0
}

# Verify all wheels for a specific variant and version
# Usage: verify_wheels_for_variant <variant> <vllm_ver> [platform]
# platform: linux/arm64, linux/amd64, or "" for all platforms
verify_wheels_for_variant() {
    local variant="$1"
    local vllm_ver="$2"
    local platform="${3:-$PLATFORM}"  # Use global PLATFORM if not specified

    # Find wheels for this variant and version (same pattern as update_readme_in_wheels)
    local variant_pattern="${variant//-/_}"

    # Determine platform filter
    local platform_filter=""
    local platform_subdir=""
    case "$platform" in
        linux/arm64|arm64|aarch64)
            platform_filter="aarch64"
            platform_subdir="linux_arm64"
            ;;
        linux/amd64|amd64|x86_64)
            platform_filter="x86_64"
            platform_subdir="linux_amd64"
            ;;
        all|auto|"")
            platform_filter=""  # Any platform
            platform_subdir=""
            ;;
    esac

    # Build exact version pattern: VERSION- or VERSION+SUFFIX-
    # This prevents matching suffix versions when looking for base version
    local search_version="${vllm_ver}${VERSION_SUFFIX}"
    local exact_pattern="${search_version}-"

    shopt -s nullglob
    local wheels=()

    if [[ -n "$platform_subdir" ]]; then
        # Specific platform - only search that platform's directory
        local subdir="$DIST_DIR/$platform_subdir"
        if [[ -d "$subdir" ]]; then
            for whl in "$subdir/${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                       "$subdir/${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl; do
                if [[ -f "$whl" ]]; then
                    wheels+=("$whl")
                fi
            done
        fi
        # Also check root dist dir with platform filter
        for whl in "$DIST_DIR/${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                   "$DIST_DIR/${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl; do
            if [[ -f "$whl" ]]; then
                wheels+=("$whl")
            fi
        done
    else
        # All platforms - check all platform subdirectories
        for subdir in "$DIST_DIR/linux_amd64" "$DIST_DIR/linux_arm64"; do
            if [[ -d "$subdir" ]]; then
                for whl in "$subdir/${variant_pattern}"-${exact_pattern}*.whl \
                           "$subdir/${variant_pattern}"_${exact_pattern}*.whl; do
                    if [[ -f "$whl" ]]; then
                        wheels+=("$whl")
                    fi
                done
            fi
        done

        # Also check root dist dir
        for whl in "$DIST_DIR/${variant_pattern}"-${exact_pattern}*.whl \
                   "$DIST_DIR/${variant_pattern}"_${exact_pattern}*.whl; do
            if [[ -f "$whl" ]]; then
                wheels+=("$whl")
            fi
        done
    fi
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        local platform_msg=""
        [[ -n "$platform_filter" ]] && platform_msg=" ($platform_filter)"
        log_error "No wheels found for $variant @ vLLM $vllm_ver${platform_msg} in $DIST_DIR"
        return 1
    fi

    log_info "Found ${#wheels[@]} wheel(s) to verify for $variant @ vLLM $vllm_ver"

    # Use parallel verification
    if ! verify_wheels_parallel "${wheels[@]}"; then
        return 1
    fi

    return 0
}

# Update README inside an existing wheel without rebuilding
# Wheels are ZIP files, so we extract, replace README, and repackage
update_readme_in_wheel() {
    local wheel_path="$1"
    local readme_file="$2"

    if [[ ! -f "$wheel_path" ]]; then
        log_error "Wheel not found: $wheel_path"
        return 1
    fi

    if [[ ! -f "$readme_file" ]]; then
        log_error "README file not found: $readme_file"
        return 1
    fi

    local wheel_name
    wheel_name=$(basename "$wheel_path")
    log_info "Updating README in: $wheel_name"

    # Create temporary directory for extraction
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    # Extract wheel
    log_info "  Extracting wheel..."
    if ! unzip -q "$wheel_path" -d "$temp_dir"; then
        log_error "Failed to extract wheel"
        return 1
    fi

    # Find the .dist-info directory
    local dist_info_dir
    dist_info_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "*.dist-info" | head -1)

    if [[ -z "$dist_info_dir" ]]; then
        log_error "Could not find .dist-info directory in wheel"
        return 1
    fi

    # Copy new README to dist-info (this is where PyPI reads it from)
    log_info "  Replacing README..."
    cp "$readme_file" "$dist_info_dir/README.md"

    # Also update METADATA file if it contains the description
    local metadata_file="$dist_info_dir/METADATA"
    if [[ -f "$metadata_file" ]]; then
        # Read the new README content
        local readme_content
        readme_content=$(cat "$readme_file")

        # Create new METADATA with updated description
        # The description comes after a blank line following the headers
        local temp_metadata
        temp_metadata=$(mktemp)

        # Extract headers (everything before the first blank line after headers)
        awk '/^$/{found=1} !found{print}' "$metadata_file" > "$temp_metadata"

        # Add blank line and new description
        echo "" >> "$temp_metadata"
        echo "$readme_content" >> "$temp_metadata"

        mv "$temp_metadata" "$metadata_file"
        log_info "  Updated METADATA description"
    fi

    # Regenerate RECORD file (contents changed, so hashes must be updated)
    local record_file="$dist_info_dir/RECORD"
    local dist_info_name
    dist_info_name=$(basename "$dist_info_dir")
    log_info "  Regenerating RECORD file..."

    # Create new RECORD
    local new_record
    new_record=$(mktemp)

    # Generate hashes for all files except RECORD itself
    # PEP 427 requires base64-urlsafe encoded SHA256 hashes (not hex)
    (
        cd "$temp_dir" || exit 1
        find . -type f ! -name "RECORD" -print0 | while IFS= read -r -d '' file; do
            # Remove leading ./
            local rel_path="${file#./}"
            # Calculate SHA256 hash as base64-urlsafe (PEP 427 format)
            # Using Python for reliable base64url encoding
            local hash
            hash=$(python3 -c "
import hashlib
import base64
with open('$file', 'rb') as f:
    digest = hashlib.sha256(f.read()).digest()
# base64url encoding without padding (as per PEP 427)
print(base64.urlsafe_b64encode(digest).rstrip(b'=').decode('ascii'))
")
            local size
            size=$(stat -c%s "$file")
            # RECORD format: path,sha256=hash,size
            echo "${rel_path},sha256=${hash},${size}"
        done
        # RECORD itself has no hash
        echo "${dist_info_name}/RECORD,,"
    ) > "$new_record"

    mv "$new_record" "$record_file"

    # Backup original wheel
    local backup_path="${wheel_path}.bak"
    mv "$wheel_path" "$backup_path"

    # Repackage wheel
    log_info "  Repackaging wheel..."

    # Get absolute path for wheel_path (in case it's relative)
    local abs_wheel_path
    abs_wheel_path=$(cd "$(dirname "$wheel_path")" && pwd)/$(basename "$wheel_path")

    # Create new wheel from temp directory
    # Using subshell to avoid changing current directory
    if ! (cd "$temp_dir" && zip -q -r "$abs_wheel_path" ./*); then
        log_error "Failed to repackage wheel"
        mv "$backup_path" "$wheel_path"
        return 1
    fi

    # Remove backup
    rm -f "$backup_path"

    log_success "  README updated in: $wheel_name"
    return 0
}

# Rename a wheel with a version suffix (e.g., 0.10.0 -> 0.10.0.rebuild1)
# This updates the wheel filename, internal metadata, and .dist-info directory
rename_wheel_with_suffix() {
    local wheel_path="$1"
    local version_suffix="$2"

    if [[ ! -f "$wheel_path" ]]; then
        log_error "Wheel not found: $wheel_path"
        return 1
    fi

    if [[ -z "$version_suffix" ]]; then
        log_error "Version suffix is required"
        return 1
    fi

    local wheel_name
    wheel_name=$(basename "$wheel_path")
    local wheel_dir
    wheel_dir=$(dirname "$wheel_path")

    # Parse wheel filename: {distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl
    # Example: vllm_cpu_avx512-0.10.0-cp310-cp310-manylinux_2_17_x86_64.whl
    local pkg_name version py_tag abi_tag platform_tag
    if [[ "$wheel_name" =~ ^([^-]+)-([^-]+)-([^-]+)-([^-]+)-(.+)\.whl$ ]]; then
        pkg_name="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
        py_tag="${BASH_REMATCH[3]}"
        abi_tag="${BASH_REMATCH[4]}"
        platform_tag="${BASH_REMATCH[5]}"
    else
        log_error "Could not parse wheel filename: $wheel_name"
        return 1
    fi

    # Check if suffix is already applied
    if [[ "$version" == *"$version_suffix" ]]; then
        log_warning "Wheel already has suffix $version_suffix: $wheel_name"
        return 0
    fi

    local new_version="${version}${version_suffix}"
    local new_wheel_name="${pkg_name}-${new_version}-${py_tag}-${abi_tag}-${platform_tag}.whl"
    local new_wheel_path="${wheel_dir}/${new_wheel_name}"

    log_info "Renaming wheel: $wheel_name -> $new_wheel_name"

    # Create temporary directory for extraction
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN

    # Extract wheel
    log_info "  Extracting wheel..."
    if ! unzip -q "$wheel_path" -d "$temp_dir"; then
        log_error "Failed to extract wheel"
        return 1
    fi

    # Find and rename the .dist-info directory
    local old_dist_info
    old_dist_info=$(find "$temp_dir" -maxdepth 1 -type d -name "*.dist-info" | head -1)

    if [[ -z "$old_dist_info" ]]; then
        log_error "Could not find .dist-info directory in wheel"
        return 1
    fi

    local old_dist_info_name
    old_dist_info_name=$(basename "$old_dist_info")
    # dist-info format: {pkg_name}-{version}.dist-info
    local new_dist_info_name="${pkg_name}-${new_version}.dist-info"
    local new_dist_info="${temp_dir}/${new_dist_info_name}"

    log_info "  Renaming dist-info: $old_dist_info_name -> $new_dist_info_name"
    mv "$old_dist_info" "$new_dist_info"

    # Update METADATA file
    local metadata_file="${new_dist_info}/METADATA"
    if [[ -f "$metadata_file" ]]; then
        log_info "  Updating METADATA version: $version -> $new_version"
        sed -i "s/^Version: ${version}$/Version: ${new_version}/" "$metadata_file"
    fi

    # Update WHEEL file (usually doesn't contain version, but check anyway)
    local wheel_file="${new_dist_info}/WHEEL"
    if [[ -f "$wheel_file" ]]; then
        # WHEEL file typically doesn't have version, but update if present
        if grep -q "^Version:" "$wheel_file"; then
            sed -i "s/^Version: ${version}$/Version: ${new_version}/" "$wheel_file"
        fi
    fi

    # Regenerate RECORD file (contains hashes of all files)
    local record_file="${new_dist_info}/RECORD"
    log_info "  Regenerating RECORD file..."

    # Create new RECORD
    local new_record
    new_record=$(mktemp)

    # Generate hashes for all files except RECORD itself
    # PEP 427 requires base64-urlsafe encoded SHA256 hashes (not hex)
    (
        cd "$temp_dir" || exit 1
        find . -type f ! -name "RECORD" -print0 | while IFS= read -r -d '' file; do
            # Remove leading ./
            local rel_path="${file#./}"
            # Calculate SHA256 hash as base64-urlsafe (PEP 427 format)
            # Using Python for reliable base64url encoding
            local hash
            hash=$(python3 -c "
import hashlib
import base64
with open('$file', 'rb') as f:
    digest = hashlib.sha256(f.read()).digest()
# base64url encoding without padding (as per PEP 427)
print(base64.urlsafe_b64encode(digest).rstrip(b'=').decode('ascii'))
")
            local size
            size=$(stat -c%s "$file")
            # RECORD format: path,sha256=hash,size
            echo "${rel_path},sha256=${hash},${size}"
        done
        # RECORD itself has no hash
        echo "${new_dist_info_name}/RECORD,,"
    ) > "$new_record"

    mv "$new_record" "$record_file"

    # Create the new wheel
    log_info "  Repackaging as: $new_wheel_name"

    # Get absolute path for new wheel
    local abs_new_wheel_path
    abs_new_wheel_path=$(cd "$wheel_dir" && pwd)/"$new_wheel_name"

    # Create new wheel from temp directory
    if ! (cd "$temp_dir" && zip -q -r "$abs_new_wheel_path" ./*); then
        log_error "Failed to create new wheel"
        return 1
    fi

    # Verify the new wheel exists
    if [[ ! -f "$new_wheel_path" ]]; then
        log_error "New wheel was not created: $new_wheel_path"
        return 1
    fi

    # Remove old wheel
    rm -f "$wheel_path"

    log_success "  Renamed: $wheel_name -> $new_wheel_name"
    return 0
}

# Rename all wheels for a variant with version suffix
# Usage: rename_wheels_with_suffix <variant> <vllm_ver> <version_suffix> [platform]
rename_wheels_with_suffix() {
    local variant="$1"
    local vllm_ver="$2"
    local version_suffix="$3"
    local platform="${4:-$PLATFORM}"  # Use global PLATFORM if not specified

    if [[ -z "$version_suffix" ]]; then
        log_error "Version suffix is required for renaming"
        return 1
    fi

    # Determine platform filter
    local platform_filter=""
    local platform_subdir=""
    case "$platform" in
        linux/arm64|arm64|aarch64)
            platform_filter="aarch64"
            platform_subdir="linux_arm64"
            ;;
        linux/amd64|amd64|x86_64)
            platform_filter="x86_64"
            platform_subdir="linux_amd64"
            ;;
        all|auto|"")
            platform_filter=""  # Any platform
            platform_subdir=""
            ;;
    esac

    # Find wheels for this variant and BASE version (not with suffix)
    # This function renames base version wheels to include a suffix
    local variant_pattern="${variant//-/_}"
    local exact_pattern="${vllm_ver}-"  # Base version only: "0.10.0-" not "0.10.0.post1-"
    shopt -s nullglob
    local wheels=()

    if [[ -n "$platform_subdir" ]]; then
        # Specific platform - only search that platform's directory
        local subdir="$DIST_DIR/$platform_subdir"
        if [[ -d "$subdir" ]]; then
            for wheel in "$subdir/${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl; do
                if [[ -f "$wheel" ]]; then
                    wheels+=("$wheel")
                fi
            done
        fi
        # Also check root dist dir with platform filter
        for wheel in "$DIST_DIR/${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl; do
            if [[ -f "$wheel" ]]; then
                wheels+=("$wheel")
            fi
        done
    else
        # Search in dist/ and subdirectories (all platforms)
        for wheel in "$DIST_DIR"/${variant_pattern}-${exact_pattern}*.whl \
                     "$DIST_DIR"/**/${variant_pattern}-${exact_pattern}*.whl; do
            if [[ -f "$wheel" ]]; then
                wheels+=("$wheel")
            fi
        done
    fi
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        local platform_msg=""
        [[ -n "$platform_filter" ]] && platform_msg=" ($platform_filter)"
        log_warning "No wheels found for $variant @ vLLM $vllm_ver${platform_msg} (base version)"
        return 1
    fi

    log_info "Found ${#wheels[@]} wheel(s) to rename for $variant @ vLLM $vllm_ver"

    local success_count=0
    local fail_count=0

    for wheel in "${wheels[@]}"; do
        if [[ $DRY_RUN -eq 1 ]]; then
            local wheel_name
            wheel_name=$(basename "$wheel")
            local new_name="${wheel_name/-${vllm_ver}-/-${vllm_ver}${version_suffix}-}"
            log_info "[DRY RUN] Would rename: $wheel_name -> $new_name"
            ((success_count++))
        else
            if rename_wheel_with_suffix "$wheel" "$version_suffix"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        fi
    done

    log_info "Rename complete: $success_count succeeded, $fail_count failed"

    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Update README in all wheels for a variant (with parallel processing)
# Usage: update_readme_in_wheels <variant> <vllm_ver> [platform]
update_readme_in_wheels() {
    local variant="$1"
    local vllm_ver="$2"
    local platform="${3:-$PLATFORM}"  # Use global PLATFORM if not specified

    # Get the README file for this variant from build_config.json
    local readme_file=""
    case "$variant" in
        vllm-cpu|noavx512)
            readme_file="$SCRIPT_DIR/noavx512_README.md"
            ;;
        vllm-cpu-avx512|avx512)
            readme_file="$SCRIPT_DIR/avx512_README.md"
            ;;
        vllm-cpu-avx512vnni|avx512vnni)
            readme_file="$SCRIPT_DIR/avx512vnni_README.md"
            ;;
        vllm-cpu-avx512bf16|avx512bf16)
            readme_file="$SCRIPT_DIR/avx512bf16_README.md"
            ;;
        vllm-cpu-amxbf16|amxbf16)
            readme_file="$SCRIPT_DIR/amxbf16_README.md"
            ;;
        *)
            log_error "Unknown variant: $variant"
            return 1
            ;;
    esac

    if [[ ! -f "$readme_file" ]]; then
        log_error "README file not found: $readme_file"
        return 1
    fi

    log_info "Using README: $readme_file"

    # Determine platform filter
    local platform_filter=""
    local platform_subdir=""
    case "$platform" in
        linux/arm64|arm64|aarch64)
            platform_filter="aarch64"
            platform_subdir="linux_arm64"
            ;;
        linux/amd64|amd64|x86_64)
            platform_filter="x86_64"
            platform_subdir="linux_amd64"
            ;;
        all|auto|"")
            platform_filter=""  # Any platform
            platform_subdir=""
            ;;
    esac

    # Build exact version pattern: VERSION- or VERSION+SUFFIX-
    # This prevents matching suffix versions when looking for base version
    local search_version="${vllm_ver}${VERSION_SUFFIX}"
    local exact_pattern="${search_version}-"

    # Find wheels for this variant and version
    local variant_pattern="${variant//-/_}"
    shopt -s nullglob
    local wheels=()

    if [[ -n "$platform_subdir" ]]; then
        # Specific platform - only search that platform's directory
        local subdir="$DIST_DIR/$platform_subdir"
        if [[ -d "$subdir" ]]; then
            for whl in "$subdir/${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                       "$subdir/${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl; do
                if [[ -f "$whl" ]]; then
                    wheels+=("$whl")
                fi
            done
        fi
        # Also check root dist dir with platform filter
        for whl in "$DIST_DIR/${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                   "$DIST_DIR/${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl; do
            if [[ -f "$whl" ]]; then
                wheels+=("$whl")
            fi
        done
    else
        # All platforms - search everywhere
        for whl in "$DIST_DIR"/linux_*/"${variant_pattern}"-${exact_pattern}*.whl \
                   "$DIST_DIR"/linux_*/"${variant_pattern}"_${exact_pattern}*.whl \
                   "$DIST_DIR"/"${variant_pattern}"-${exact_pattern}*.whl \
                   "$DIST_DIR"/"${variant_pattern}"_${exact_pattern}*.whl; do
            if [[ -f "$whl" ]]; then
                wheels+=("$whl")
            fi
        done
    fi
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        local platform_msg=""
        [[ -n "$platform_filter" ]] && platform_msg=" ($platform_filter)"
        log_error "No wheels found for $variant @ vLLM $search_version${platform_msg} in $DIST_DIR"
        return 1
    fi

    local num_wheels=${#wheels[@]}
    local parallel_jobs=$MAX_JOBS

    # Cap parallel jobs at number of wheels (no point having more workers than wheels)
    if [[ $parallel_jobs -gt $num_wheels ]]; then
        parallel_jobs=$num_wheels
    fi

    # Cap at 8 to avoid overwhelming the system with too many zip operations
    if [[ $parallel_jobs -gt 8 ]]; then
        parallel_jobs=8
    fi

    log_info "Found $num_wheels wheel(s) to update (using $parallel_jobs parallel jobs)"

    # Create temp directory for tracking results
    local results_dir
    results_dir=$(mktemp -d)
    trap "rm -rf '$results_dir'" RETURN

    # Process wheels in parallel using background jobs
    local running=0
    local total_started=0

    for wheel in "${wheels[@]}"; do
        # Wait if we've reached max parallel jobs
        while [[ $running -ge $parallel_jobs ]]; do
            # Wait for any background job to complete
            wait -n 2>/dev/null || true
            running=$(jobs -r | wc -l)
        done

        # Start background job for this wheel
        (
            local wheel_name
            wheel_name=$(basename "$wheel")
            if update_readme_in_wheel "$wheel" "$readme_file"; then
                touch "$results_dir/success_${wheel_name}"
            else
                touch "$results_dir/failed_${wheel_name}"
            fi
        ) &

        ((running++))
        ((total_started++))
    done

    # Wait for all remaining background jobs to complete
    wait

    # Count results
    local success_count failed_count
    success_count=$(find "$results_dir" -name "success_*" 2>/dev/null | wc -l)
    failed_count=$(find "$results_dir" -name "failed_*" 2>/dev/null | wc -l)

    # Report any failures
    if [[ $failed_count -gt 0 ]]; then
        log_error "Failed wheels:"
        for f in "$results_dir"/failed_*; do
            if [[ -f "$f" ]]; then
                local failed_wheel="${f#$results_dir/failed_}"
                log_error "  - $failed_wheel"
            fi
        done
        log_error "$failed_count wheel(s) failed to update"
        return 1
    fi

    log_success "All $success_count wheel(s) updated successfully (parallel processing)"

    # Verify updated wheels
    log_info "Verifying updated wheels..."
    if ! verify_wheels_parallel "${wheels[@]}"; then
        log_error "Wheel verification failed after README update"
        return 1
    fi

    return 0
}

# Check if package version exists on PyPI
check_pypi_version_exists() {
    local package_name="$1"
    local version="$2"
    local pypi_url="$3"  # "https://pypi.org" or "https://test.pypi.org"

    log_info "Checking if $package_name v$version exists on $(basename "$pypi_url")..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would check: $pypi_url/pypi/$package_name/json"
        return 1  # Assume doesn't exist in dry-run
    fi

    # Query PyPI JSON API
    local response
    response=$(curl -s "$pypi_url/pypi/$package_name/json" 2>/dev/null)

    if [[ -z "$response" ]]; then
        log_info "Package $package_name not found on $(basename "$pypi_url")"
        return 1  # Package doesn't exist
    fi

    # Check if specific version exists
    if echo "$response" | grep -q "\"$version\""; then
        log_warning "Version $version already exists on $(basename "$pypi_url")"
        return 0  # Version exists
    fi

    log_info "Version $version not found on $(basename "$pypi_url")"
    return 1  # Version doesn't exist
}

# Check if platform-specific wheel exists on PyPI
# Returns 0 if wheel for the specified platform exists, 1 otherwise
# Args:
#   $1: package_name (e.g., "vllm-cpu")
#   $2: version (e.g., "0.11.0")
#   $3: python_ver (e.g., "3.10")
#   $4: platform (e.g., "linux/arm64", "linux/amd64", "all", "auto")
#   $5: pypi_url (optional, defaults to https://pypi.org)
check_pypi_platform_wheel_exists() {
    local package_name="$1"
    local version="$2"
    local python_ver="$3"
    local platform="$4"
    local pypi_url="${5:-https://pypi.org}"

    # Determine platform tag to search for
    local platform_tag=""
    case "$platform" in
        linux/arm64|arm64|aarch64)
            platform_tag="aarch64"
            ;;
        linux/amd64|amd64|x86_64)
            platform_tag="x86_64"
            ;;
        all|auto|"")
            # For all/auto, check if ANY wheel exists (use old behavior)
            return $(check_pypi_version_exists "$package_name" "$version" "$pypi_url"; echo $?)
            ;;
        *)
            log_warning "Unknown platform: $platform, using version-only check"
            return $(check_pypi_version_exists "$package_name" "$version" "$pypi_url"; echo $?)
            ;;
    esac

    local pyver_tag="cp${python_ver//./}"  # 3.10 -> cp310

    log_info "Checking if $package_name v$version ($pyver_tag, $platform_tag) exists on $(basename "$pypi_url")..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would check for $platform_tag wheel"
        return 1  # Assume doesn't exist in dry-run
    fi

    # Query PyPI JSON API for the specific version
    local response
    response=$(curl -s "$pypi_url/pypi/$package_name/$version/json" 2>/dev/null)

    if [[ -z "$response" ]] || echo "$response" | grep -q '"message"'; then
        log_info "Version $version not found on $(basename "$pypi_url")"
        return 1  # Version doesn't exist at all
    fi

    # Check if a wheel for this platform exists
    # Look for pattern like: vllm_cpu-0.11.0-cp310-cp310-manylinux_2_17_aarch64.whl
    local wheel_pattern="${package_name//-/_}-${version}.*${pyver_tag}.*${platform_tag}"

    if echo "$response" | grep -qE "\"filename\":\s*\"${wheel_pattern}"; then
        log_warning "Wheel for $platform_tag already exists on $(basename "$pypi_url")"
        return 0  # Platform-specific wheel exists
    fi

    log_info "No $platform_tag wheel found for $package_name v$version"
    return 1  # Platform-specific wheel doesn't exist
}

# Check if specific wheel file exists on PyPI (or was previously uploaded and deleted)
# This is more thorough than check_pypi_version_exists as it checks for the exact filename
# PyPI does not allow filename reuse even after deletion
check_pypi_wheel_exists() {
    local wheel_path="$1"
    local pypi_url="${2:-https://pypi.org}"

    local wheel_basename
    wheel_basename=$(basename "$wheel_path")

    # Extract package name and version from wheel filename
    # Format: package_name-version-pyXX-pyXX-platform.whl
    local pkg_name
    pkg_name=$(echo "$wheel_basename" | sed 's/-[0-9].*//' | tr '_' '-')
    local version
    version=$(echo "$wheel_basename" | sed -n 's/.*-\([0-9][0-9.]*[0-9]\)-.*/\1/p')

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would check wheel: $wheel_basename on $(basename "$pypi_url")"
        return 1  # Assume doesn't exist in dry-run
    fi

    # Query PyPI JSON API for the specific version
    local response
    response=$(curl -s "$pypi_url/pypi/$pkg_name/$version/json" 2>/dev/null)

    if [[ -z "$response" ]] || echo "$response" | grep -q '"message"'; then
        # Version doesn't exist at all
        return 1
    fi

    # Check if this exact wheel filename exists in the release files
    if echo "$response" | grep -q "\"filename\": \"$wheel_basename\""; then
        log_warning "Wheel $wheel_basename already exists on $(basename "$pypi_url")"
        return 0  # Wheel exists
    fi

    # Also check if a similar wheel exists (same version, different build)
    # This catches cases where the file was uploaded then deleted
    local wheel_prefix
    wheel_prefix=$(echo "$wheel_basename" | sed 's/\(.*-[0-9][0-9.]*[0-9]\).*/\1/')

    if echo "$response" | grep -q "\"filename\": \"${wheel_prefix}"; then
        log_warning "A wheel with prefix $wheel_prefix already exists on $(basename "$pypi_url")"
        log_warning "PyPI may reject this upload due to filename reuse policy"
        return 0  # Similar wheel exists - likely will be rejected
    fi

    return 1  # Wheel doesn't exist
}

# Check if wheel file already exists in $DIST_DIR directory
# Platform-aware: when PLATFORM is set to a specific value (e.g., linux/arm64),
# only looks for wheels matching that platform
check_wheel_exists_locally() {
    local variant="$1"
    local version="$2"
    local python_ver="$3"

    # Convert variant name to wheel package name format (replace - with _)
    local wheel_pattern="${variant//-/_}"

    # Build pattern to match wheel filename
    # Format: package_name-VERSION-cpXX-cpXX-platform.whl
    local py_tag="cp${python_ver//./}"

    # Determine platform filter
    local platform_filter=""
    local platform_subdir=""
    case "$PLATFORM" in
        linux/arm64|arm64|aarch64)
            platform_filter="aarch64"
            platform_subdir="linux_arm64"
            ;;
        linux/amd64|amd64|x86_64)
            platform_filter="x86_64"
            platform_subdir="linux_amd64"
            ;;
        all|auto|"")
            platform_filter=""  # Any platform
            platform_subdir=""
            ;;
        *)
            platform_filter=""  # Unknown, any platform
            platform_subdir=""
            ;;
    esac

    if [[ -n "$platform_filter" ]]; then
        log_info "Checking for existing wheel: ${wheel_pattern}-${version}-${py_tag}*${platform_filter}*.whl in $DIST_DIR"
    else
        log_info "Checking for existing wheel: ${wheel_pattern}-${version}-${py_tag}*.whl in $DIST_DIR"
    fi

    # Build exact version pattern: VERSION- ensures we match "0.10.0-" not "0.10.0.post1-"
    # This prevents matching suffix versions (e.g., 0.10.0.post1) when looking for base (0.10.0)
    local exact_version="${version}-"

    # Check in platform-specific subdirectory first (for docker builds)
    if [[ -n "$platform_subdir" ]]; then
        shopt -s nullglob
        local docker_wheels=("$DIST_DIR"/${platform_subdir}/${wheel_pattern}-${exact_version}${py_tag}*${platform_filter}*.whl "$DIST_DIR"/${platform_subdir}/${wheel_pattern}_${exact_version}${py_tag}*${platform_filter}*.whl)
        shopt -u nullglob

        if [[ ${#docker_wheels[@]} -gt 0 ]]; then
            log_info "Found existing wheel in docker output: ${docker_wheels[0]}"
            return 0  # Wheel exists
        fi
    fi

    # Check root dist dir with platform filter
    shopt -s nullglob
    local wheels=()
    if [[ -n "$platform_filter" ]]; then
        wheels=("$DIST_DIR"/${wheel_pattern}-${exact_version}${py_tag}*${platform_filter}*.whl "$DIST_DIR"/${wheel_pattern}_${exact_version}${py_tag}*${platform_filter}*.whl)
    else
        wheels=("$DIST_DIR"/${wheel_pattern}-${exact_version}${py_tag}*.whl "$DIST_DIR"/${wheel_pattern}_${exact_version}${py_tag}*.whl)
    fi
    shopt -u nullglob

    if [[ ${#wheels[@]} -gt 0 ]]; then
        log_info "Found existing wheel: ${wheels[0]}"
        return 0  # Wheel exists
    fi

    # If no platform filter, also check all platform subdirectories
    if [[ -z "$platform_subdir" ]]; then
        shopt -s nullglob
        local docker_wheels=("$DIST_DIR"/linux_*/${wheel_pattern}-${exact_version}${py_tag}*.whl "$DIST_DIR"/linux_*/${wheel_pattern}_${exact_version}${py_tag}*.whl)
        shopt -u nullglob

        if [[ ${#docker_wheels[@]} -gt 0 ]]; then
            log_info "Found existing wheel in docker output: ${docker_wheels[0]}"
            return 0  # Wheel exists
        fi
    fi

    return 1  # Wheel doesn't exist
}

# Pre-flight check: Determine what needs to be built/published
# Returns via global arrays: BUILDS_NEEDED, PUBLISHES_NEEDED
declare -a BUILDS_NEEDED=()
declare -a PUBLISHES_NEEDED=()
declare -a ALREADY_PUBLISHED=()

preflight_check() {
    local variant="$1"
    local version="$2"
    local python_ver="$3"

    # Convert short variant name to full package name
    local package_name
    package_name=$(normalize_variant "$variant") || return 1

    log_step "Pre-flight check for $package_name v$version (Python $python_ver)"

    # If --update-readme mode, check if wheel exists locally to update
    if [[ $UPDATE_README -eq 1 ]]; then
        if check_wheel_exists_locally "$package_name" "$version" "$python_ver"; then
            log_info "README update mode - will update existing wheel (no rebuild, no upload)"
        else
            log_warning "No wheel found locally for README update - will skip"
        fi
        return 0
    fi

    # First, check if already published on production PyPI
    # Use platform-aware check when a specific platform is requested
    if check_pypi_platform_wheel_exists "$package_name" "$version" "$python_ver" "$PLATFORM" "https://pypi.org"; then
        log_success "✓ $package_name v$version already published on PyPI - SKIPPING"
        ALREADY_PUBLISHED+=("$package_name:$version:$python_ver")
        return 0  # Skip entirely
    fi

    # Check if wheel exists locally
    if check_wheel_exists_locally "$package_name" "$version" "$python_ver"; then
        log_info "Wheel exists locally - will skip build, proceed with publish"
        PUBLISHES_NEEDED+=("$package_name:$version:$python_ver")
        return 0
    fi

    # Need to build and publish
    log_info "Wheel not found - will build and publish"
    BUILDS_NEEDED+=("$package_name:$version:$python_ver")
    PUBLISHES_NEEDED+=("$package_name:$version:$python_ver")
    return 0
}

# Run pre-flight checks for all requested builds
run_preflight_checks() {
    log_step "Running pre-flight checks..."

    # Clear arrays
    BUILDS_NEEDED=()
    PUBLISHES_NEEDED=()
    ALREADY_PUBLISHED=()

    # Expand Python versions
    local python_versions=()
    if [[ "$PYTHON_VERSION" == *-* ]]; then
        # Range format: 3.10-3.13
        local start_ver="${PYTHON_VERSION%-*}"
        local end_ver="${PYTHON_VERSION#*-}"
        local start_minor="${start_ver#3.}"
        local end_minor="${end_ver#3.}"
        for ((minor = start_minor; minor <= end_minor; minor++)); do
            python_versions+=("3.$minor")
        done
    elif [[ "$PYTHON_VERSION" == *,* ]]; then
        # Comma-separated
        IFS=',' read -ra python_versions <<< "$PYTHON_VERSION"
    else
        # Single version
        python_versions=("$PYTHON_VERSION")
    fi

    # Expand vLLM versions
    local vllm_versions=()
    if [[ -n "$VLLM_VERSION" ]]; then
        IFS=',' read -ra vllm_versions <<< "$VLLM_VERSION"
    else
        log_error "vLLM version is required for pre-flight checks"
        return 1
    fi

    # Expand variants
    local all_variants=()
    if [[ "$VARIANT" == "all" ]]; then
        all_variants=("vllm-cpu" "vllm-cpu-avx512" "vllm-cpu-avx512vnni" "vllm-cpu-avx512bf16" "vllm-cpu-amxbf16")
    else
        all_variants=("$VARIANT")
    fi

    # Filter variants by platform (e.g., ARM64 only supports vllm-cpu)
    local filtered_variants
    filtered_variants=$(filter_variants_by_platform "$PLATFORM" "${all_variants[@]}")
    read -ra variants <<< "$filtered_variants"

    if [[ ${#variants[@]} -eq 0 ]]; then
        log_error "No variants support platform: $PLATFORM"
        return 1
    fi

    # Run checks for each combination
    local total_checks=$((${#variants[@]} * ${#vllm_versions[@]} * ${#python_versions[@]}))
    local check_count=0

    for var in "${variants[@]}"; do
        for ver in "${vllm_versions[@]}"; do
            for pyver in "${python_versions[@]}"; do
                ((check_count++)) || true
                log_info "Check $check_count/$total_checks: $var v$ver (Python $pyver)"
                preflight_check "$var" "$ver" "$pyver"
            done
        done
    done

    echo ""
    log_step "Pre-flight Summary:"
    log_info "  Already published (skip all):  ${#ALREADY_PUBLISHED[@]}"
    log_info "  Builds needed:                 ${#BUILDS_NEEDED[@]}"
    log_info "  Publishes needed:              ${#PUBLISHES_NEEDED[@]}"

    if [[ ${#ALREADY_PUBLISHED[@]} -gt 0 ]]; then
        log_info ""
        log_info "Already published packages:"
        for item in "${ALREADY_PUBLISHED[@]}"; do
            log_info "  ✓ $item"
        done
    fi

    if [[ ${#BUILDS_NEEDED[@]} -gt 0 ]]; then
        log_info ""
        log_info "Packages to build:"
        for item in "${BUILDS_NEEDED[@]}"; do
            log_info "  → $item"
        done
    fi

    if [[ ${#BUILDS_NEEDED[@]} -eq 0 ]] && [[ ${#PUBLISHES_NEEDED[@]} -eq 0 ]]; then
        log_success "Nothing to do - all packages already published!"
        return 2  # Special return code: nothing to do
    fi

    return 0
}

# Publish to production PyPI
publish_to_production_pypi() {
    # Only upload wheels for current version (stored in WHEEL_PATHS array)
    if [[ ${#WHEEL_PATHS[@]} -eq 0 ]]; then
        log_warning "No wheels to upload to production PyPI"
        return 0
    fi

    log_info "Publishing ${#WHEEL_PATHS[@]} wheel(s) to production PyPI..."

    # Check if each wheel already exists on production PyPI
    # Uses wheel-level check to catch filename reuse issues (deleted files can't be re-uploaded)
    local wheels_to_upload=()
    local skipped_wheels=()
    for wheel in "${WHEEL_PATHS[@]}"; do
        local wheel_basename
        wheel_basename=$(basename "$wheel")

        if check_pypi_wheel_exists "$wheel" "https://pypi.org"; then
            log_info "Skipping $wheel_basename - already exists on production PyPI"
            skipped_wheels+=("$wheel_basename")
        else
            wheels_to_upload+=("$wheel")
        fi
    done

    if [[ ${#skipped_wheels[@]} -gt 0 ]]; then
        log_info "Skipped ${#skipped_wheels[@]} wheel(s) that already exist on PyPI"
    fi

    if [[ ${#wheels_to_upload[@]} -eq 0 ]]; then
        log_warning "All wheels already exist on production PyPI - skipping upload"
        return 0
    fi

    log_info "Uploading ${#wheels_to_upload[@]} wheel(s) to production PyPI..."

    if [[ $DRY_RUN -eq 1 ]]; then
        for wheel in "${wheels_to_upload[@]}"; do
            log_info "[DRY RUN] Would upload: $(basename "$wheel")"
        done
        return 0
    fi

    # Log what will be uploaded (no confirmation - automated pipeline)
    log_info "Publishing ${#wheels_to_upload[@]} wheel(s) to PRODUCTION PyPI:"
    for wheel in "${wheels_to_upload[@]}"; do
        log_info "  - $(basename "$wheel")"
    done

    # Upload wheels one by one to handle individual failures gracefully
    local upload_success=0
    local upload_failed=0
    local failed_wheels=()

    for wheel in "${wheels_to_upload[@]}"; do
        local wheel_basename
        wheel_basename=$(basename "$wheel")
        log_info "Uploading: $wheel_basename"

        # Get variant-specific token based on wheel filename
        local token=""
        if [[ "$wheel_basename" == vllm_cpu_amxbf16-* ]]; then
            token="${PYPI_TOKEN_AMXBF16:-}"
        elif [[ "$wheel_basename" == vllm_cpu_avx512bf16-* ]]; then
            token="${PYPI_TOKEN_AVX512BF16:-}"
        elif [[ "$wheel_basename" == vllm_cpu_avx512vnni-* ]]; then
            token="${PYPI_TOKEN_AVX512VNNI:-}"
        elif [[ "$wheel_basename" == vllm_cpu_avx512-* ]]; then
            token="${PYPI_TOKEN_AVX512:-}"
        elif [[ "$wheel_basename" == vllm_cpu-* ]]; then
            token="${PYPI_TOKEN_CPU:-}"
        fi

        # Fallback to generic token if variant-specific not set
        if [[ -z "$token" ]]; then
            token="${PYPI_TOKEN:-}"
        fi

        if [[ -z "$token" ]]; then
            log_error "No PyPI token found for $wheel_basename"
            log_error "Set PYPI_TOKEN_CPU, PYPI_TOKEN_AVX512, etc. or PYPI_TOKEN as fallback"
            failed_wheels+=("$wheel_basename")
            ((upload_failed++)) || true
            continue
        fi

        if twine upload \
            --username __token__ \
            --password "$token" \
            --skip-existing \
            "$wheel" 2>&1; then
            log_success "Uploaded: $wheel_basename"
            ((upload_success++)) || true
        else
            # Check if it's a filename reuse error
            local error_output
            error_output=$(twine upload --username __token__ --password "$token" "$wheel" 2>&1 || true)
            if echo "$error_output" | grep -q "filename was previously used"; then
                log_warning "Skipping $wheel_basename - filename was previously used on PyPI (deleted file)"
                ((upload_success++)) || true  # Count as success since we can't upload it anyway
            else
                log_error "Failed to upload: $wheel_basename"
                failed_wheels+=("$wheel_basename")
                ((upload_failed++)) || true
            fi
        fi
    done

    if [[ $upload_failed -gt 0 ]]; then
        log_error "Failed to upload ${upload_failed} wheel(s):"
        for fw in "${failed_wheels[@]}"; do
            log_error "  - $fw"
        done
        return 1
    fi

    log_success "Published ${upload_success} wheel(s) to production PyPI"
}

# Check if GitHub release exists
check_github_release_exists() {
    local tag="$1"

    log_info "Checking if GitHub release $tag exists..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would check: gh release view $tag"
        return 1  # Assume doesn't exist in dry-run
    fi

    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI not found, cannot check existing releases"
        return 1  # Can't check, assume doesn't exist
    fi

    # Check if release exists
    if gh release view "$tag" &>/dev/null; then
        log_warning "GitHub release $tag already exists"
        return 0  # Release exists
    fi

    log_info "GitHub release $tag not found"
    return 1  # Release doesn't exist
}

# Create GitHub release for single wheel
create_github_release() {
    if [[ $SKIP_GITHUB -eq 1 ]]; then
        log_info "Skipping GitHub release (--skip-github specified)"
        return 0
    fi

    log_info "Creating GitHub release..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would create GitHub release with gh cli"
        return 0
    fi

    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) not found. Skipping release creation."
        log_info "Install with: https://cli.github.com/"
        return 0
    fi

    # Check if we're in a git repo
    if ! git rev-parse --git-dir &>/dev/null; then
        log_warning "Not in a git repository. Skipping GitHub release."
        return 0
    fi

    # Use detected version
    if [[ -z "$DETECTED_VERSION" ]]; then
        log_warning "Version not detected. Skipping GitHub release."
        return 0
    fi

    local tag="v${DETECTED_VERSION}-${VARIANT}"

    # Check if release already exists
    if check_github_release_exists "$tag"; then
        log_warning "Skipping GitHub release creation - release already exists"
        log_info "Existing release: $tag"
        return 0
    fi

    local release_title="vLLM CPU ${VARIANT} v${DETECTED_VERSION}"
    local release_notes="Release of ${PACKAGE_NAME} v${DETECTED_VERSION}

Built from vLLM v${DETECTED_VERSION}
Variant: ${VARIANT}

## Installation

\`\`\`bash
pip install ${PACKAGE_NAME}
\`\`\`

## Verification

\`\`\`bash
python -c 'import vllm; print(vllm.__version__)'
\`\`\`
"

    log_info "Creating release: $tag"

    if ! gh release create "$tag" \
         --title "$release_title" \
         --notes "$release_notes" \
         "$WHEEL_PATH"; then
        log_error "Failed to create GitHub release"
        return 1
    fi

    log_success "GitHub release created: $tag"
}

# Create GitHub releases for all wheels
create_all_github_releases() {
    if [[ $SKIP_GITHUB -eq 1 ]]; then
        log_info "Skipping GitHub releases (--skip-github specified)"
        return 0
    fi

    log_info "Creating GitHub releases for ${#WHEEL_PATHS[@]} wheel(s)..."

    if [[ $DRY_RUN -eq 1 ]]; then
        for idx in "${!WHEEL_PATHS[@]}"; do
            local pkg="${PACKAGE_NAMES[$idx]}"
            local ver="${DETECTED_VERSIONS[$idx]}"
            local wheel="${WHEEL_PATHS[$idx]}"
            local variant_name

            # Extract variant name from package name (e.g., vllm-cpu-avx512 -> vllm-cpu-avx512)
            variant_name="${pkg#vllm-}"

            log_info "[DRY RUN] Would create release: v${ver}-${variant_name}"
            log_info "[DRY RUN] Would attach wheel: $(basename "$wheel")"
        done
        return 0
    fi

    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) not found. Skipping release creation."
        log_info "Install with: https://cli.github.com/"
        return 0
    fi

    # Check if we're in a git repo
    if ! git rev-parse --git-dir &>/dev/null; then
        log_warning "Not in a git repository. Skipping GitHub releases."
        return 0
    fi

    local failed=0
    local success_count=0
    local idx

    for idx in "${!WHEEL_PATHS[@]}"; do
        local pkg="${PACKAGE_NAMES[$idx]}"
        local ver="${DETECTED_VERSIONS[$idx]}"
        local wheel="${WHEEL_PATHS[$idx]}"

        log_info "=========================================="
        log_info "Creating release $((idx+1))/${#WHEEL_PATHS[@]}: $pkg"
        log_info "=========================================="

        # Extract variant name from package name
        local variant_name
        variant_name="${pkg#vllm-}"

        # Handle special case where package name is just "vllm"
        if [[ "$variant_name" == "$pkg" ]]; then
            variant_name="cpu"
        fi

        local tag="v${ver}-${variant_name}"

        # Check if release already exists
        if check_github_release_exists "$tag"; then
            log_warning "Release $tag already exists, skipping"
            ((success_count++))
            continue
        fi

        local release_title="vLLM CPU ${variant_name} v${ver}"
        local release_notes="Release of ${pkg} v${ver}

Built from vLLM v${ver}
Variant: ${variant_name}

## Installation

\`\`\`bash
pip install ${pkg}
\`\`\`

## Verification

\`\`\`bash
python -c 'import vllm; print(vllm.__version__)'
\`\`\`
"

        log_info "Creating release: $tag"
        log_info "Attaching wheel: $(basename "$wheel")"

        if ! gh release create "$tag" \
             --title "$release_title" \
             --notes "$release_notes" \
             "$wheel"; then
            log_error "Failed to create GitHub release for $pkg"
            failed=1
            continue
        fi

        log_success "✓ GitHub release created: $tag"
        ((success_count++))
    done

    if [[ $failed -eq 1 ]]; then
        log_warning "Some GitHub releases failed (created $success_count/${#WHEEL_PATHS[@]})"
        return 1
    fi

    log_success "All ${#WHEEL_PATHS[@]} GitHub release(s) created successfully"
}

# Process a single vLLM version: build all Python versions, then publish
# Arguments: $1 = vllm_version, $2 = variant, $3 = python_versions (space or comma-separated)
process_single_version() {
    local vllm_ver="$1"
    local variant="$2"
    local python_vers="$3"

    # Convert space-separated to comma-separated for build scripts
    python_vers="${python_vers// /,}"

    log_step "════════════════════════════════════════════════════════════"
    log_step "Processing $variant @ vLLM $vllm_ver (Python: $python_vers)"
    log_step "════════════════════════════════════════════════════════════"
    echo ""

    # Temporarily set VLLM_VERSION for this iteration
    local saved_vllm_version="$VLLM_VERSION"
    VLLM_VERSION="$vllm_ver"

    # Reset wheel arrays for this version
    WHEEL_PATHS=()
    PACKAGE_NAMES=()
    DETECTED_VERSIONS=()

    # Determine if we're processing multiple wheels (all variants)
    local multi_wheel=0
    if [[ "$variant" == "all" ]]; then
        multi_wheel=1
    fi

    # If --update-readme mode, just update existing wheels and exit early
    if [[ $UPDATE_README -eq 1 ]]; then
        log_info "=== README Update Mode (vLLM $vllm_ver) ==="
        log_info "Updating README in existing wheels (no rebuild, no upload)"

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would update README in wheels for $variant @ vLLM $vllm_ver"
        else
            if ! update_readme_in_wheels "$variant" "$vllm_ver"; then
                log_error "Failed to update README in wheels"
                VLLM_VERSION="$saved_vllm_version"
                return 1
            fi
        fi

        log_success "README update complete for $variant @ vLLM $vllm_ver"
        log_info "Updated wheels are in: $DIST_DIR"
        VLLM_VERSION="$saved_vllm_version"
        return 0
    fi

    # If rename mode (--skip-build + --version-suffix), rename existing wheels with version suffix and then publish
    if [[ $SKIP_BUILD -eq 1 ]] && [[ -n "$VERSION_SUFFIX" ]]; then
        log_info "=== Rename Wheels Mode (vLLM $vllm_ver) ==="
        log_info "Renaming existing wheels with suffix: $VERSION_SUFFIX"

        if ! rename_wheels_with_suffix "$variant" "$vllm_ver" "$VERSION_SUFFIX"; then
            log_error "Failed to rename wheels"
            VLLM_VERSION="$saved_vllm_version"
            return 1
        fi

        log_success "Wheels renamed for $variant @ vLLM $vllm_ver"

        # After renaming, find the renamed wheels and continue with publish
        local new_version="${vllm_ver}${VERSION_SUFFIX}"
        log_info "Looking for renamed wheels with version: $new_version"

        # Find the renamed wheels (skip in dry-run since they won't exist yet)
        WHEEL_PATHS=()
        PACKAGE_NAMES=()
        DETECTED_VERSIONS=()

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would look for wheels with version: $new_version"
            log_info "[DRY RUN] Would verify and publish renamed wheels"
            log_success "[DRY RUN] Rename mode complete for $variant @ vLLM $vllm_ver"
            VLLM_VERSION="$saved_vllm_version"
            return 0
        fi

        local variant_pattern="${variant//-/_}"
        shopt -s nullglob
        for wheel in "$DIST_DIR"/${variant_pattern}-${new_version}-*.whl \
                     "$DIST_DIR"/**/${variant_pattern}-${new_version}-*.whl; do
            if [[ -f "$wheel" ]]; then
                WHEEL_PATHS+=("$wheel")
                PACKAGE_NAMES+=("$variant")
                DETECTED_VERSIONS+=("$new_version")
            fi
        done
        shopt -u nullglob

        if [[ ${#WHEEL_PATHS[@]} -eq 0 ]]; then
            log_error "No renamed wheels found for $variant @ vLLM $new_version"
            VLLM_VERSION="$saved_vllm_version"
            return 1
        fi

        log_info "Found ${#WHEEL_PATHS[@]} renamed wheel(s)"

        # Continue with verification and publish (skip build phase)
        # Fall through to verification and publish phases below
    fi

    # Phase 1: Build wheels for this version (skip if rename mode)
    if [[ $SKIP_BUILD -eq 1 ]] && [[ -n "$VERSION_SUFFIX" ]]; then
        log_info "=== Phase 1: Build (Skipped - using renamed wheels) ==="
    else
        log_info "=== Phase 1: Build and Validate (vLLM $vllm_ver) ==="
    fi

    # Check if all wheels for this variant+version already exist locally
    local needs_build=0
    local package_name
    package_name=$(normalize_variant "$variant") || package_name="$variant"

    # Convert python_vers to array for checking
    local py_vers_array
    IFS=',' read -ra py_vers_array <<< "$python_vers"

    for pyver in "${py_vers_array[@]}"; do
        if ! check_wheel_exists_locally "$package_name" "$vllm_ver" "$pyver"; then
            needs_build=1
            log_info "Wheel for Python $pyver not found locally - build needed"
            break
        fi
    done

    if [[ $needs_build -eq 0 ]]; then
        log_info "All wheels for $variant @ vLLM $vllm_ver already exist locally - skipping build"
    fi

    if [[ $SKIP_BUILD -eq 0 ]] && [[ $needs_build -eq 1 ]]; then
        log_info "Building wheels for vLLM $vllm_ver..."

        # Build using the appropriate builder
        local build_cmd=""
        if [[ "$BUILDER" == "docker" ]]; then
            build_cmd="./docker-buildx.sh --variant=$variant"
            build_cmd="$build_cmd --vllm-versions=$vllm_ver"
            build_cmd="$build_cmd --python-versions=$python_vers"
            build_cmd="$build_cmd --platform=$PLATFORM"
            build_cmd="$build_cmd --max-jobs=$MAX_JOBS"
            build_cmd="$build_cmd --output-dir=$DIST_DIR"
            [[ -n "$VERSION_SUFFIX" ]] && build_cmd="$build_cmd --version-suffix=$VERSION_SUFFIX"
        else
            build_cmd="./build_wheels.sh --variant=$variant"
            build_cmd="$build_cmd --vllm-versions=$vllm_ver"
            build_cmd="$build_cmd --python-versions=$python_vers"
            build_cmd="$build_cmd --max-jobs=$MAX_JOBS"
            build_cmd="$build_cmd --output-dir=$DIST_DIR"
            [[ -n "$VERSION_SUFFIX" ]] && build_cmd="$build_cmd --version-suffix=$VERSION_SUFFIX"
        fi

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would run: $build_cmd"
        else
            log_info "Running: $build_cmd"
            if ! eval "$build_cmd"; then
                log_error "Build failed for vLLM $vllm_ver"
                VLLM_VERSION="$saved_vllm_version"
                return 1
            fi

        fi
    elif [[ $SKIP_BUILD -eq 1 ]]; then
        log_info "Skipping build (--skip-build specified)"
    fi

    # Find wheels for this specific variant and version
    # Wheels are in platform subdirectories: dist/linux_amd64/, dist/linux_arm64/
    # Convert variant name to wheel pattern (vllm-cpu -> vllm_cpu)
    local variant_pattern="${variant//-/_}"

    # Determine platform filter for wheel discovery
    local platform_filter=""
    local platform_subdir=""
    case "$PLATFORM" in
        linux/arm64|arm64|aarch64)
            platform_filter="aarch64"
            platform_subdir="linux_arm64"
            ;;
        linux/amd64|amd64|x86_64)
            platform_filter="x86_64"
            platform_subdir="linux_amd64"
            ;;
        all|auto|"")
            platform_filter=""  # Any platform
            platform_subdir=""
            ;;
        *)
            platform_filter=""  # Unknown, any platform
            platform_subdir=""
            ;;
    esac

    if [[ -n "$platform_filter" ]]; then
        log_info "Locating $platform_filter wheels for $variant @ vLLM $vllm_ver..."
    else
        log_info "Locating wheels for $variant @ vLLM $vllm_ver..."
    fi

    shopt -s nullglob
    local version_wheels=()

    # Build exact version pattern: VERSION- or VERSION+SUFFIX-
    # This prevents matching suffix versions when looking for base version
    local search_version="${vllm_ver}${VERSION_SUFFIX}"
    local exact_pattern="${search_version}-"

    # Search based on platform filter
    if [[ -n "$platform_subdir" ]]; then
        # Specific platform - only search in that platform's directory
        for whl in "$DIST_DIR"/${platform_subdir}/"${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                   "$DIST_DIR"/${platform_subdir}/"${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl \
                   "$DIST_DIR"/"${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                   "$DIST_DIR"/"${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl; do
            if [[ -f "$whl" ]]; then
                version_wheels+=("$whl")
            fi
        done
    else
        # All platforms - search everywhere
        for whl in "$DIST_DIR"/linux_*/"${variant_pattern}"-${exact_pattern}*.whl \
                   "$DIST_DIR"/linux_*/"${variant_pattern}"_${exact_pattern}*.whl \
                   "$DIST_DIR"/"${variant_pattern}"-${exact_pattern}*.whl \
                   "$DIST_DIR"/"${variant_pattern}"_${exact_pattern}*.whl; do
            if [[ -f "$whl" ]]; then
                version_wheels+=("$whl")
            fi
        done
    fi
    shopt -u nullglob

    # Remove duplicates (in case same wheel exists in multiple locations)
    local unique_wheels=()
    local seen_basenames=()
    for whl in "${version_wheels[@]}"; do
        local bn
        bn=$(basename "$whl")
        if [[ ! " ${seen_basenames[*]} " =~ " ${bn} " ]]; then
            unique_wheels+=("$whl")
            seen_basenames+=("$bn")
        fi
    done
    version_wheels=("${unique_wheels[@]}")

    if [[ ${#version_wheels[@]} -eq 0 ]] && [[ $DRY_RUN -eq 0 ]]; then
        log_error "No wheels found for $variant @ vLLM $search_version"
        log_error "Expected pattern: ${variant_pattern}-${search_version}-*.whl"
        VLLM_VERSION="$saved_vllm_version"
        return 1
    fi

    log_info "Found ${#version_wheels[@]} wheel(s) for $variant @ vLLM $vllm_ver"

    # Populate wheel arrays (needed for both dry-run and real mode)
    for wheel in "${version_wheels[@]}"; do
        WHEEL_PATHS+=("$wheel")
        local pkg_name
        pkg_name=$(basename "$wheel" | sed 's/-[0-9].*//' | tr '_' '-')
        PACKAGE_NAMES+=("$pkg_name")
        DETECTED_VERSIONS+=("$vllm_ver")
        log_info "  - $(basename "$wheel")"
    done

    # Validate wheels with twine (skip in dry-run mode)
    if [[ $DRY_RUN -eq 0 ]]; then
        validate_all_wheels || {
            VLLM_VERSION="$saved_vllm_version"
            return 1
        }
    fi
    echo ""

    # Verify wheel integrity (with rebuild-on-failure)
    log_info "=== Wheel Verification (vLLM $vllm_ver) ==="
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would verify wheel integrity for $variant @ vLLM $vllm_ver"
    else
        local max_rebuild_attempts=2
        local rebuild_attempt=0
        local verification_passed=0

        while [[ $rebuild_attempt -lt $max_rebuild_attempts ]] && [[ $verification_passed -eq 0 ]]; do
            if verify_wheels_for_variant "$variant" "$vllm_ver"; then
                verification_passed=1
                log_success "Wheel verification passed for $variant @ vLLM $vllm_ver"
            else
                ((rebuild_attempt++)) || true
                if [[ $rebuild_attempt -lt $max_rebuild_attempts ]]; then
                    log_warning "Wheel verification failed (attempt $rebuild_attempt/$max_rebuild_attempts)"
                    log_info "Rebuilding wheels..."

                    # Remove failed wheels
                    for whl in "${version_wheels[@]}"; do
                        if [[ -f "$whl" ]]; then
                            rm -f "$whl"
                            log_info "Removed failed wheel: $(basename "$whl")"
                        fi
                    done

                    # Clear wheel arrays for rebuild
                    WHEEL_PATHS=()
                    PACKAGE_NAMES=()
                    DETECTED_VERSIONS=()
                    version_wheels=()

                    # Force rebuild
                    local rebuild_cmd=""
                    if [[ "$BUILDER" == "docker" ]]; then
                        rebuild_cmd="./docker-buildx.sh --variant=$variant"
                        rebuild_cmd="$rebuild_cmd --vllm-versions=$vllm_ver"
                        rebuild_cmd="$rebuild_cmd --python-versions=$python_vers"
                        rebuild_cmd="$rebuild_cmd --platform=$PLATFORM"
                        rebuild_cmd="$rebuild_cmd --max-jobs=$MAX_JOBS"
                        rebuild_cmd="$rebuild_cmd --output-dir=$DIST_DIR"
                        [[ -n "$VERSION_SUFFIX" ]] && rebuild_cmd="$rebuild_cmd --version-suffix=$VERSION_SUFFIX"
                    else
                        rebuild_cmd="./build_wheels.sh --variant=$variant"
                        rebuild_cmd="$rebuild_cmd --vllm-versions=$vllm_ver"
                        rebuild_cmd="$rebuild_cmd --python-versions=$python_vers"
                        rebuild_cmd="$rebuild_cmd --max-jobs=$MAX_JOBS"
                        rebuild_cmd="$rebuild_cmd --output-dir=$DIST_DIR"
                        [[ -n "$VERSION_SUFFIX" ]] && rebuild_cmd="$rebuild_cmd --version-suffix=$VERSION_SUFFIX"
                    fi

                    log_info "Running: $rebuild_cmd"
                    if ! eval "$rebuild_cmd"; then
                        log_error "Rebuild failed for vLLM $vllm_ver"
                        VLLM_VERSION="$saved_vllm_version"
                        return 1
                    fi

                    # Re-locate wheels after rebuild (using same exact version pattern)
                    # search_version and exact_pattern were defined earlier
                    shopt -s nullglob
                    if [[ -n "$platform_subdir" ]]; then
                        # Platform-specific search
                        for whl in "$DIST_DIR"/${platform_subdir}/"${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                                   "$DIST_DIR"/${platform_subdir}/"${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl \
                                   "$DIST_DIR"/"${variant_pattern}"-${exact_pattern}*${platform_filter}*.whl \
                                   "$DIST_DIR"/"${variant_pattern}"_${exact_pattern}*${platform_filter}*.whl; do
                            if [[ -f "$whl" ]]; then
                                version_wheels+=("$whl")
                            fi
                        done
                    else
                        for whl in "$DIST_DIR"/linux_*/"${variant_pattern}"-${exact_pattern}*.whl \
                                   "$DIST_DIR"/linux_*/"${variant_pattern}"_${exact_pattern}*.whl \
                                   "$DIST_DIR"/"${variant_pattern}"-${exact_pattern}*.whl \
                                   "$DIST_DIR"/"${variant_pattern}"_${exact_pattern}*.whl; do
                            if [[ -f "$whl" ]]; then
                                version_wheels+=("$whl")
                            fi
                        done
                    fi
                    shopt -u nullglob

                    # Repopulate wheel arrays
                    for wheel in "${version_wheels[@]}"; do
                        WHEEL_PATHS+=("$wheel")
                        local pkg_name
                        pkg_name=$(basename "$wheel" | sed 's/-[0-9].*//' | tr '_' '-')
                        PACKAGE_NAMES+=("$pkg_name")
                        DETECTED_VERSIONS+=("$vllm_ver")
                    done
                else
                    log_error "Wheel verification failed after $max_rebuild_attempts attempts"
                    VLLM_VERSION="$saved_vllm_version"
                    return 1
                fi
            fi
        done
    fi
    echo ""

    # Phase 2: Production PyPI publish
    log_info "=== Phase 2: Production Publish (vLLM $vllm_ver) ==="
    if [[ $DRY_RUN -eq 0 ]]; then
        log_success "Verification passed for vLLM $vllm_ver! Publishing to PyPI..."
    fi
    publish_to_production_pypi || {
        VLLM_VERSION="$saved_vllm_version"
        return 1
    }
    echo ""

    # Phase 3: GitHub release
    log_info "=== Phase 3: GitHub Release (vLLM $vllm_ver) ==="
    create_all_github_releases || log_warning "Some GitHub releases failed (non-fatal)"
    echo ""

    log_success "✓ Completed processing vLLM $vllm_ver"
    VLLM_VERSION="$saved_vllm_version"
    return 0
}

# Main workflow
main() {
    parse_args "$@"

    # Parse Python version(s) into PYTHON_VERSIONS array
    parse_python_versions "$PYTHON_VERSION" || exit 1

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     vLLM CPU Build-Verify-Publish Pipeline v${SCRIPT_VERSION}          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check and install dependencies
    check_and_install_dependencies || exit 1
    echo ""

    # Normalize default variant if not already normalized
    if [[ "$VARIANT" == "noavx512" ]]; then
        VARIANT=$(normalize_variant "$VARIANT")
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
    fi

    log_info "Starting build-verify-publish workflow"
    log_info "Variant: $VARIANT"
    log_info "Python: $PYTHON_VERSION"
    log_info "Builder: $BUILDER"
    [[ "$BUILDER" == "docker" ]] && log_info "Platform: $PLATFORM"
    [[ -n "$VLLM_VERSION" ]] && log_info "vLLM version(s): $VLLM_VERSION"
    echo ""

    # Parse vLLM versions into array
    local vllm_versions_array=()
    if [[ -n "$VLLM_VERSION" ]]; then
        IFS=',' read -ra vllm_versions_array <<< "$VLLM_VERSION"
    else
        log_error "vLLM version is required (--vllm-versions=X.Y.Z)"
        exit 1
    fi

    # Determine variants to process
    local all_variants=()
    if [[ "$VARIANT" == "all" ]]; then
        all_variants=("vllm-cpu" "vllm-cpu-avx512" "vllm-cpu-avx512vnni" "vllm-cpu-avx512bf16" "vllm-cpu-amxbf16")
    else
        all_variants=("$VARIANT")
    fi

    # Filter variants by platform (e.g., ARM64 only supports vllm-cpu)
    local filtered_variants
    filtered_variants=$(filter_variants_by_platform "$PLATFORM" "${all_variants[@]}")
    read -ra variants_array <<< "$filtered_variants"

    if [[ ${#variants_array[@]} -eq 0 ]]; then
        log_error "No variants support platform: $PLATFORM"
        exit 1
    fi

    if [[ ${#variants_array[@]} -ne ${#all_variants[@]} ]]; then
        log_info "Platform $PLATFORM: filtered to ${#variants_array[@]} variant(s): ${variants_array[*]}"
    fi

    # Detect rename mode: --skip-build + --version-suffix means rename existing wheels
    local RENAME_MODE=0
    if [[ $SKIP_BUILD -eq 1 ]] && [[ -n "$VERSION_SUFFIX" ]]; then
        RENAME_MODE=1
        log_info "Rename mode enabled: will rename existing wheels with suffix $VERSION_SUFFIX"
    fi

    # Phase 0: Pre-flight checks (skip for --update-readme and rename modes)
    if [[ $UPDATE_README -eq 1 ]]; then
        log_info "=== README Update Mode - Skipping Pre-flight Checks ==="
        log_info "Will update README in existing local wheels (no rebuild, no upload)"
    elif [[ $RENAME_MODE -eq 1 ]]; then
        log_info "=== Rename Wheels Mode - Skipping Pre-flight Checks ==="
        log_info "Will rename existing wheels with suffix: $VERSION_SUFFIX"
    else
        log_info "=== Phase 0: Pre-flight Checks ==="
        local preflight_result=0
        run_preflight_checks || preflight_result=$?

        if [[ $preflight_result -eq 2 ]]; then
            # Nothing to do - all packages already published
            log_success "All requested packages are already published on PyPI!"
            log_info "Nothing to build or publish."
            exit 0
        elif [[ $preflight_result -ne 0 ]]; then
            log_error "Pre-flight checks failed"
            exit 1
        fi
    fi
    echo ""

    # Processing order: Variant → vLLM version → Python versions → Publish
    # This ensures each variant+version combination is fully built and published
    # before moving to the next
    local total_variants=${#variants_array[@]}
    local total_versions=${#vllm_versions_array[@]}
    local total_combinations=$((total_variants * total_versions))
    local current_combination=0
    local failed_combinations=()
    local successful_combinations=()

    log_info "Processing order: Variant → vLLM version → Build all Python → Publish"
    log_info "Total variants: $total_variants"
    log_info "Total vLLM versions: $total_versions"
    log_info "Total combinations: $total_combinations"
    echo ""

    for current_variant in "${variants_array[@]}"; do
        echo ""
        log_step "╔══════════════════════════════════════════════════════════════════╗"
        log_step "║  VARIANT: $current_variant"
        log_step "╚══════════════════════════════════════════════════════════════════╝"
        echo ""

        for vllm_ver in "${vllm_versions_array[@]}"; do
            ((current_combination++)) || true
            echo ""
            log_step "┌──────────────────────────────────────────────────────────────────┐"
            log_step "│  [$current_combination/$total_combinations] $current_variant @ vLLM $vllm_ver"
            log_step "└──────────────────────────────────────────────────────────────────┘"
            echo ""

            # Get version-aware Python versions for this vLLM version
            local supported_py_versions
            if [[ "${PYTHON_VERSIONS[0]}" == "auto" ]]; then
                # Auto mode: detect all supported versions from vLLM's pyproject.toml
                supported_py_versions=$(get_auto_python_versions "$vllm_ver")
            else
                # Manual mode: filter requested versions against vLLM's requirements
                supported_py_versions=$(get_supported_python_versions "$vllm_ver" "${PYTHON_VERSIONS[@]}")
            fi

            if [[ -z "$supported_py_versions" ]]; then
                log_warning "No supported Python versions for vLLM $vllm_ver - skipping"
                continue
            fi

            log_info "Python versions for vLLM $vllm_ver: $supported_py_versions"

            # Process this single variant+version combination
            if process_single_version "$vllm_ver" "$current_variant" "$supported_py_versions"; then
                successful_combinations+=("$current_variant@$vllm_ver")
                log_success "✓ Completed: $current_variant @ vLLM $vllm_ver"
            else
                failed_combinations+=("$current_variant@$vllm_ver")
                log_error "✗ Failed: $current_variant @ vLLM $vllm_ver"
                # Continue with next combination instead of exiting
            fi
        done

        log_success "Completed all vLLM versions for variant: $current_variant"
    done

    # Final Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log_step "Final Summary"
    echo "═══════════════════════════════════════════════════════════════"

    if [[ ${#successful_combinations[@]} -gt 0 ]]; then
        log_success "Successfully processed ${#successful_combinations[@]} combination(s):"
        for combo in "${successful_combinations[@]}"; do
            log_info "  ✓ $combo"
        done
    fi

    if [[ ${#failed_combinations[@]} -gt 0 ]]; then
        log_error "Failed to process ${#failed_combinations[@]} combination(s):"
        for combo in "${failed_combinations[@]}"; do
            log_info "  ✗ $combo"
        done
        exit 1
    fi

    log_success "Complete workflow finished successfully!"
}

main "$@"
