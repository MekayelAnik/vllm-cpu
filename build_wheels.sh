#!/usr/bin/env bash
#
# Build vLLM CPU wheels for PyPI distribution
# Builds 5 variants: noavx512, avx512, avx512vnni, avx512bf16, amxbf16
#
# Version: 2.3.0
# Bash Version Required: 4.0+
#
# Usage:
#   ./build_wheels.sh [OPTIONS]
#
# Options:
#   --variant=NAME              Build specific variant (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
#                               Use --variant=all to build all 5 variants
#   --vllm-versions=VERSION     vLLM version(s) to build (default: latest from git)
#                               Accepts: single (0.11.0) or multiple (0.10.0,0.10.1,0.11.0)
#                               Alias: --vllm-version (deprecated, use --vllm-versions)
#   --python-versions=VERSION   Python version(s) to build (default: 3.12)
#                               Accepts: single (3.12), multiple (3.10,3.11,3.12), range (3.10-3.13),
#                               or "auto" to detect from vLLM's pyproject.toml
#                               Alias: --python-version (deprecated, use --python-versions)
#   --version-suffix=SUFFIX     Add version suffix for re-uploading (e.g., .post1, .post2, .dev1)
#                               Required when re-uploading previously deleted wheels (PyPI filename policy)
#                               Only .postN and .devN are valid (PEP 440 compliant)
#                               Example: --version-suffix=.post1 turns 0.11.0 into 0.11.0.post1
#   --output-dir=PATH           Output directory for wheels (default: ./dist)
#   --max-jobs=N                Parallel build jobs (default: CPU count)
#   --no-cleanup                Skip cleanup after build
#   --dry-run                   Show what would be done without doing it
#   --help                      Show this help
#
# Examples:
#   # Build all variants for vLLM 0.11.0 with Python 3.10-3.13
#   ./build_wheels.sh --vllm-versions=0.11.0 --python-versions=3.10-3.13
#
#   # Build specific variant for multiple vLLM versions
#   ./build_wheels.sh --variant=vllm-cpu-avx512bf16 --vllm-versions=0.10.0,0.10.1,0.11.0
#
#   # Build version matrix: 3 vLLM versions × 4 Python versions = 12 wheels per variant
#   ./build_wheels.sh --vllm-versions=0.10.0,0.11.0,0.11.1 --python-versions=3.10-3.13
#
#   # Re-upload deleted wheel with .post1 suffix (PyPI immutable filename policy workaround)
#   ./build_wheels.sh --variant=vllm-cpu-avx512 --vllm-versions=0.10.0 --version-suffix=.post1
#
#   # Auto-detect Python versions from vLLM's pyproject.toml
#   ./build_wheels.sh --vllm-versions=0.11.2 --python-versions=auto
#

# Check Bash version (require 4.0+)
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: This script requires Bash 4.0 or higher" >&2
    echo "Current version: ${BASH_VERSION}" >&2
    echo "Please upgrade Bash or use a different shell" >&2
    exit 1
fi

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# Enable Bash 5.2+ features if available
if [[ "${BASH_VERSINFO[0]}" -ge 5 ]] && [[ "${BASH_VERSINFO[1]}" -ge 2 ]]; then
    shopt -s globskipdots 2>/dev/null || true
fi

# Script metadata
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="2.2.0"

# Color codes (readonly to prevent modification)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging configuration
readonly LOG_TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'

# Default configuration
VARIANT=""
VLLM_VERSION=""
VLLM_VERSIONS=()       # Array of vLLM versions to build (empty = use VLLM_VERSION or latest)
PYTHON_VERSION="3.12"  # Default to 3.12 for broader compatibility
PYTHON_VERSIONS=()     # Array of Python versions to build (empty = use PYTHON_VERSION)
VERSION_SUFFIX=""      # Optional version suffix (e.g., ".post1", ".post2") for re-uploads
OUTPUT_DIR="$SCRIPT_DIR/dist"
MAX_JOBS=$(nproc)
NO_CLEANUP=0
DRY_RUN=0
WORKSPACE="$SCRIPT_DIR/build"
readonly CONFIG_FILE="$SCRIPT_DIR/build_config.json"

# Cleanup state tracking
CLEANUP_DONE=0

# Enhanced logging functions with timestamps and proper stream redirection
log_info() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] [DEBUG] $*" >&2
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
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

# Check and install dependencies
check_and_install_dependencies() {
    log_info "Checking build dependencies..."

    local distro
    distro=$(detect_distro)
    log_info "Detected distribution: $distro"

    # Required packages (common names across distros)
    local -a missing_deps=()
    local -a required_commands=(
        "gcc"
        "g++"
        "cmake"
        "git"
        "curl"
        "wget"
    )

    # Check which commands are missing
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Check for libnuma development files
    if [[ ! -f /usr/include/numa.h ]] && [[ ! -f /usr/include/x86_64-linux-gnu/numa.h ]]; then
        missing_deps+=("libnuma-dev")
    fi

    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_success "All required dependencies are installed"
        return 0
    fi

    log_warning "Missing dependencies: ${missing_deps[*]}"

    # Check if running as root or with sudo
    local install_cmd=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            install_cmd="sudo"
            log_info "Will use sudo to install dependencies"
        else
            log_error "Not running as root and sudo is not available"
            log_error "Please install the following dependencies manually:"
            log_error "  ${missing_deps[*]}"
            return 1
        fi
    fi

    log_info "Installing missing dependencies..."

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            local -a packages=(
                "build-essential"
                "ccache"
                "git"
                "curl"
                "wget"
                "ca-certificates"
                "gcc"
                "g++"
                "python3.13-dev"         # Python development headers
                "python3.13-venv"        # Python venv module
                "python3-pip"            # Pip package manager
                "libtcmalloc-minimal4"  # Google's memory allocator
                "libnuma-dev"           # Verified: Debian/Ubuntu uses -dev suffix
                "jq"
                "lsof"
                "vim"
                "numactl"
                "xz-utils"
                "cmake"
                "ninja-build"           # Verified: Debian/Ubuntu uses ninja-build
            )
            if [[ $DRY_RUN -eq 1 ]]; then
                log_info "[DRY RUN] Would run: $install_cmd apt-get update"
                log_info "[DRY RUN] Would run: $install_cmd apt-get install -y --no-install-recommends ${packages[*]}"
            else
                log_info "Running: apt-get update && apt-get install..."
                $install_cmd apt-get update -qq || log_warning "apt-get update failed"
                $install_cmd apt-get install -y --no-install-recommends "${packages[@]}" || {
                    log_error "Failed to install dependencies"
                    return 1
                }
            fi
            ;;

        fedora|rhel|centos|rocky|almalinux)
            local -a packages=(
                "@development-tools"   # Development tools group
                "ccache"
                "git"
                "curl"
                "wget"
                "ca-certificates"
                "gcc"
                "gcc-c++"
                "python3.13-devel"    # Python development headers
                "gperftools-libs"     # Google's performance tools
                "numactl-devel"       # Verified: RHEL/Fedora uses -devel suffix
                "jq"
                "lsof"
                "vim-enhanced"
                "numactl"
                "xz"
                "cmake"
                "ninja-build"         # Verified: Fedora uses ninja-build
            )
            if [[ $DRY_RUN -eq 1 ]]; then
                log_info "[DRY RUN] Would run: $install_cmd dnf install -y ${packages[*]}"
            else
                log_info "Running: dnf install..."
                $install_cmd dnf install -y "${packages[@]}" || {
                    log_error "Failed to install dependencies"
                    return 1
                }
            fi
            ;;

        opensuse*|sles)
            local -a packages=(
                "patterns-devel-base-devel_basis"
                "ccache"
                "git"
                "curl"
                "wget"
                "ca-certificates"
                "gcc"
                "gcc-c++"
                "python313-devel"      # Python development headers
                "gperftools"
                "libnuma-devel"  # Verified: openSUSE uses libnuma-devel
                "jq"
                "lsof"
                "vim"
                "numactl"
                "xz"
                "cmake"
                "ninja"
            )
            if [[ $DRY_RUN -eq 1 ]]; then
                log_info "[DRY RUN] Would run: $install_cmd zypper install -y ${packages[*]}"
            else
                log_info "Running: zypper install..."
                $install_cmd zypper install -y "${packages[@]}" || {
                    log_error "Failed to install dependencies"
                    return 1
                }
            fi
            ;;

        arch|manjaro)
            local -a packages=(
                "base-devel"
                "ccache"
                "git"
                "curl"
                "wget"
                "ca-certificates"
                "gcc"
                "python"              # Python with development headers
                "gperftools"
                "numactl"  # Verified: Arch's numactl includes dev files
                "jq"
                "lsof"
                "vim"
                "xz"
                "cmake"
                "ninja"
            )
            if [[ $DRY_RUN -eq 1 ]]; then
                log_info "[DRY RUN] Would run: $install_cmd pacman -Sy --noconfirm ${packages[*]}"
            else
                log_info "Running: pacman -Sy..."
                $install_cmd pacman -Sy --noconfirm "${packages[@]}" || {
                    log_error "Failed to install dependencies"
                    return 1
                }
            fi
            ;;

        *)
            log_error "Unsupported distribution: $distro"
            log_error "Please install the following dependencies manually:"
            log_error "  - GCC/G++ compiler"
            log_error "  - CMake (>=3.21)"
            log_error "  - Git"
            log_error "  - curl, wget"
            log_error "  - libnuma development files"
            log_error "  - numactl"
            log_error "  - ninja-build"
            return 1
            ;;
    esac

    log_success "Dependencies installed successfully"
    return 0
}

# Cleanup after each individual wheel build
cleanup_after_wheel() {
    local variant="$1"

    log_info "Cleaning up build artifacts for $variant..."

    if [[ $NO_CLEANUP -eq 1 ]]; then
        log_info "Skipping per-wheel cleanup (--no-cleanup flag set)"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would clean up:"
        log_info "  - Virtual environment: $WORKSPACE/venv/"
        log_info "  - CMake build artifacts: $WORKSPACE/vllm/build/"
        log_info "  - Egg-info directories: $WORKSPACE/vllm/*.egg-info/"
        log_info "  - Python cache: $WORKSPACE/vllm/__pycache__/"
        log_info "  - Temporary wheel directory: $WORKSPACE/wheels-$variant/"
        log_info "  - Git modifications in vLLM repository"
        log_info "  - uv cache: ~/.cache/uv/"
        log_info "  - pip cache: ~/.cache/pip/"
        log_info "  - Temp build files in /tmp"
        return 0
    fi

    # Change to workspace to ensure safe operations
    cd "$WORKSPACE" || {
        log_error "Failed to change to workspace directory"
        return 1
    }

    # Record disk usage before cleanup
    local disk_before
    disk_before=$(du -sb "$WORKSPACE" 2>/dev/null | cut -f1)

    # 1. Remove virtual environment (will be recreated for next build if needed)
    if [[ -d "venv" ]]; then
        log_info "Removing virtual environment..."
        rm -rf venv/ || log_warning "Failed to remove venv/"
    fi

    # 2. Remove CMake build artifacts (largest space consumer: ~125MB)
    if [[ -d "vllm/build" ]]; then
        log_info "Removing CMake build artifacts..."
        rm -rf vllm/build/ || log_warning "Failed to remove build/"
    fi

    # 3. Remove all .egg-info directories
    if compgen -G "vllm/*.egg-info" > /dev/null 2>&1; then
        log_info "Removing .egg-info directories..."
        rm -rf vllm/*.egg-info || log_warning "Failed to remove .egg-info directories"
    fi

    # 4. Remove Python cache
    if [[ -d "vllm/__pycache__" ]]; then
        log_info "Removing Python cache..."
        find vllm/ -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        find vllm/ -type f -name "*.pyc" -delete 2>/dev/null || true
        find vllm/ -type f -name "*.pyo" -delete 2>/dev/null || true
    fi

    # 5. Remove temporary wheel directory
    if [[ -d "wheels-$variant" ]]; then
        log_info "Removing temporary wheel directory..."
        rm -rf "wheels-$variant/" || log_warning "Failed to remove wheels-$variant/"
    fi

    # 6. Reset git repository to clean state (remove any modifications)
    if [[ -d "vllm/.git" ]]; then
        log_info "Resetting vLLM repository to clean state..."
        (cd vllm && \
         git reset --hard HEAD >/dev/null 2>&1 && \
         git clean -fd >/dev/null 2>&1) || \
         log_warning "Failed to reset git repository"
    fi

    # 7. Remove any backup files created during build
    find vllm/ -name "*.backup" -type f -delete 2>/dev/null || true

    # 8. Clean uv cache (can accumulate packages downloaded during build)
    if command -v uv &>/dev/null; then
        log_info "Cleaning uv cache..."
        uv cache clean 2>/dev/null || log_warning "Failed to clean uv cache"
    fi

    # 9. Clean pip cache (if pip was used during build)
    if [[ -d "$HOME/.cache/pip" ]]; then
        log_info "Cleaning pip cache..."
        rm -rf "$HOME/.cache/pip"/* 2>/dev/null || log_warning "Failed to clean pip cache"
    fi

    # 10. Remove temporary build files from /tmp
    # Only remove files that are clearly from this build process
    log_info "Cleaning temporary build files..."
    find /tmp -maxdepth 1 \( \
        -name "pip-*" -o \
        -name "tmp*vllm*" -o \
        -name "tmp*wheel*" -o \
        -name "tmp*build*" -o \
        -name ".tmp*" \
    \) -mmin +5 -exec rm -rf {} + 2>/dev/null || true

    # 11. Remove any setuptools build isolation directories
    if [[ -d "$HOME/.local/share/uv" ]]; then
        log_info "Cleaning uv data directory..."
        rm -rf "$HOME/.local/share/uv"/* 2>/dev/null || log_warning "Failed to clean uv data"
    fi

    # Record disk usage after cleanup
    local disk_after
    disk_after=$(du -sb "$WORKSPACE" 2>/dev/null | cut -f1)

    # Calculate space reclaimed from workspace
    local space_reclaimed=$((disk_before - disk_after))
    local space_mb=$((space_reclaimed / 1024 / 1024))

    log_success "Cleanup complete! Reclaimed ${space_mb}MB of disk space (workspace only)"
    log_info "Workspace size: $(du -sh "$WORKSPACE" 2>/dev/null | cut -f1)"

    # Also report cache sizes if they exist
    if [[ -d "$HOME/.cache/uv" ]]; then
        local uv_cache_size
        uv_cache_size=$(du -sh "$HOME/.cache/uv" 2>/dev/null | cut -f1)
        log_info "uv cache: ${uv_cache_size}"
    fi
    if [[ -d "$HOME/.cache/pip" ]]; then
        local pip_cache_size
        pip_cache_size=$(du -sh "$HOME/.cache/pip" 2>/dev/null | cut -f1)
        log_info "pip cache: ${pip_cache_size}"
    fi
}

# Enhanced cleanup function with double-execution prevention
cleanup() {
    local exit_code=$?

    # Prevent double execution
    if [[ "$CLEANUP_DONE" -eq 1 ]]; then
        return
    fi
    CLEANUP_DONE=1

    # Reset traps to prevent recursion
    trap - EXIT ERR INT TERM

    if [[ $NO_CLEANUP -eq 0 ]]; then
        log_info "Final cleanup at script exit..."
        if [[ -n "${WORKSPACE:-}" ]] && [[ -d "$WORKSPACE" ]]; then
            # Only preserve vLLM git repository (per-wheel cleanup already handled everything else)
            if [[ -d "$WORKSPACE/vllm/.git" ]]; then
                log_info "Preserving vLLM repository, cleaning any remaining artifacts..."
                # Clean any remaining wheel directories
                rm -rf "$WORKSPACE"/wheels-* 2>/dev/null || true
                # Clean any other build artifacts except vllm/
                find "$WORKSPACE" -maxdepth 1 -mindepth 1 ! -name "vllm" -exec rm -rf {} + 2>/dev/null || true
                log_success "Final cleanup complete (vLLM repo preserved)"
            else
                log_warning "Skipping final cleanup (no vLLM repo found to preserve)"
            fi
        fi
    else
        log_info "Skipping final cleanup (workspace: ${WORKSPACE:-unknown})"
    fi

    exit "$exit_code"
}

# Set trap for cleanup (only EXIT, let signals propagate naturally)
trap cleanup EXIT

# Validate Python version format
validate_python_version() {
    local version="$1"
    if ! [[ "$version" =~ ^3\.[0-9]{1,2}(\.[0-9]+)?$ ]]; then
        log_error "Invalid Python version format: $version"
        log_info "Expected format: 3.X or 3.X.Y (e.g., 3.13 or 3.13.1)"
        log_info "For multiple versions use: --python-versions=3.10,3.11,3.12"
        log_info "For version range use: --python-versions=3.10-3.13"
        return 1
    fi
    return 0
}

# Parse --python-versions parameter (supports comma-separated list, range, or "auto")
# When "auto" is specified, Python versions will be detected from vLLM's pyproject.toml
# at build time for each vLLM version
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

        log_info "Building for Python 3.$start through 3.$end"
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

    log_info "Will build for Python versions: ${PYTHON_VERSIONS[*]}"
    return 0
}

# Parse --vllm-version parameter (supports comma-separated list)
parse_vllm_versions() {
    local input="$1"
    VLLM_VERSIONS=()  # Clear array

    # Comma-separated list (e.g., "0.10.0,0.10.1,0.11.0")
    IFS=',' read -ra versions <<< "$input"
    for ver in "${versions[@]}"; do
        ver=$(echo "$ver" | tr -d ' ')  # Remove whitespace
        if [[ -z "$ver" ]]; then
            continue
        fi
        # Validate version format (allow v prefix or plain version)
        if [[ "$ver" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?$ ]]; then
            # Remove 'v' prefix if present for consistency
            ver="${ver#v}"
            VLLM_VERSIONS+=("$ver")
        else
            log_error "Invalid vLLM version format: $ver"
            log_info "Expected format: X.Y.Z or X.Y.Z.W (e.g., 0.11.0 or 0.10.1.1)"
            return 1
        fi
    done

    if [[ ${#VLLM_VERSIONS[@]} -eq 0 ]]; then
        log_error "No valid vLLM versions provided"
        return 1
    fi

    log_info "Will build for vLLM versions: ${VLLM_VERSIONS[*]}"
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
    local requested_versions=("${@:2}")  # All arguments after the first
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

    # If fetch failed, use hardcoded fallback based on known vLLM history
    if [[ -z "$requires_python" ]]; then
        log_warning "Could not fetch requires-python for vLLM $vllm_ver from GitHub, using fallback"
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

    # Default min/max if not specified
    min_py="${min_py:-3.10}"
    max_py="${max_py:-3.14}"  # Reasonable default upper limit

    local min_minor="${min_py#*.}"
    local max_minor="${max_py#*.}"

    # Generate all versions in range (max is exclusive)
    local versions=()
    for ((i=min_minor; i<max_minor; i++)); do
        versions+=("3.$i")
    done

    log_info "Auto-detected Python versions for vLLM $vllm_ver: ${versions[*]}"
    echo "${versions[*]}"
}

# Validate MAX_JOBS
validate_max_jobs() {
    local jobs="$1"
    if ! [[ "$jobs" =~ ^[0-9]+$ ]]; then
        log_error "MAX_JOBS must be a positive integer, got: $jobs"
        return 1
    fi
    if [[ "$jobs" -lt 1 ]]; then
        log_error "MAX_JOBS must be at least 1"
        return 1
    fi
    return 0
}

# Enhanced path validation with comprehensive dangerous path checking
is_safe_path() {
    local path="$1"

    # List of dangerous paths
    local -ar dangerous_paths=(
        "/"
        "/root"
        "/home"
        "/usr"
        "/etc"
        "/var"
        "/bin"
        "/sbin"
        "/lib"
        "/lib64"
        "/boot"
        "/sys"
        "/proc"
        "/dev"
    )

    # Check against dangerous paths
    local dangerous
    for dangerous in "${dangerous_paths[@]}"; do
        if [[ "$path" == "$dangerous" ]] || [[ "$path" == "${dangerous}/"* ]]; then
            return 1
        fi
    done

    return 0
}

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
                local versions_input="${1#*=}"
                # Auto-detect if it's a single version or comma-separated list
                if [[ "$versions_input" == *","* ]]; then
                    # Multiple versions
                    parse_vllm_versions "$versions_input"
                else
                    # Single version
                    VLLM_VERSION="$versions_input"
                fi
                shift
                ;;
            --python-version=*|--python-versions=*)
                local versions_input="${1#*=}"
                # Auto-detect if it's auto, a single version, range, or comma-separated list
                if [[ "$versions_input" == "auto" ]] || [[ "$versions_input" == *","* ]] || [[ "$versions_input" == *"-"* ]]; then
                    # Auto mode, multiple versions, or range - use parse_python_versions
                    parse_python_versions "$versions_input"
                else
                    # Single version
                    PYTHON_VERSION="$versions_input"
                    if ! validate_python_version "$PYTHON_VERSION"; then
                        exit 1
                    fi
                fi
                shift
                ;;
            --output-dir=*)
                OUTPUT_DIR="${1#*=}"
                shift
                ;;
            --max-jobs=*)
                MAX_JOBS="${1#*=}"
                if ! validate_max_jobs "$MAX_JOBS"; then
                    exit 1
                fi
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=1
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

# Get build configuration for a variant
get_build_config() {
    local variant="$1"
    local field="$2"

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi

    if [[ ! -r "$CONFIG_FILE" ]]; then
        log_error "Config file not readable: $CONFIG_FILE"
        exit 1
    fi

    # Validate JSON
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "Invalid JSON in config file: $CONFIG_FILE"
        exit 1
    fi

    local result
    result=$(jq -r ".builds.\"${variant}\".${field}" "$CONFIG_FILE" 2>/dev/null) || {
        log_error "Failed to read field: builds.${variant}.${field}"
        exit 1
    }

    if [[ "$result" == "null" ]] || [[ -z "$result" ]]; then
        log_error "Field not found or empty: builds.${variant}.${field}"
        exit 1
    fi

    printf '%s' "$result"
}

# Get all variants
get_all_variants() {
    if ! jq -r '.builds | keys[]' "$CONFIG_FILE" 2>/dev/null; then
        log_error "Failed to get variants from config file"
        exit 1
    fi
}

# Escape special characters for sed
escape_sed() {
    local string="$1"
    # Escape forward slashes, backslashes, ampersands, and double quotes
    printf '%s' "$string" | sed 's/[\\/&]/\\&/g' | sed 's/"/\\"/g'
}

# Execute command or show what would be executed in dry-run mode
run_cmd() {
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would execute: $*"
        return 0
    else
        "$@"
    fi
}

# Build a single variant with timeout support
build_variant() {
    local variant="$1"

    log_info "Building variant: $variant"

    # Save the requested vLLM version before it gets overwritten
    local requested_vllm_version="$VLLM_VERSION"

    # Get configuration with proper quoting
    local package_name
    local description
    local readme_file
    local disable_avx512
    local enable_vnni
    local enable_bf16
    local enable_amx

    package_name="$(get_build_config "$variant" "package_name")"
    description="$(get_build_config "$variant" "description")"
    readme_file="$(get_build_config "$variant" "readme_file")"
    disable_avx512="$(get_build_config "$variant" "flags.disable_avx512")"
    enable_vnni="$(get_build_config "$variant" "flags.enable_avx512vnni")"
    enable_bf16="$(get_build_config "$variant" "flags.enable_avx512bf16")"
    enable_amx="$(get_build_config "$variant" "flags.enable_amxbf16")"

    # Validate package name format
    if ! [[ "$package_name" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Invalid package name format: $package_name"
        exit 1
    fi

    log_info "Package: $package_name"
    log_info "AVX512 Disabled: $disable_avx512"
    log_info "VNNI Enabled: $enable_vnni"
    log_info "BF16 Enabled: $enable_bf16"
    log_info "AMX Enabled: $enable_amx"

    # Create workspace
    if ! mkdir -p "$WORKSPACE"; then
        log_error "Failed to create workspace directory: $WORKSPACE"
        exit 1
    fi

    if ! cd "$WORKSPACE"; then
        log_error "Failed to change to workspace directory: $WORKSPACE"
        exit 1
    fi

    # Clone or update vLLM repository
    if [[ ! -d "vllm" ]]; then
        log_info "Cloning vLLM repository..."
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would execute: timeout 300 git clone https://github.com/vllm-project/vllm.git"
        else
            if ! timeout 300 git clone https://github.com/vllm-project/vllm.git; then
                log_error "Failed to clone vLLM repository (timeout or error)"
                log_error "Check network connectivity or increase timeout"
                exit 1
            fi
        fi
    elif [[ -d "vllm/.git" ]]; then
        log_info "vLLM repository exists, updating..."
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would execute: cd vllm && git fetch origin && git pull"
        else
            if ! (cd vllm && git fetch origin && git pull); then
                log_warning "Failed to update vLLM repository, using existing version"
            else
                log_success "vLLM repository updated"
            fi
        fi
    elif [[ $DRY_RUN -eq 0 ]]; then
        log_error "vllm directory exists but is not a git repository"
        exit 1
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would execute: cd vllm"
    else
        if ! cd vllm; then
            log_error "Failed to enter vllm directory"
            exit 1
        fi
    fi

    # Checkout specific version if requested
    if [[ -n "$VLLM_VERSION" ]]; then
        log_info "Checking out specified version: $VLLM_VERSION"
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would execute: git checkout v$VLLM_VERSION or $VLLM_VERSION"
        else
            # Discard any local changes that might prevent checkout
            log_info "Discarding local changes to ensure clean checkout..."
            git reset --hard HEAD >/dev/null 2>&1 || true
            git clean -fd >/dev/null 2>&1 || true

            # Try with 'v' prefix first, then without
            if git checkout "v$VLLM_VERSION" 2>/dev/null; then
                log_success "Checked out version v$VLLM_VERSION"
            elif git checkout "$VLLM_VERSION" 2>/dev/null; then
                log_success "Checked out version $VLLM_VERSION"
            else
                log_error "Version $VLLM_VERSION (or v$VLLM_VERSION) not found in repository"
                log_error "Available tags: $(git tag -l | tail -10 | tr '\n' ' ')"
                exit 1
            fi
        fi
    fi

    # Detect version from git (after checkout if version was specified)
    if [[ $DRY_RUN -eq 1 ]]; then
        VLLM_VERSION="0.0.0"
        log_info "[DRY RUN] Would detect version from git"
    else
        VLLM_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
        log_info "Building version: $VLLM_VERSION"
    fi

    # Set up virtual environment (shared across all variants)
    log_info "Creating build environment..."
    local venv_path="$WORKSPACE/venv"
    if [[ ! -d "$venv_path" ]] || [[ $DRY_RUN -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would execute: uv venv --python $PYTHON_VERSION $venv_path"
        else
            if ! uv venv --python "$PYTHON_VERSION" "$venv_path"; then
                log_error "Failed to create virtual environment"
                exit 1
            fi
        fi
    fi

    # shellcheck source=/dev/null
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would execute: source $venv_path/bin/activate"
    else
        if ! source "$venv_path/bin/activate"; then
            log_error "Failed to activate virtual environment"
            exit 1
        fi
    fi

    # Install build dependencies (including setuptools-scm required by setup.py)
    log_info "Installing build dependencies..."
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would execute: uv pip install --upgrade pip setuptools wheel build setuptools-scm"
    else
        if ! uv pip install --upgrade pip setuptools wheel build setuptools-scm; then
            log_error "Failed to install base build dependencies"
            exit 1
        fi
    fi

    # Install all dependencies using explicit index URLs (avoids modifying git-tracked files)
    log_info "Installing vLLM dependencies (PyTorch from CPU index, other packages from PyPI)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would execute: uv pip install --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple --index-strategy unsafe-best-match -e ."
    else
        # Install in editable mode with explicit index URLs:
        # - Primary index: PyTorch CPU (https://download.pytorch.org/whl/cpu)
        # - Secondary index: PyPI (https://pypi.org/simple) for intel-openmp, etc.
        # This avoids modifying pyproject.toml and prevents git conflicts
        if ! uv pip install \
            --index-url https://download.pytorch.org/whl/cpu \
            --extra-index-url https://pypi.org/simple \
            --index-strategy unsafe-best-match \
            -e .; then
            log_error "Failed to install vLLM dependencies"
            exit 1
        fi
    fi

    # Set environment variables for build
    log_info "Setting build environment variables..."
    export VLLM_TARGET_DEVICE=cpu
    export MAX_JOBS="$MAX_JOBS"
    export CMAKE_ARGS="-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"

    # Simplify version format for PyPI compatibility
    # vLLM's setup.py appends +cpu (or .cpu if + already exists)
    # Strategy: Use version without +, so vLLM adds +cpu cleanly
    # Result: v0.11.0 becomes 0.11.0+cpu (PyPI compatible!)
    local base_version="${VLLM_VERSION#v}"

    # Apply version suffix if specified (for re-uploading previously deleted wheels)
    # PyPI has an immutable filename policy - once a filename is used, it cannot be re-uploaded
    # Use .post1, .post2, etc. to create a new version when re-uploading
    if [[ -n "$VERSION_SUFFIX" ]]; then
        base_version="${base_version}${VERSION_SUFFIX}"
        log_info "Using version with suffix: $base_version (for re-upload)"
    fi

    export SETUPTOOLS_SCM_PRETEND_VERSION="$base_version"
    log_info "Using version: ${SETUPTOOLS_SCM_PRETEND_VERSION} (final wheel version)"

    if [[ "$disable_avx512" == "true" ]]; then
        export VLLM_CPU_DISABLE_AVX512=1
    else
        export VLLM_CPU_DISABLE_AVX512=0
    fi

    if [[ "$enable_vnni" == "true" ]]; then
        export VLLM_CPU_AVX512VNNI=1
    else
        export VLLM_CPU_AVX512VNNI=0
    fi

    if [[ "$enable_bf16" == "true" ]]; then
        export VLLM_CPU_AVX512BF16=1
    else
        export VLLM_CPU_AVX512BF16=0
    fi

    if [[ "$enable_amx" == "true" ]]; then
        export VLLM_CPU_AMXBF16=1
    else
        export VLLM_CPU_AMXBF16=0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Build environment:"
        log_info "  VLLM_TARGET_DEVICE=cpu"
        log_info "  MAX_JOBS=$MAX_JOBS"
        log_info "  CMAKE_ARGS=$CMAKE_ARGS"
        log_info "  VLLM_CPU_DISABLE_AVX512=$VLLM_CPU_DISABLE_AVX512"
        log_info "  VLLM_CPU_AVX512VNNI=$VLLM_CPU_AVX512VNNI"
        log_info "  VLLM_CPU_AVX512BF16=$VLLM_CPU_AVX512BF16"
        log_info "  VLLM_CPU_AMXBF16=$VLLM_CPU_AMXBF16"
    fi

    # Modify package metadata
    log_info "Customizing package metadata for $package_name..."

    if [[ -f "pyproject.toml" ]] || [[ $DRY_RUN -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would backup pyproject.toml"
            log_info "[DRY RUN] Would update package name to: $package_name"
            log_info "[DRY RUN] Would update description to: $description"
            log_info "[DRY RUN] Would update license to: GPL-3.0"
            log_info "[DRY RUN] Would set author: Mekayel Anik <mekayel.anik@gmail.com>"
            log_info "[DRY RUN] Would set maintainer: Mekayel Anik <mekayel.anik@gmail.com>"
            log_info "[DRY RUN] Would update project URLs:"
            log_info "[DRY RUN]   - Homepage: https://github.com/MekayelAnik/vllm-cpu"
            log_info "[DRY RUN]   - Repository: https://github.com/MekayelAnik/vllm-cpu"
            log_info "[DRY RUN]   - Bug Tracker: https://github.com/MekayelAnik/vllm-cpu/issues"
            log_info "[DRY RUN]   - Changelog: https://github.com/MekayelAnik/vllm-cpu/releases"
            log_info "[DRY RUN] Would update Python version classifiers (remove 3.9, keep 3.10-3.13)"
            log_info "[DRY RUN] Would copy README file: $readme_file"
            log_info "[DRY RUN] Would add PyTorch CPU-only installation instructions"
        else
            # Backup original
            if ! cp pyproject.toml pyproject.toml.backup; then
                log_error "Failed to backup pyproject.toml"
                exit 1
            fi

            # Escape special characters for sed
            local safe_package_name
            local safe_description
            safe_package_name="$(escape_sed "$package_name")"
            safe_description="$(escape_sed "$description")"

            # Update package name and description
            if ! sed -i "s/name = \"vllm\"/name = \"${safe_package_name}\"/" pyproject.toml; then
                log_error "Failed to update package name in pyproject.toml"
                exit 1
            fi

            if ! sed -i "s/description = .*/description = \"${safe_description}\"/" pyproject.toml; then
                log_error "Failed to update description in pyproject.toml"
                exit 1
            fi

            # Update license to GPL-3.0
            log_info "Updating license to GPL-3.0..."
            sed -i 's/license = .*/license = "GPL-3.0"/' pyproject.toml
            # Also update license classifier if present
            sed -i 's/"License :: OSI Approved :: Apache Software License"/"License :: OSI Approved :: GNU General Public License v3 (GPLv3)"/' pyproject.toml

            # Add/Update author and maintainer information
            log_info "Adding author and maintainer metadata..."
            # Remove existing authors/maintainers lines if present
            sed -i '/^authors = /d' pyproject.toml
            sed -i '/^maintainers = /d' pyproject.toml
            # Add new author and maintainer after the description line
            sed -i '/^description = /a authors = [{name = "Mekayel Anik", email = "mekayel.anik@gmail.com"}]' pyproject.toml
            sed -i '/^authors = /a maintainers = [{name = "Mekayel Anik", email = "mekayel.anik@gmail.com"}]' pyproject.toml

            # Update project URLs
            log_info "Updating project URLs..."
            # Check if [project.urls] section exists
            if grep -q "\[project\.urls\]" pyproject.toml; then
                # Update existing URLs section
                sed -i 's|Homepage = .*|Homepage = "https://github.com/MekayelAnik/vllm-cpu"|' pyproject.toml
                sed -i 's|Documentation = .*|Documentation = "https://docs.vllm.ai/en/latest/"|' pyproject.toml
                sed -i 's|Repository = .*|Repository = "https://github.com/MekayelAnik/vllm-cpu"|' pyproject.toml
                sed -i 's|Changelog = .*|Changelog = "https://github.com/MekayelAnik/vllm-cpu/releases"|' pyproject.toml
                # Add Bug Tracker if not present
                if ! grep -q "Bug Tracker" pyproject.toml; then
                    sed -i '/\[project\.urls\]/a "Bug Tracker" = "https://github.com/MekayelAnik/vllm-cpu/issues"' pyproject.toml
                fi
            else
                log_warning "Could not find [project.urls] section in pyproject.toml"
            fi

            # Update Python version classifiers (remove 3.9, keep 3.10-3.13)
            log_info "Updating Python version classifiers (3.10-3.13 only)..."
            # First, remove any existing Python 3.9 classifier
            sed -i '/"Programming Language :: Python :: 3\.9"/d' pyproject.toml
            # Ensure 3.10-3.13 are present (add if missing)
            if grep -q "classifiers = \[" pyproject.toml; then
                # Check and add each version if not present
                for pyver in 3.10 3.11 3.12 3.13; do
                    if ! grep -q "Programming Language :: Python :: $pyver" pyproject.toml; then
                        sed -i "/classifiers = \[/a\    \"Programming Language :: Python :: $pyver\"," pyproject.toml
                    fi
                done
            else
                log_warning "Could not find classifiers section in pyproject.toml"
            fi

            # Copy variant-specific README file
            log_info "Copying variant-specific README: $readme_file..."
            local readme_path="$SCRIPT_DIR/$readme_file"
            if [[ -f "$readme_path" ]]; then
                # Backup original README if it exists
                if [[ -f "README.md" ]]; then
                    cp README.md README.md.backup || log_warning "Failed to backup README.md"
                fi
                # Copy variant-specific README
                if ! cp "$readme_path" README.md; then
                    log_error "Failed to copy README file: $readme_path"
                    exit 1
                fi
                log_success "Copied $readme_file to README.md"
            else
                log_error "README file not found: $readme_path"
                exit 1
            fi

            # Note: Index URLs are specified via command-line flags during installation (no pyproject.toml modification needed)
        fi
    else
        log_warning "pyproject.toml not found, skipping metadata customization"
    fi

    # Patch setup.py to disable version suffix (e.g., +cpu, +cuda)
    # We want version to be exactly what user specified (e.g., 0.11.0)
    # The package name differentiation is handled by pyproject.toml
    log_info "Patching setup.py to use exact version without suffix..."
    if [[ -f "$WORKSPACE/vllm/setup.py" ]]; then
        # Replace version += line with pass, maintaining proper indentation (12 spaces)
        sed -i 's/^            version += f"{sep}cpu"/            pass  # Disabled: use exact version (no +cpu suffix)/' "$WORKSPACE/vllm/setup.py"
        log_info "Version suffix disabled - wheel will use exact version: ${SETUPTOOLS_SCM_PRETEND_VERSION}"
    else
        log_warning "setup.py not found, skipping version patch"
    fi

    # Build wheel with timeout (30-60 minutes)
    log_info "Building wheel (this may take 30-60 minutes)..."
    local wheel_dir="$WORKSPACE/wheels-$variant"

    # Detect platform architecture (for both dry-run and actual build)
    local platform_arch
    platform_arch=$(uname -m)

    local platform_tag
    case "$platform_arch" in
        x86_64)
            platform_tag="manylinux_2_17_x86_64"
            ;;
        aarch64|arm64)
            platform_tag="manylinux_2_17_aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $platform_arch"
            exit 1
            ;;
    esac

    log_info "Target platform: $platform_tag (detected: $platform_arch)"

    # Determine platform-based output directory (linux_amd64 or linux_arm64)
    local platform_dir
    case "$platform_arch" in
        x86_64)  platform_dir="linux_amd64" ;;
        aarch64) platform_dir="linux_arm64" ;;
        *)       platform_dir="linux_${platform_arch}" ;;
    esac
    local final_output_dir="$OUTPUT_DIR/$platform_dir"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would create wheel directory: $wheel_dir"
        log_info "[DRY RUN] Would execute: timeout 3600 python setup.py bdist_wheel --dist-dir=$wheel_dir --plat-name=$platform_tag"
        log_info "[DRY RUN] Would restore original pyproject.toml and README.md"
        log_info "[DRY RUN] Would copy wheel to: $final_output_dir"
        log_success "[DRY RUN] Would complete build for $variant"
    else
        if ! mkdir -p "$wheel_dir"; then
            log_error "Failed to create wheel output directory"
            exit 1
        fi

        # Use timeout for build (3600 seconds = 1 hour)
        log_info "Executing: python setup.py bdist_wheel --dist-dir=$wheel_dir --plat-name=$platform_tag"
        if ! timeout 3600 python setup.py bdist_wheel --dist-dir="$wheel_dir" --plat-name="$platform_tag"; then
            log_error "Failed to build wheel (timeout or build error)"
            log_error "Check build logs for details or increase timeout"
            exit 1
        fi

        # Immediately verify wheel was created
        log_info "Checking for built wheel in $wheel_dir..."
        if ! ls -la "$wheel_dir"/*.whl 2>/dev/null; then
            log_error "Build command succeeded but no wheel found in $wheel_dir"
            log_error "Contents of wheel directory:"
            ls -la "$wheel_dir" 2>/dev/null || log_error "Directory doesn't exist"
            log_error "Contents of current directory:"
            ls -la
            log_error "Checking for .whl files in build directory tree:"
            find . -name "*.whl" -type f 2>/dev/null || log_error "No .whl files found"
            exit 1
        fi
        log_success "Wheel found in $wheel_dir"

        # Restore original files
        if [[ -f "pyproject.toml.backup" ]]; then
            if ! mv pyproject.toml.backup pyproject.toml; then
                log_warning "Failed to restore original pyproject.toml"
            fi
        fi

        # Restore original README.md
        if [[ -f "README.md.backup" ]]; then
            if ! mv README.md.backup README.md; then
                log_warning "Failed to restore original README.md"
            fi
        fi

        # Copy wheel to platform-based output directory
        # Structure: dist/linux_amd64/ or dist/linux_arm64/
        if ! mkdir -p "$final_output_dir"; then
            log_error "Failed to create output directory: $final_output_dir"
            exit 1
        fi

        # Enable nullglob to handle no-match case
        shopt -s nullglob
        local wheels=("$wheel_dir"/*.whl)
        shopt -u nullglob

        if [[ ${#wheels[@]} -eq 0 ]]; then
            log_error "No wheels found in $wheel_dir"
            exit 1
        fi

        if ! cp "${wheels[@]}" "$final_output_dir/"; then
            log_error "Failed to copy wheels to output directory"
            exit 1
        fi

        log_success "Built wheel for $variant → $final_output_dir"
    fi

    # Deactivate venv before cleanup
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would deactivate virtual environment"
    else
        deactivate 2>/dev/null || true
    fi

    # Clean up build artifacts after this wheel (reclaim disk space immediately)
    cleanup_after_wheel "$variant"
}

# Build all variants
build_all() {
    log_info "Building all variants..."

    # Get variants into array
    local -a variants_array
    if ! mapfile -t variants_array < <(get_all_variants); then
        log_error "Failed to read variants from config file"
        exit 1
    fi

    if [[ ${#variants_array[@]} -eq 0 ]]; then
        log_error "No variants found in config file"
        exit 1
    fi

    local variant
    for variant in "${variants_array[@]}"; do
        log_info "========================================"
        build_variant "$variant"
        log_info "========================================"
        echo ""
    done

    log_success "All variants built successfully!"
}

# Main
main() {
    log_info "Starting vLLM CPU wheel builder v${SCRIPT_VERSION}"
    log_debug "Script: $SCRIPT_DIR/$SCRIPT_NAME"
    log_debug "Bash version: ${BASH_VERSION}"

    parse_args "$@"

    # Show dry-run mode if enabled
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "=========================================="
        log_info "DRY RUN MODE - No actual changes will be made"
        log_info "=========================================="
    fi

    # Check and install build dependencies
    if ! check_and_install_dependencies; then
        log_error "Failed to install required dependencies"
        exit 1
    fi

    # Check uv package manager
    if ! command -v uv &> /dev/null; then
        log_error "uv package manager is required"
        log_info "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Build configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Determine vLLM versions to build
    local -a vllm_versions_to_build=()
    if [[ ${#VLLM_VERSIONS[@]} -gt 0 ]]; then
        vllm_versions_to_build=("${VLLM_VERSIONS[@]}")
    elif [[ -n "$VLLM_VERSION" ]]; then
        vllm_versions_to_build=("$VLLM_VERSION")
    else
        # No version specified, will use latest from git
        vllm_versions_to_build=("")
    fi

    # Determine Python versions to build
    # Special case: "auto" means detect from vLLM's pyproject.toml per-version
    local python_auto_mode=0
    local -a python_versions_to_build=()
    if [[ ${#PYTHON_VERSIONS[@]} -gt 0 ]]; then
        if [[ "${PYTHON_VERSIONS[0]}" == "auto" ]]; then
            python_auto_mode=1
            log_info "Python version auto-detection mode enabled"
        else
            python_versions_to_build=("${PYTHON_VERSIONS[@]}")
        fi
    else
        python_versions_to_build=("$PYTHON_VERSION")
    fi

    # Show build matrix
    log_info "=========================================="
    log_info "Build Matrix:"
    log_info "  vLLM versions: ${#vllm_versions_to_build[@]} (${vllm_versions_to_build[*]:-latest})"
    if [[ $python_auto_mode -eq 1 ]]; then
        log_info "  Python versions: auto (will detect from vLLM's pyproject.toml)"
    else
        log_info "  Python versions: ${#python_versions_to_build[@]} (${python_versions_to_build[*]})"
    fi
    if [[ -n "$VARIANT" ]] && [[ "$VARIANT" != "all" ]]; then
        log_info "  Variants: 1 ($VARIANT)"
        if [[ $python_auto_mode -eq 0 ]]; then
            log_info "  Total wheels: $((${#vllm_versions_to_build[@]} * ${#python_versions_to_build[@]}))"
        else
            log_info "  Total wheels: (will be determined after auto-detection)"
        fi
    else
        log_info "  Variants: 5 (all)"
        if [[ $python_auto_mode -eq 0 ]]; then
            log_info "  Total wheels: $((${#vllm_versions_to_build[@]} * ${#python_versions_to_build[@]} * 5))"
        else
            log_info "  Total wheels: (will be determined after auto-detection)"
        fi
    fi
    log_info "=========================================="

    # Build matrix: vLLM versions × Python versions × Variants
    for vllm_ver in "${vllm_versions_to_build[@]}"; do
        if [[ -n "$vllm_ver" ]]; then
            log_info "╔════════════════════════════════════════╗"
            log_info "║ Building for vLLM version: $vllm_ver"
            log_info "╚════════════════════════════════════════╝"
            VLLM_VERSION="$vllm_ver"

            # Get Python versions for this vLLM version
            local py_versions_for_vllm=()
            if [[ $python_auto_mode -eq 1 ]]; then
                # Auto mode: detect all supported versions from vLLM's pyproject.toml
                local auto_versions
                auto_versions=$(get_auto_python_versions "$vllm_ver")
                read -ra py_versions_for_vllm <<< "$auto_versions"
            else
                # Manual mode: filter requested versions against vLLM's requirements
                local supported_py_versions
                supported_py_versions=$(get_supported_python_versions "$vllm_ver" "${python_versions_to_build[@]}")
                read -ra py_versions_for_vllm <<< "$supported_py_versions"
            fi

            if [[ ${#py_versions_for_vllm[@]} -eq 0 ]]; then
                log_warning "No supported Python versions for vLLM $vllm_ver - skipping"
                continue
            fi
            log_info "Python versions for vLLM $vllm_ver: ${py_versions_for_vllm[*]}"
        else
            log_info "╔════════════════════════════════════════╗"
            log_info "║ Building for vLLM version: latest"
            log_info "╚════════════════════════════════════════╝"
            VLLM_VERSION=""
            # For latest without auto mode, use requested versions
            # For latest with auto mode, use a sensible default
            if [[ $python_auto_mode -eq 1 ]]; then
                log_warning "Auto mode with 'latest' vLLM version - using default 3.10-3.13"
                py_versions_for_vllm=("3.10" "3.11" "3.12" "3.13")
            else
                py_versions_for_vllm=("${python_versions_to_build[@]}")
            fi
        fi

        for py_ver in "${py_versions_for_vllm[@]}"; do
            log_info "┌────────────────────────────────────────┐"
            log_info "│ Building for Python $py_ver"
            log_info "└────────────────────────────────────────┘"
            PYTHON_VERSION="$py_ver"

            # Delete existing venv to force recreation with new Python version
            # (This is a safety measure; per-wheel cleanup should have already removed it)
            if [[ -d "$WORKSPACE/venv" ]]; then
                log_info "Removing existing venv for Python version switch..."
                rm -rf "$WORKSPACE/venv"
            fi

            # Build variant(s)
            if [[ -n "$VARIANT" ]]; then
                if [[ "$VARIANT" == "all" ]]; then
                    build_all
                else
                    build_variant "$VARIANT"
                fi
            else
                build_all
            fi
        done
    done

    # Show results
    log_info "=========================================="
    log_info "Build Complete!"
    log_info "=========================================="

    shopt -s nullglob
    local all_wheels=("$OUTPUT_DIR"/**/*.whl "$OUTPUT_DIR"/*.whl)
    shopt -u nullglob

    if [[ ${#all_wheels[@]} -gt 0 ]]; then
        log_info "Total wheels built: ${#all_wheels[@]}"
        log_info ""
        log_info "Output structure:"
        if command -v tree &>/dev/null; then
            tree -L 2 "$OUTPUT_DIR" || ls -R "$OUTPUT_DIR"
        else
            find "$OUTPUT_DIR" -name "*.whl" -type f | sort | sed 's/^/  /'
        fi
        log_info ""
        log_info "Wheels are in platform directories:"
        log_info "  $OUTPUT_DIR/linux_amd64/*.whl  (x86_64)"
        log_info "  $OUTPUT_DIR/linux_arm64/*.whl  (aarch64)"
    else
        log_warning "No wheels found in output directory"
    fi
}

main "$@"
