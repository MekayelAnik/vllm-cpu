#!/usr/bin/env bash
#
# docker-buildx.sh - Build vLLM CPU wheels using Docker buildx
#
# Leverages Docker buildx's multi-architecture support to build wheels for
# multiple platforms (amd64/arm64) in a single command. The build process
# runs entirely inside Docker, with wheels exported directly to the local
# filesystem without creating intermediate images.
#
# Usage:
#   ./docker-buildx.sh [OPTIONS]
#
# Options:
#   --variant=NAME              Variant to build (noavx512, avx512, avx512vnni,
#                               avx512bf16, amxbf16, all). Also accepts full names
#                               like vllm-cpu, vllm-cpu-avx512, etc.
#                               Only vllm-cpu supports arm64; others are x86_64-only
#                               Default: noavx512
#   --vllm-versions=VERSION     vLLM version(s) to build (required)
#                               Accepts: single (0.11.2) or multiple (0.10.0,0.11.0,0.11.2)
#   --python-versions=VERSION   Python version(s) (default: 3.12)
#                               Accepts: single (3.12), multiple (3.10,3.11,3.12),
#                               or range (3.10-3.13)
#   --platform=PLATFORM         Target platform(s): auto, linux/amd64, linux/arm64
#                               'auto' reads from build_config.json (default)
#   --output-dir=PATH           Output directory for wheels (default: ./dist)
#   --max-jobs=N                Parallel build jobs (default: 4)
#   --version-suffix=SUFFIX     Add version suffix for re-uploading (e.g., .post1, .dev1)
#                               Only .postN and .devN are valid (PEP 440 compliant)
#   --no-cache                  Build without Docker cache
#   --progress=TYPE             Progress output: auto, plain, tty (default: auto)
#   --builder=NAME              Buildx builder name (default: vllm-wheel-builder)
#   --dry-run                   Show what would be done without doing it
#   --help                      Show this help
#
# Examples:
#   # Build vllm-cpu for both amd64 and arm64
#   ./docker-buildx.sh --variant=noavx512 --vllm-versions=0.11.2
#
#   # Build x86-only variant (using short name)
#   ./docker-buildx.sh --variant=avx512bf16 --vllm-versions=0.11.2
#
#   # Build with specific platform override
#   ./docker-buildx.sh --variant=vllm-cpu --platform=linux/arm64 --vllm-versions=0.11.2
#
#   # Build multiple vLLM versions
#   ./docker-buildx.sh --variant=noavx512 --vllm-versions=0.10.0,0.11.0,0.11.2
#
#   # Build multiple Python versions (range)
#   ./docker-buildx.sh --variant=noavx512 --vllm-versions=0.11.2 --python-versions=3.10-3.13
#
#   # Build all 5 variants for a version
#   ./docker-buildx.sh --variant=all --vllm-versions=0.11.2
#
#   # Build version matrix: multiple vLLM x multiple Python versions
#   ./docker-buildx.sh --variant=noavx512 --vllm-versions=0.10.0,0.11.0 --python-versions=3.10-3.13
#
#   # Dry run - see what would be built
#   ./docker-buildx.sh --variant=all --vllm-versions=0.11.2 --dry-run
#
# Output structure (with platform-split):
#   dist/
#      linux_amd64/
#         vllm_cpu-0.11.2-cp312-cp312-linux_x86_64.whl
#      linux_arm64/
#          vllm_cpu-0.11.2-cp312-cp312-linux_aarch64.whl

set -euo pipefail

# Script metadata
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="2.0.0"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Default configuration
AUTO_INSTALL=1  # Auto-install missing dependencies by default
VARIANT="noavx512"  # User-facing short name, converted to vllm-cpu internally
VLLM_VERSIONS=""
PYTHON_VERSIONS="3.12"
VERSION_SUFFIX=""  # Optional version suffix (e.g., ".post1") for re-uploads
PLATFORM="auto"  # auto = read from build_config.json
OUTPUT_DIR="$SCRIPT_DIR/dist"
MAX_JOBS=4
NO_CACHE=""
PROGRESS="auto"
BUILDER_NAME="vllm-wheel-builder"
CONFIG_FILE="$SCRIPT_DIR/build_config.json"
DRY_RUN=0

# All variant names (full names)
readonly ALL_VARIANTS="vllm-cpu vllm-cpu-avx512 vllm-cpu-avx512vnni vllm-cpu-avx512bf16 vllm-cpu-amxbf16"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "${CYAN}[STEP]${NC} $*"; }

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

# Check and install Docker
install_docker() {
    local distro="$1"
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    log_info "Installing Docker..."

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            # Remove old versions
            $sudo_cmd apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

            # Install prerequisites
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y --no-install-recommends \
                ca-certificates \
                curl \
                gnupg \
                lsb-release

            # Add Docker's official GPG key
            $sudo_cmd install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$distro/gpg | $sudo_cmd gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
            $sudo_cmd chmod a+r /etc/apt/keyrings/docker.gpg

            # Set up repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro \
                $(lsb_release -cs) stable" | $sudo_cmd tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Install Docker
            $sudo_cmd apt-get update -qq
            $sudo_cmd apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        fedora)
            $sudo_cmd dnf -y install dnf-plugins-core
            $sudo_cmd dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            $sudo_cmd dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        centos|rhel|rocky|almalinux)
            $sudo_cmd yum install -y yum-utils
            $sudo_cmd yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $sudo_cmd yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        arch|manjaro)
            $sudo_cmd pacman -Sy --noconfirm docker docker-buildx
            ;;

        opensuse*|sles)
            $sudo_cmd zypper install -y docker docker-buildx
            ;;

        *)
            log_error "Unsupported distribution for Docker installation: $distro"
            log_info "Please install Docker manually: https://docs.docker.com/get-docker/"
            return 1
            ;;
    esac

    # Start and enable Docker service
    $sudo_cmd systemctl start docker 2>/dev/null || true
    $sudo_cmd systemctl enable docker 2>/dev/null || true

    # Add current user to docker group
    if [[ $EUID -ne 0 ]]; then
        $sudo_cmd usermod -aG docker "$USER" 2>/dev/null || true
        log_warning "You may need to log out and back in for Docker group changes to take effect"
        log_warning "Or run: newgrp docker"
    fi

    log_success "Docker installed successfully"
}

# Check and install Docker Buildx plugin
install_buildx() {
    local distro="$1"
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    log_info "Installing Docker Buildx plugin..."

    # First, try to install via package manager (if Docker was installed via packages)
    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            if $sudo_cmd apt-get install -y docker-buildx-plugin 2>/dev/null; then
                log_success "Docker Buildx installed via apt"
                return 0
            fi
            ;;
        fedora)
            if $sudo_cmd dnf install -y docker-buildx-plugin 2>/dev/null; then
                log_success "Docker Buildx installed via dnf"
                return 0
            fi
            ;;
        centos|rhel|rocky|almalinux)
            if $sudo_cmd yum install -y docker-buildx-plugin 2>/dev/null; then
                log_success "Docker Buildx installed via yum"
                return 0
            fi
            ;;
    esac

    # Fallback: Install buildx manually
    log_info "Installing Docker Buildx manually..."

    local buildx_version="v0.12.1"
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="arm-v7" ;;
    esac

    local buildx_url="https://github.com/docker/buildx/releases/download/${buildx_version}/buildx-${buildx_version}.linux-${arch}"
    local buildx_dir="$HOME/.docker/cli-plugins"

    mkdir -p "$buildx_dir"
    if curl -fsSL "$buildx_url" -o "$buildx_dir/docker-buildx"; then
        chmod +x "$buildx_dir/docker-buildx"
        log_success "Docker Buildx installed to $buildx_dir/docker-buildx"
    else
        log_error "Failed to download Docker Buildx"
        return 1
    fi
}

# Check and install jq
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

# Check all dependencies and install if missing
check_and_install_dependencies() {
    log_step "Checking dependencies..."

    local distro
    distro=$(detect_distro)
    log_info "Detected distribution: $distro"

    local missing_deps=()
    local need_docker=0
    local need_buildx=0
    local need_jq=0

    # Check Docker
    if ! command -v docker &>/dev/null; then
        log_warning "Docker is not installed"
        need_docker=1
        missing_deps+=("docker")
    else
        log_success "Docker: $(docker --version 2>/dev/null | head -1)"
    fi

    # Check Docker Buildx
    if command -v docker &>/dev/null; then
        if ! docker buildx version &>/dev/null; then
            log_warning "Docker Buildx plugin is not installed"
            need_buildx=1
            missing_deps+=("docker-buildx-plugin")
        else
            log_success "Docker Buildx: $(docker buildx version 2>/dev/null | head -1)"
        fi
    fi

    # Check jq
    if ! command -v jq &>/dev/null; then
        log_warning "jq is not installed"
        need_jq=1
        missing_deps+=("jq")
    else
        log_success "jq: $(jq --version 2>/dev/null)"
    fi

    # If no missing dependencies, we're done
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log_success "All dependencies are installed"
        return 0
    fi

    # Check if auto-install is enabled
    if [[ $AUTO_INSTALL -ne 1 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Run with auto-install or install manually"
        return 1
    fi

    # Check if we can install (need root or sudo)
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)
    if [[ -z "$sudo_cmd" ]] && [[ $EUID -ne 0 ]]; then
        log_error "Cannot install dependencies: not root and sudo not available"
        log_info "Please install manually: ${missing_deps[*]}"
        return 1
    fi

    log_info "Installing missing dependencies: ${missing_deps[*]}"

    # Install Docker if needed
    if [[ $need_docker -eq 1 ]]; then
        install_docker "$distro" || return 1
    fi

    # Install Buildx if needed
    if [[ $need_buildx -eq 1 ]]; then
        install_buildx "$distro" || return 1
    fi

    # Install jq if needed
    if [[ $need_jq -eq 1 ]]; then
        install_jq "$distro" || return 1
    fi

    log_success "All dependencies installed successfully"

    # Verify Docker is running
    if ! docker info &>/dev/null; then
        log_warning "Docker daemon may not be running"
        log_info "Try: sudo systemctl start docker"
        log_info "Or: newgrp docker (if just added to docker group)"
    fi

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
            log_error "Or full names: vllm-cpu, vllm-cpu-avx512, vllm-cpu-avx512vnni, vllm-cpu-avx512bf16, vllm-cpu-amxbf16"
            return 1
            ;;
    esac
}

# Expand Python version range (e.g., "3.10-3.13" -> "3.10 3.11 3.12 3.13")
expand_python_versions() {
    local input="$1"
    local versions=()

    # Split on comma first
    IFS=',' read -ra parts <<< "$input"

    for part in "${parts[@]}"; do
        # Trim whitespace
        part=$(echo "$part" | xargs)

        # Check if it's a range (contains -)
        if [[ "$part" == *-* ]]; then
            local start_ver="${part%-*}"
            local end_ver="${part#*-}"

            # Extract minor versions
            local start_minor="${start_ver#3.}"
            local end_minor="${end_ver#3.}"

            # Generate range
            for ((minor = start_minor; minor <= end_minor; minor++)); do
                versions+=("3.$minor")
            done
        else
            versions+=("$part")
        fi
    done

    echo "${versions[@]}"
}

# Show help
show_help() {
    echo -e "$(cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════════════════════╗
║              vLLM CPU Wheel Builder (Docker Buildx) v${SCRIPT_VERSION}                   ║
╚════════════════════════════════════════════════════════════════════════════╝${NC}

${GREEN}DESCRIPTION${NC}
    Build vLLM CPU wheels using Docker buildx for multiple architectures.
    Leverages Docker buildx's multi-platform support to build wheels for
    amd64 and arm64 in a single command. Wheels are exported directly to
    the local filesystem without creating intermediate Docker images.

${GREEN}USAGE${NC}
    ${SCRIPT_NAME} [OPTIONS]

${GREEN}OPTIONS${NC}
    ${YELLOW}--variant=NAME${NC}
        Variant to build. Accepts short names or full package names.
        Short names: noavx512, avx512, avx512vnni, avx512bf16, amxbf16, all
        Full names:  vllm-cpu, vllm-cpu-avx512, vllm-cpu-avx512vnni,
                     vllm-cpu-avx512bf16, vllm-cpu-amxbf16
        Note: Only vllm-cpu (noavx512) supports arm64; others are x86_64-only
        Default: noavx512

    ${YELLOW}--vllm-versions=VERSION${NC}
        vLLM version(s) to build. ${RED}Required.${NC}
        Accepts: single version (0.11.2) or comma-separated (0.10.0,0.11.0,0.11.2)

    ${YELLOW}--python-versions=VERSION${NC}
        Python version(s) to build for.
        Accepts: single (3.12), comma-separated (3.10,3.11,3.12), or range (3.10-3.13)
        Default: 3.12

    ${YELLOW}--platform=PLATFORM${NC}
        Target platform(s) for the build.
        Options: auto, linux/amd64, linux/arm64
        'auto' reads supported platforms from build_config.json
        Default: auto

    ${YELLOW}--output-dir=PATH${NC}
        Output directory for built wheels.
        Default: ./dist

    ${YELLOW}--max-jobs=N${NC}
        Number of parallel build jobs.
        Default: 4

    ${YELLOW}--no-cache${NC}
        Build without using Docker cache.

    ${YELLOW}--progress=TYPE${NC}
        Progress output type: auto, plain, tty
        Default: auto

    ${YELLOW}--builder=NAME${NC}
        Docker buildx builder name.
        Default: vllm-wheel-builder

    ${YELLOW}--dry-run${NC}
        Show what would be done without actually building.

    ${YELLOW}--help, -h${NC}
        Show this help message.

${GREEN}VARIANT MAPPING${NC}
    Short Name    Full Name               AVX512  VNNI  BF16  AMX   Platforms
    ─────────────────────────────────────────────────────────────────────────
    noavx512      vllm-cpu                 ❌      ❌    ❌    ❌    x86_64, arm64
    avx512        vllm-cpu-avx512          ✅      ❌    ❌    ❌    x86_64
    avx512vnni    vllm-cpu-avx512vnni      ✅      ✅    ❌    ❌    x86_64
    avx512bf16    vllm-cpu-avx512bf16      ✅      ✅    ✅    ❌    x86_64
    amxbf16       vllm-cpu-amxbf16         ✅      ✅    ✅    ✅    x86_64

${GREEN}EXAMPLES${NC}
    ${BLUE}# Build vllm-cpu (noavx512) for both amd64 and arm64${NC}
    ${SCRIPT_NAME} --variant=noavx512 --vllm-versions=0.11.2

    ${BLUE}# Build x86-only variant using short name${NC}
    ${SCRIPT_NAME} --variant=avx512bf16 --vllm-versions=0.11.2

    ${BLUE}# Build with specific platform override${NC}
    ${SCRIPT_NAME} --variant=vllm-cpu --platform=linux/arm64 --vllm-versions=0.11.2

    ${BLUE}# Build multiple vLLM versions${NC}
    ${SCRIPT_NAME} --variant=noavx512 --vllm-versions=0.10.0,0.11.0,0.11.2

    ${BLUE}# Build for Python version range${NC}
    ${SCRIPT_NAME} --variant=noavx512 --vllm-versions=0.11.2 --python-versions=3.10-3.13

    ${BLUE}# Build ALL 5 variants${NC}
    ${SCRIPT_NAME} --variant=all --vllm-versions=0.11.2

    ${BLUE}# Build version matrix (vLLM × Python)${NC}
    ${SCRIPT_NAME} --variant=noavx512 --vllm-versions=0.10.0,0.11.0 --python-versions=3.10-3.13

    ${BLUE}# Dry run - preview build plan${NC}
    ${SCRIPT_NAME} --variant=all --vllm-versions=0.11.2 --python-versions=3.10-3.13 --dry-run

${GREEN}OUTPUT STRUCTURE${NC}
    dist/
    ├── linux_amd64/
    │   └── vllm_cpu-0.11.2-cp312-cp312-linux_x86_64.whl
    └── linux_arm64/
        └── vllm_cpu-0.11.2-cp312-cp312-linux_aarch64.whl

${GREEN}DEPENDENCIES${NC}
    The script will automatically install missing dependencies:
    - Docker (docker-ce)
    - Docker Buildx plugin (docker-buildx-plugin)
    - jq (JSON processor)

${GREEN}CROSS-PLATFORM BUILDS${NC}
    When building for a different architecture (e.g., arm64 on x86_64),
    QEMU user-mode emulation is automatically configured via the
    tonistiigi/binfmt Docker image.

${GREEN}SEE ALSO${NC}
    - test_and_publish.sh: Native wheel building and PyPI publishing
    - build_wheels.sh: Low-level wheel build script
    - Dockerfile.buildx: Multi-stage Dockerfile for buildx builds

EOF
)"
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
                VLLM_VERSIONS="${1#*=}"
                shift
                ;;
            --python-version=*|--python-versions=*)
                PYTHON_VERSIONS="${1#*=}"
                shift
                ;;
            --platform=*)
                PLATFORM="${1#*=}"
                shift
                ;;
            --output-dir=*)
                OUTPUT_DIR="${1#*=}"
                shift
                ;;
            --max-jobs=*)
                MAX_JOBS="${1#*=}"
                shift
                ;;
            --no-cache)
                NO_CACHE="--no-cache"
                shift
                ;;
            --progress=*)
                PROGRESS="${1#*=}"
                shift
                ;;
            --builder=*)
                BUILDER_NAME="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --version-suffix=*)
                VERSION_SUFFIX="${1#*=}"
                # Validate suffix format (must start with . and be .postN or .devN format)
                if ! [[ "$VERSION_SUFFIX" =~ ^\.(post|dev)[0-9]+$ ]]; then
                    log_error "Invalid version suffix: $VERSION_SUFFIX"
                    log_info "Suffix must be .postN or .devN format (e.g., .post1, .post2, .dev1)"
                    exit 1
                fi
                log_info "Version suffix enabled: $VERSION_SUFFIX"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Validate variant exists in config
validate_variant() {
    local variant="$1"

    # "all" is a special case
    if [[ "$variant" == "all" ]]; then
        return 0
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi

    local exists
    exists=$(jq -r ".builds.\"$variant\" // empty" "$CONFIG_FILE")

    if [[ -z "$exists" ]]; then
        log_error "Unknown variant: $variant"
        log_info "Available variants:"
        jq -r '.builds | keys[]' "$CONFIG_FILE" | sed 's/^/  - /'
        exit 1
    fi
}

# Get supported platforms for variant from config
get_variant_platforms() {
    local variant="$1"
    local platforms

    platforms=$(jq -r ".builds.\"$variant\".platforms[]" "$CONFIG_FILE" 2>/dev/null)

    if [[ -z "$platforms" ]]; then
        # Default to x86_64 only
        echo "linux/amd64"
        return
    fi

    local result=""
    while IFS= read -r plat; do
        case "$plat" in
            x86_64)
                result="${result:+$result,}linux/amd64"
                ;;
            aarch64|arm64)
                result="${result:+$result,}linux/arm64"
                ;;
        esac
    done <<< "$platforms"

    echo "$result"
}

# Get docker command (with sudo if needed)
get_docker_cmd() {
    if [[ "${DOCKER_SUDO:-0}" == "1" ]]; then
        echo "sudo docker"
    else
        echo "docker"
    fi
}

# Check if Docker is available and running
check_docker_running() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        log_info "Install from: https://docs.docker.com/get-docker/"
        return 1
    fi

    # Try docker info directly first (with retries for transient failures)
    local max_retries=3
    local retry=0
    while [[ $retry -lt $max_retries ]]; do
        if docker info &>/dev/null; then
            log_success "Docker daemon is running"
            return 0
        fi
        ((retry++))
        if [[ $retry -lt $max_retries ]]; then
            log_warning "Docker check failed, retrying ($retry/$max_retries)..."
            sleep 2
        fi
    done

    # If that failed, check if it's a permission issue
    local docker_error
    docker_error=$(docker info 2>&1)
    local docker_exit=$?

    # If docker info actually succeeds but outputs warnings, that's OK
    if [[ $docker_exit -eq 0 ]]; then
        log_success "Docker daemon is running"
        return 0
    fi

    if echo "$docker_error" | grep -qi "permission denied"; then
        log_warning "Docker permission denied - trying with sudo..."

        # Check if sudo is available
        if command -v sudo &>/dev/null; then
            if sudo docker info &>/dev/null; then
                log_warning "Docker requires sudo. Consider adding user to docker group:"
                log_info "  sudo usermod -aG docker \$USER"
                log_info "  newgrp docker  # or log out and back in"
                log_info ""
                log_info "Continuing with sudo for this session..."
                # Set a flag to use sudo for docker commands
                export DOCKER_SUDO=1
                return 0
            fi
        fi

        log_error "Docker permission denied and sudo failed"
        log_info "Add your user to the docker group:"
        log_info "  sudo usermod -aG docker \$USER"
        log_info "  newgrp docker"
        return 1
    fi

    # Check if daemon is actually not running
    if echo "$docker_error" | grep -qi "cannot connect\|connection refused\|Is the docker daemon running"; then
        log_error "Docker daemon is not running"
        log_info "Start Docker with: sudo systemctl start docker"
        return 1
    fi

    # Unknown error
    log_error "Docker check failed (exit code $docker_exit): $docker_error"
    return 1
}

# Check and setup buildx builder
setup_buildx_builder() {
    local builder="$1"
    local docker_cmd
    docker_cmd=$(get_docker_cmd)

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would setup buildx builder: $builder"
        return 0
    fi

    log_step "Setting up buildx builder: $builder"

    # Check if builder exists
    if $docker_cmd buildx inspect "$builder" &>/dev/null; then
        log_info "Using existing builder: $builder"
        $docker_cmd buildx use "$builder"
    else
        log_info "Creating new builder: $builder"

        # Create builder with docker-container driver (required for multi-arch)
        $docker_cmd buildx create \
            --name "$builder" \
            --driver docker-container \
            --driver-opt network=host \
            --use
    fi

    # Bootstrap the builder (ensure it's running)
    log_info "Bootstrapping builder..."
    $docker_cmd buildx inspect --bootstrap "$builder" >/dev/null

    log_success "Builder ready: $builder"
}

# Setup QEMU for cross-platform builds
setup_qemu() {
    local platforms="$1"
    local docker_cmd
    docker_cmd=$(get_docker_cmd)

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would setup QEMU for platforms: $platforms"
        return 0
    fi

    # Check if cross-platform build is needed
    local host_arch
    host_arch=$(uname -m)

    local need_qemu=0

    if [[ "$platforms" == *"linux/arm64"* ]] && [[ "$host_arch" == "x86_64" ]]; then
        need_qemu=1
    elif [[ "$platforms" == *"linux/amd64"* ]] && [[ "$host_arch" == "aarch64" ]]; then
        need_qemu=1
    fi

    if [[ $need_qemu -eq 1 ]]; then
        log_step "Setting up QEMU for cross-platform builds"

        # Register QEMU handlers using Docker's binfmt image
        if $docker_cmd run --rm --privileged tonistiigi/binfmt --install all &>/dev/null; then
            log_success "QEMU handlers registered"
        else
            log_warning "Could not register QEMU handlers (may already be registered)"
        fi
    fi
}

# Build wheels for a single variant/version/python combination
# Always outputs to platform-specific subdirectories (linux_amd64, linux_arm64)
build_single_wheel() {
    local variant="$1"
    local version="$2"
    local python_ver="$3"
    local platforms="$4"
    local output_dir="$5"
    local docker_cmd
    docker_cmd=$(get_docker_cmd)

    log_step "Building wheel: $variant v$version (Python $python_ver)"
    echo ""
    log_info "Configuration:"
    log_info "  Variant:        $variant"
    log_info "  vLLM Version:   $version"
    log_info "  Python Version: $python_ver"
    log_info "  Platforms:      $platforms"
    log_info "  Output:         $output_dir"
    log_info "  Max Jobs:       $MAX_JOBS"
    [[ "${DOCKER_SUDO:-0}" == "1" ]] && log_info "  Docker:         using sudo"
    echo ""

    # Ensure base output directory exists
    mkdir -p "$output_dir"
    output_dir=$(realpath "$output_dir")

    # Split platforms and build each one separately to ensure platform-specific subdirectories
    # Docker buildx only creates subdirectories when building multiple platforms simultaneously
    # We want consistent output structure regardless of single or multi-platform builds
    local platform_list
    IFS=',' read -ra platform_list <<< "$platforms"

    local build_failed=0
    for platform in "${platform_list[@]}"; do
        # Convert platform format: linux/amd64 -> linux_amd64
        local platform_dir="${platform//\//_}"
        local platform_output_dir="$output_dir/$platform_dir"

        log_info "Building for platform: $platform -> $platform_output_dir"

        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY RUN] Would run: $docker_cmd buildx build --platform $platform ..."
            log_info "[DRY RUN]   --build-arg VARIANT=$variant"
            log_info "[DRY RUN]   --build-arg VLLM_VERSION=$version"
            log_info "[DRY RUN]   --build-arg PYTHON_VERSION=$python_ver"
            log_info "[DRY RUN]   --build-arg VERSION_SUFFIX=$VERSION_SUFFIX"
            log_info "[DRY RUN]   --output type=local,dest=$platform_output_dir"
            continue
        fi

        # Ensure platform-specific output directory exists
        mkdir -p "$platform_output_dir"

        # Build command - use array for proper argument handling
        local cmd_args=(
            buildx build
            --platform "$platform"
            --build-arg "VARIANT=$variant"
            --build-arg "VLLM_VERSION=$version"
            --build-arg "PYTHON_VERSION=$python_ver"
            --build-arg "MAX_JOBS=$MAX_JOBS"
            --build-arg "VERSION_SUFFIX=$VERSION_SUFFIX"
            --output "type=local,dest=$platform_output_dir"
            --progress "$PROGRESS"
            -f "$SCRIPT_DIR/Dockerfile.buildx"
        )

        # Add no-cache flag if specified
        if [[ -n "$NO_CACHE" ]]; then
            cmd_args+=("$NO_CACHE")
        fi

        # Add build context
        cmd_args+=("$SCRIPT_DIR")

        log_info "Running: $docker_cmd ${cmd_args[*]}"
        echo ""

        # Execute build
        if $docker_cmd "${cmd_args[@]}"; then
            log_success "Build completed for $platform: $variant v$version (Python $python_ver)"
        else
            log_error "Build failed for $platform: $variant v$version (Python $python_ver)"
            build_failed=1
        fi
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi

    if [[ $build_failed -eq 0 ]]; then
        log_success "All platform builds completed: $variant v$version (Python $python_ver)"
        return 0
    else
        log_error "Some platform builds failed: $variant v$version (Python $python_ver)"
        return 1
    fi
}

# Main function
main() {
    parse_args "$@"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     vLLM CPU Wheel Builder (Docker Buildx) v${SCRIPT_VERSION}          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ $DRY_RUN -eq 1 ]]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
        echo ""
    fi

    # Check and install dependencies (skip in dry-run for actual installs)
    check_and_install_dependencies || exit 1

    # Verify Docker is running (skip in dry-run)
    if [[ $DRY_RUN -eq 0 ]]; then
        check_docker_running || exit 1
    fi

    # Normalize variant if using short name
    if [[ "$VARIANT" != "all" ]] && [[ "$VARIANT" != vllm-cpu* ]]; then
        VARIANT=$(normalize_variant "$VARIANT") || exit 1
    fi

    # Validate variant
    validate_variant "$VARIANT"

    # Determine vLLM version(s)
    if [[ -z "$VLLM_VERSIONS" ]]; then
        log_error "vLLM version is required"
        log_info "Usage: $SCRIPT_NAME --variant=$VARIANT --vllm-versions=0.11.2"
        exit 1
    fi

    # Expand Python versions
    local python_versions_array
    read -ra python_versions_array <<< "$(expand_python_versions "$PYTHON_VERSIONS")"

    # Split vLLM versions
    IFS=',' read -ra vllm_versions_array <<< "$VLLM_VERSIONS"

    # Determine variants to build
    local variants_to_build=()
    if [[ "$VARIANT" == "all" ]]; then
        read -ra variants_to_build <<< "$ALL_VARIANTS"
    else
        variants_to_build=("$VARIANT")
    fi

    # Calculate total builds
    local total_builds=$((${#variants_to_build[@]} * ${#vllm_versions_array[@]} * ${#python_versions_array[@]}))

    log_info "Build plan:"
    log_info "  Variants:        ${variants_to_build[*]}"
    log_info "  vLLM versions:   ${vllm_versions_array[*]}"
    log_info "  Python versions: ${python_versions_array[*]}"
    log_info "  Total builds:    $total_builds"
    echo ""

    # Setup QEMU and buildx builder once
    local first_platforms
    first_platforms=$(get_variant_platforms "${variants_to_build[0]}")

    setup_qemu "$first_platforms"
    setup_buildx_builder "$BUILDER_NAME"

    # Build loop
    local build_count=0
    local failed_count=0

    for variant in "${variants_to_build[@]}"; do
        # Get supported platforms for this variant from config
        local supported_platforms
        supported_platforms=$(get_variant_platforms "$variant")

        # Determine which platforms to build
        local build_platforms
        if [[ "$PLATFORM" == "auto" ]] || [[ "$PLATFORM" == "all" ]]; then
            # Auto/all: build for all platforms this variant supports
            build_platforms="$supported_platforms"
            log_info "Building $variant for supported platforms: $build_platforms"
        else
            # User specified specific platform(s) - validate against supported
            build_platforms=""
            IFS=',' read -ra requested_platforms <<< "$PLATFORM"
            for req_plat in "${requested_platforms[@]}"; do
                if [[ "$supported_platforms" == *"$req_plat"* ]]; then
                    build_platforms="${build_platforms:+$build_platforms,}$req_plat"
                else
                    log_warning "Skipping $req_plat for $variant (not supported - only: $supported_platforms)"
                fi
            done

            if [[ -z "$build_platforms" ]]; then
                log_warning "No compatible platforms for $variant - skipping entirely"
                continue
            fi
        fi

        for vllm_ver in "${vllm_versions_array[@]}"; do
            for py_ver in "${python_versions_array[@]}"; do
                ((build_count++)) || true
                echo ""
                log_step "═══════════════════════════════════════════════════════════"
                log_step "Build $build_count/$total_builds"
                log_step "═══════════════════════════════════════════════════════════"

                if build_single_wheel "$variant" "$vllm_ver" "$py_ver" "$build_platforms" "$OUTPUT_DIR"; then
                    log_success "✓ Build $build_count/$total_builds completed"
                else
                    ((failed_count++)) || true
                    log_error "✗ Build $build_count/$total_builds failed"
                fi
            done
        done
    done

    # Show results
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    if [[ $failed_count -eq 0 ]]; then
        log_success "All $total_builds build(s) completed successfully!"
    else
        log_warning "$((total_builds - failed_count))/$total_builds builds succeeded, $failed_count failed"
    fi
    echo ""
    log_info "Output directory: $OUTPUT_DIR"

    # List built wheels (skip in dry-run)
    if [[ $DRY_RUN -eq 0 ]] && [[ -d "$OUTPUT_DIR" ]]; then
        echo ""
        log_info "Built wheels:"
        find "$OUTPUT_DIR" -name "*.whl" -type f 2>/dev/null | while read -r whl; do
            local size
            size=$(du -h "$whl" | cut -f1)
            echo "  - $(basename "$whl") ($size)"
        done

        echo ""
        log_info "Directory structure:"
        if command -v tree &>/dev/null; then
            tree -L 2 "$OUTPUT_DIR" 2>/dev/null || ls -laR "$OUTPUT_DIR"
        else
            ls -laR "$OUTPUT_DIR"
        fi
    fi

    echo ""
    log_info "To test a wheel:"
    echo "  pip install $OUTPUT_DIR/linux_amd64/*.whl"
    echo "  python -c \"import vllm; print(vllm.__version__)\""

    # Return failure if any builds failed
    if [[ $failed_count -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
