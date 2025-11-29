#!/usr/bin/env bash
#
# vLLM CPU PyPI Wheel Builder
# Builds vLLM from source with CPU-specific optimizations for Debian Trixie
# Uses official vLLM requirements: cpu.txt and cpu-build.txt
#
# Usage:
#   ./pypi-builder.sh [OPTIONS]
#
# Options:
#   --python-version=3.13        Python version to use (default: 3.13)
#   --disable-avx512             Disable AVX512 instructions
#   --enable-avx512bf16          Enable AVX512BF16 ISA
#   --enable-avx512vnni          Enable AVX512VNNI ISA
#   --enable-amxbf16             Enable AMXBF16 ISA
#   --max-jobs=N                 Maximum parallel build jobs (default: CPU core count)
#   --venv-path=/vllm/venv       Virtual environment path (default: /vllm/venv)
#   --skip-deps                  Skip system dependency installation
#   --requirements-dir=PATH      Directory containing cpu.txt and cpu-build.txt
#   --no-cleanup                 Skip cleanup of build packages and caches
#   --help                       Show this help message
#
# Requirements Files:
#   - common.txt: Shared dependencies (transformers, fastapi, etc.)
#   - cpu.txt: Runtime dependencies (PyTorch 2.8.0, IPEX, Intel OpenMP, etc.)
#   - cpu-build.txt: Build dependencies (cmake, ninja, setuptools-scm, etc.)
#
# Note: cpu.txt references common.txt with "-r common.txt"
#       All three files must be in the same directory.
#
# For Docker builds:
#   - Use cpu-build.txt during build stage
#   - Use cpu.txt + common.txt for final runtime image
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
PYTHON_VERSION="3.13.9"
VLLM_CPU_DISABLE_AVX512=0
VLLM_CPU_AVX512BF16=0
VLLM_CPU_AVX512VNNI=0
VLLM_CPU_AMXBF16=0
MAX_JOBS=0  # Will be set to CPU core count if not specified
VENV_PATH="/vllm/venv"
SKIP_DEPS=0
NO_CLEANUP=0
WORKSPACE="/vllm"
REQUIREMENTS_DIR=""

# Get CPU core count for MAX_JOBS
get_cpu_cores() {
    nproc
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [[ $NO_CLEANUP -eq 0 ]] && [[ ${CLEANUP_CALLED:-0} -eq 0 ]]; then
        CLEANUP_CALLED=1
        log_info "Performing cleanup on exit..."
    fi
    exit "$exit_code"
}

# Set trap for cleanup
trap cleanup EXIT ERR INT TERM

# Validate Python version format
validate_python_version() {
    local version="$1"
    if ! [[ "$version" =~ ^3\.[0-9]{1,2}(\.[0-9]+)?$ ]]; then
        log_error "Invalid Python version format: $version"
        log_info "Expected format: 3.X or 3.X.Y (e.g., 3.13 or 3.13.9)"
        return 1
    fi
    return 0
}

# Validate MAX_JOBS
validate_max_jobs() {
    local jobs="$1"
    if ! [[ "$jobs" =~ ^[0-9]+$ ]]; then
        log_error "MAX_JOBS must be a positive integer, got: $jobs"
        return 1
    fi
    if [[ "$jobs" -lt 0 ]]; then
        log_error "MAX_JOBS must be non-negative (0 = auto)"
        return 1
    fi
    return 0
}

# Validate path to prevent directory traversal
validate_path() {
    local path="$1"
    local description="$2"

    # Resolve to absolute path
    if ! path=$(realpath -m "$path" 2>/dev/null); then
        log_error "Invalid path for $description: $path"
        return 1
    fi

    # Check for directory traversal attempts
    if [[ "$path" == *".."* ]]; then
        log_error "Directory traversal detected in $description: $path"
        return 1
    fi

    printf '%s' "$path"
    return 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --python-version=*)
                PYTHON_VERSION="${1#*=}"
                if ! validate_python_version "$PYTHON_VERSION"; then
                    exit 1
                fi
                shift
                ;;
            --disable-avx512)
                VLLM_CPU_DISABLE_AVX512=1
                shift
                ;;
            --enable-avx512bf16)
                VLLM_CPU_AVX512BF16=1
                shift
                ;;
            --enable-avx512vnni)
                VLLM_CPU_AVX512VNNI=1
                shift
                ;;
            --enable-amxbf16)
                VLLM_CPU_AMXBF16=1
                shift
                ;;
            --max-jobs=*)
                MAX_JOBS="${1#*=}"
                if ! validate_max_jobs "$MAX_JOBS"; then
                    exit 1
                fi
                shift
                ;;
            --venv-path=*)
                VENV_PATH="${1#*=}"
                if ! VENV_PATH=$(validate_path "$VENV_PATH" "venv-path"); then
                    exit 1
                fi
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=1
                shift
                ;;
            --requirements-dir=*)
                REQUIREMENTS_DIR="${1#*=}"
                if ! REQUIREMENTS_DIR=$(validate_path "$REQUIREMENTS_DIR" "requirements-dir"); then
                    exit 1
                fi
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=1
                shift
                ;;
            --help)
                grep '^#' "$0" | grep -v '#!/' | sed 's/^# //'
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]] && [[ $SKIP_DEPS -eq 0 ]]; then
        log_error "This script must be run as root for system dependency installation"
        log_info "Run with sudo or use --skip-deps to skip system packages"
        exit 1
    fi
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)
            echo "x86_64"
            ;;
        aarch64)
            echo "aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Find requirements files
find_requirements_files() {
    local common_txt=""
    local cpu_txt=""
    local cpu_build_txt=""

    # Search locations in order
    local script_dir
    script_dir=$(dirname "$(realpath "$0")")

    local search_paths=(
        "${REQUIREMENTS_DIR}"
        "$script_dir"
        "/vllm/requirements"
        "${WORKSPACE}/requirements"
        "."
    )

    for path in "${search_paths[@]}"; do
        if [[ -z "$path" ]] || [[ ! -d "$path" ]]; then
            continue
        fi

        if [[ -f "$path/common.txt" ]] && [[ -z "$common_txt" ]]; then
            common_txt="$path/common.txt"
        fi

        if [[ -f "$path/cpu.txt" ]] && [[ -z "$cpu_txt" ]]; then
            cpu_txt="$path/cpu.txt"
        fi

        if [[ -f "$path/cpu-build.txt" ]] && [[ -z "$cpu_build_txt" ]]; then
            cpu_build_txt="$path/cpu-build.txt"
        fi

        if [[ -n "$common_txt" ]] && [[ -n "$cpu_txt" ]] && [[ -n "$cpu_build_txt" ]]; then
            break
        fi
    done

    if [[ -z "$common_txt" ]]; then
        log_error "common.txt not found. Required by cpu.txt"
        exit 1
    fi

    if [[ -z "$cpu_txt" ]]; then
        log_error "cpu.txt not found. Please provide --requirements-dir or place files in script directory"
        exit 1
    fi

    if [[ -z "$cpu_build_txt" ]]; then
        log_error "cpu-build.txt not found. Required for building from source"
        exit 1
    fi

    export COMMON_REQUIREMENTS="$common_txt"
    export CPU_REQUIREMENTS="$cpu_txt"
    export CPU_BUILD_REQUIREMENTS="$cpu_build_txt"

    log_info "Found requirements files:"
    log_info "  Common:  $COMMON_REQUIREMENTS"
    log_info "  Runtime: $CPU_REQUIREMENTS"
    log_info "  Build:   $CPU_BUILD_REQUIREMENTS"
}

# Install system dependencies
install_system_deps() {
    if [[ $SKIP_DEPS -eq 1 ]]; then
        log_info "Skipping system dependency installation"
        return
    fi

    log_info "Installing system dependencies..."

    # Update package lists
    if ! apt-get update -y; then
        log_error "Failed to update package lists"
        exit 1
    fi

    # Install core dependencies
    if ! apt-get install -y --no-install-recommends \
        sudo \
        ccache \
        git \
        curl \
        wget \
        ca-certificates \
        gcc-14 \
        g++-14 \
        libtcmalloc-minimal4 \
        libnuma-dev \
        jq \
        lsof \
        vim \
        numactl \
        xz-utils; then
        log_error "Failed to install system dependencies"
        exit 1
    fi

    # Verify critical packages were installed
    for pkg in gcc-14 g++-14 libtcmalloc-minimal4 libnuma-dev; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            log_error "Critical package not installed: $pkg"
            exit 1
        fi
    done

    # Set gcc-14 as default
    if ! update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 10 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-14; then
        log_warning "Failed to set gcc-14 as default"
    fi

    log_success "System dependencies installed"
}

# Install uv package manager
install_uv() {
    log_info "Installing uv package manager..."

    if command -v uv &> /dev/null; then
        log_info "uv is already installed"
    else
        # Download and verify install script
        local temp_script
        temp_script=$(mktemp)
        chmod 700 "$temp_script"

        if ! curl -LsSf -o "$temp_script" https://astral.sh/uv/install.sh; then
            log_error "Failed to download uv installer"
            rm -f "$temp_script"
            exit 1
        fi

        # Execute install script
        if ! sh "$temp_script"; then
            log_error "Failed to install uv"
            rm -f "$temp_script"
            exit 1
        fi

        rm -f "$temp_script"
        export PATH="/root/.local/bin:$PATH"
    fi

    # Verify installation
    if ! command -v uv &> /dev/null; then
        log_error "uv installation verification failed"
        exit 1
    fi

    log_success "uv installed"
}

# Setup Python virtual environment
setup_venv() {
    log_info "Setting up Python ${PYTHON_VERSION} virtual environment at ${VENV_PATH}..."

    export UV_PYTHON_INSTALL_DIR=/opt/uv/python

    if [[ -d "${VENV_PATH}" ]]; then
        log_info "Virtual environment already exists at ${VENV_PATH}"
        log_info "Reusing existing environment and checking for missing packages..."

        # Activate existing environment
        # shellcheck source=/dev/null
        if ! source "${VENV_PATH}/bin/activate"; then
            log_error "Failed to activate existing virtual environment"
            exit 1
        fi

        # Verify Python version matches
        local current_py_version
        current_py_version=$(python --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
        local requested_py_version
        requested_py_version=$(echo "$PYTHON_VERSION" | cut -d. -f1,2)

        if [[ "$current_py_version" != "$requested_py_version" ]]; then
            log_warning "Existing venv has Python $current_py_version, but $PYTHON_VERSION was requested"
            log_info "Recreating virtual environment..."
            deactivate || true

            # Safe removal with validation
            if [[ -d "${VENV_PATH}" ]] && [[ "${VENV_PATH}" != "/" ]] && [[ "${VENV_PATH}" != "/root" ]]; then
                rm -rf "${VENV_PATH}"
            else
                log_error "Refusing to remove suspicious path: ${VENV_PATH}"
                exit 1
            fi

            if ! uv venv --python "${PYTHON_VERSION}" --seed "${VENV_PATH}"; then
                log_error "Failed to create virtual environment"
                exit 1
            fi

            # shellcheck source=/dev/null
            if ! source "${VENV_PATH}/bin/activate"; then
                log_error "Failed to activate new virtual environment"
                exit 1
            fi
        fi
    else
        if ! uv venv --python "${PYTHON_VERSION}" --seed "${VENV_PATH}"; then
            log_error "Failed to create virtual environment"
            exit 1
        fi

        # shellcheck source=/dev/null
        if ! source "${VENV_PATH}/bin/activate"; then
            log_error "Failed to activate virtual environment"
            exit 1
        fi
    fi

    log_success "Virtual environment ready"
}

# Setup environment variables
setup_env_vars() {
    log_info "Setting up environment variables..."

    local arch
    arch=$(detect_arch)

    # Set MAX_JOBS to CPU core count if not specified
    if [[ $MAX_JOBS -eq 0 ]]; then
        MAX_JOBS=$(get_cpu_cores)
        log_info "Using MAX_JOBS=$MAX_JOBS (CPU core count)"
    fi

    # Export environment variables
    export CCACHE_DIR=/root/.cache/ccache
    export CMAKE_CXX_COMPILER_LAUNCHER=ccache
    export PATH="${VENV_PATH}/bin:/root/.local/bin:$PATH"
    export VIRTUAL_ENV="${VENV_PATH}"
    export UV_HTTP_TIMEOUT=500
    export UV_INDEX_STRATEGY="unsafe-best-match"
    export UV_LINK_MODE="copy"
    export TARGETARCH="${arch}"
    export MAX_JOBS="${MAX_JOBS}"
    export VLLM_TARGET_DEVICE=cpu

    # vLLM CPU build flags
    export VLLM_CPU_DISABLE_AVX512="${VLLM_CPU_DISABLE_AVX512}"
    export VLLM_CPU_AVX512BF16="${VLLM_CPU_AVX512BF16}"
    export VLLM_CPU_AVX512VNNI="${VLLM_CPU_AVX512VNNI}"
    export VLLM_CPU_AMXBF16="${VLLM_CPU_AMXBF16}"

    # Set LD_PRELOAD based on architecture - SAFE VERSION
    local tcmalloc_lib=""
    local iomp_lib="${VENV_PATH}/lib/libiomp5.so"

    if [[ "$arch" == "x86_64" ]]; then
        tcmalloc_lib="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"
    else
        tcmalloc_lib="/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4"
    fi

    # Validate libraries exist before setting LD_PRELOAD
    local ld_preload_value=""
    if [[ -f "$tcmalloc_lib" ]]; then
        ld_preload_value="$tcmalloc_lib"
    else
        log_warning "tcmalloc library not found: $tcmalloc_lib"
    fi

    if [[ "$arch" == "x86_64" ]] && [[ -f "$iomp_lib" ]]; then
        if [[ -n "$ld_preload_value" ]]; then
            ld_preload_value="${ld_preload_value}:${iomp_lib}"
        else
            ld_preload_value="$iomp_lib"
        fi
    fi

    if [[ -n "$ld_preload_value" ]]; then
        export LD_PRELOAD="$ld_preload_value"
    fi

    log_success "Environment variables configured"
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies from official vLLM requirements..."

    # Upgrade pip
    if ! uv pip install --upgrade pip; then
        log_error "Failed to upgrade pip"
        exit 1
    fi

    # Check if torch and vllm are already installed
    local torch_installed=0
    local vllm_installed=0

    if python -c "import torch" 2>/dev/null; then
        local torch_version
        torch_version=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
        log_info "PyTorch already installed: $torch_version"
        torch_installed=1
    fi

    if python -c "import vllm" 2>/dev/null; then
        local vllm_version
        vllm_version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)
        log_info "vLLM already installed: $vllm_version"
        vllm_installed=1
    fi

    # Install runtime dependencies from cpu.txt
    log_info "Installing/updating runtime dependencies from cpu.txt..."
    if ! uv pip install -r "${CPU_REQUIREMENTS}"; then
        log_error "Failed to install runtime dependencies"
        exit 1
    fi

    if [[ $torch_installed -eq 1 ]] && [[ $vllm_installed -eq 1 ]]; then
        log_success "All packages verified/updated"
    else
        log_success "Python dependencies installed"
    fi
}

# Install build dependencies
install_build_deps() {
    log_info "Installing build dependencies from cpu-build.txt..."
    if ! uv pip install -r "${CPU_BUILD_REQUIREMENTS}"; then
        log_error "Failed to install build dependencies"
        exit 1
    fi
    log_success "Build dependencies installed"
}

# Install vLLM from source
install_vllm_from_source() {
    log_info "Installing vLLM from source..."

    # Check if vLLM is already installed
    if python -c "import vllm" 2>/dev/null; then
        local vllm_version
        vllm_version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)
        log_info "vLLM $vllm_version is already installed"
        log_info "Skipping source build (manually remove venv to rebuild)"
        return
    fi

    # Install build dependencies first
    install_build_deps

    # Validate and create workspace
    if [[ ! -d "$WORKSPACE" ]]; then
        if ! mkdir -p "$WORKSPACE"; then
            log_error "Failed to create workspace directory: $WORKSPACE"
            exit 1
        fi
    fi

    if ! cd "$WORKSPACE"; then
        log_error "Failed to change to workspace directory: $WORKSPACE"
        exit 1
    fi

    # Clone vLLM if not already present
    if [[ ! -d "vllm" ]]; then
        log_info "Cloning vLLM repository..."
        if ! git clone https://github.com/vllm-project/vllm.git; then
            log_error "Failed to clone vLLM repository"
            exit 1
        fi
    else
        log_info "Using existing vLLM repository at $WORKSPACE/vllm"
        log_info "To use latest code: rm -rf $WORKSPACE/vllm and re-run"
    fi

    if ! cd vllm; then
        log_error "Failed to change to vllm directory"
        exit 1
    fi

    # Build and install vLLM
    log_info "Building vLLM (this may take 30-60 minutes)..."
    if ! VLLM_TARGET_DEVICE=cpu python3 setup.py bdist_wheel --dist-dir=dist --py-limited-api=cp38; then
        log_error "Failed to build vLLM wheel"
        exit 1
    fi

    log_info "Installing vLLM wheel..."

    # Enable nullglob for safe file operations
    shopt -s nullglob
    local wheels=(dist/*.whl)
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        log_error "No wheels found in dist/"
        exit 1
    fi

    if ! uv pip install "${wheels[@]}"; then
        log_error "Failed to install vLLM wheel"
        exit 1
    fi

    log_success "vLLM built and installed successfully"
}

# Create activation script
create_activation_script() {
    log_info "Creating activation script..."

    local arch
    arch=$(detect_arch)

    cat > "${VENV_PATH}/activate_vllm.sh" << EOF
#!/usr/bin/env bash
# vLLM CPU environment activation script

export CCACHE_DIR=/root/.cache/ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache
export VIRTUAL_ENV="${VENV_PATH}"
export PATH="${VENV_PATH}/bin:/root/.local/bin:\$PATH"
export UV_HTTP_TIMEOUT=500
export UV_INDEX_STRATEGY="unsafe-best-match"
export UV_LINK_MODE="copy"
export TARGETARCH="${arch}"
export MAX_JOBS="${MAX_JOBS}"
export VLLM_TARGET_DEVICE=cpu

# vLLM CPU build flags
export VLLM_CPU_DISABLE_AVX512="${VLLM_CPU_DISABLE_AVX512}"
export VLLM_CPU_AVX512BF16="${VLLM_CPU_AVX512BF16}"
export VLLM_CPU_AVX512VNNI="${VLLM_CPU_AVX512VNNI}"
export VLLM_CPU_AMXBF16="${VLLM_CPU_AMXBF16}"

# Set LD_PRELOAD based on architecture
if [[ "\$(uname -m)" == "x86_64" ]]; then
    if [[ -f "/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4" ]]; then
        export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"
        if [[ -f "${VENV_PATH}/lib/libiomp5.so" ]]; then
            export LD_PRELOAD="\${LD_PRELOAD}:${VENV_PATH}/lib/libiomp5.so"
        fi
    fi
else
    if [[ -f "/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4" ]]; then
        export LD_PRELOAD="/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4"
    fi
fi

# Activate virtual environment
source "${VENV_PATH}/bin/activate"

echo "vLLM CPU environment activated"
echo "Python: \$(python --version)"
echo "PyTorch: \$(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'not installed')"
echo "vLLM: \$(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null || echo 'not installed')"
EOF

    if ! chmod +x "${VENV_PATH}/activate_vllm.sh"; then
        log_warning "Failed to make activation script executable"
    fi

    log_success "Activation script created at ${VENV_PATH}/activate_vllm.sh"
}

# Cleanup unnecessary packages and caches
cleanup_system() {
    echo ""
    echo "=========================================="
    echo "🧹 CLEANUP PHASE STARTED"
    echo "=========================================="
    echo ""

    # Get disk usage before cleanup
    local disk_before
    disk_before=$(df -h / | awk 'NR==2 {print $3}')
    log_info "Disk usage before cleanup: $disk_before"
    echo ""

    if [[ $SKIP_DEPS -eq 1 ]]; then
        log_warning "Skipping system package cleanup (--skip-deps was used)"
    else
        echo "----------------------------------------"
        log_info "STEP 1: Removing build tools and development packages"
        echo "----------------------------------------"

        # List packages to remove
        log_info "The following packages will be removed:"
        echo "  - git, wget, curl (download tools)"
        echo "  - ccache (compilation cache)"
        echo "  - gcc-14, g++-14 (compilers)"
        echo ""

        # Remove build-only packages (ignore failures)
        apt-get remove -y --purge \
            git \
            wget \
            curl \
            ccache \
            gcc-14 \
            g++-14 \
            cpp-14 \
            binutils \
            2>/dev/null || true

        log_success "Build tools removed"
        echo ""

        # Autoremove dependencies
        echo "----------------------------------------"
        log_info "STEP 2: Removing orphaned packages"
        echo "----------------------------------------"
        apt-get autoremove -y --purge 2>&1 | grep -E "^Removing|^Purging" || true
        log_success "Orphaned packages removed"
        echo ""

        # Clean all apt caches thoroughly
        echo "----------------------------------------"
        log_info "STEP 3: Cleaning APT caches"
        echo "----------------------------------------"

        local apt_cache_size
        apt_cache_size=$(du -sh /var/cache/apt 2>/dev/null | awk '{print $1}' || echo "0")
        log_info "APT cache size before: $apt_cache_size"

        apt-get autoclean -y
        apt-get clean -y
        rm -rf /var/lib/apt/lists/* 2>/dev/null || true
        rm -rf /var/cache/apt/archives/* 2>/dev/null || true
        rm -rf /var/cache/apt/*.bin 2>/dev/null || true

        log_success "APT caches cleaned (freed ~$apt_cache_size)"
        echo ""
    fi

    # Clean Python/pip/uv caches thoroughly
    echo "----------------------------------------"
    log_info "STEP 4: Cleaning Python package caches"
    echo "----------------------------------------"

    local cache_size_before=0
    if [[ -d /root/.cache ]]; then
        cache_size_before=$(du -sh /root/.cache 2>/dev/null | awk '{print $1}' || echo "0")
        log_info "Python cache size before: $cache_size_before"
    fi

    rm -rf /root/.cache/pip 2>/dev/null || true
    rm -rf /root/.cache/uv 2>/dev/null || true
    rm -rf /root/.cache/torch 2>/dev/null || true
    rm -rf /root/.cache/ccache 2>/dev/null || true

    log_success "Python caches cleaned (freed ~$cache_size_before)"
    echo ""

    # Remove vLLM source directory with validation
    echo "----------------------------------------"
    log_info "STEP 5: Removing vLLM source repository"
    echo "----------------------------------------"

    local vllm_source_dir="${WORKSPACE}/vllm"

    # Validate path before removal
    if [[ -d "$vllm_source_dir" ]] && \
       [[ "$vllm_source_dir" != "/" ]] && \
       [[ "$vllm_source_dir" != "/root" ]] && \
       [[ "$vllm_source_dir" != "/home" ]] && \
       [[ "$vllm_source_dir" =~ /vllm$ ]]; then

        local vllm_size
        vllm_size=$(du -sh "$vllm_source_dir" 2>/dev/null | awk '{print $1}')
        log_info "vLLM source directory: $vllm_source_dir"
        log_info "Directory size: $vllm_size"

        # Move out of directory first
        cd / 2>/dev/null || true

        if rm -rf "$vllm_source_dir" 2>/dev/null; then
            if [[ ! -d "$vllm_source_dir" ]]; then
                log_success "vLLM source directory removed (freed ~$vllm_size)"
            else
                log_warning "vLLM source directory still exists after removal"
            fi
        else
            log_warning "Failed to remove vLLM source directory"
        fi
    else
        log_info "vLLM source directory not found or invalid path"
    fi
    echo ""

    # Final summary
    echo "=========================================="
    echo "🎉 CLEANUP COMPLETED"
    echo "=========================================="

    local disk_after
    disk_after=$(df -h / | awk 'NR==2 {print $3}')
    local disk_available
    disk_available=$(df -h / | awk 'NR==2 {print $4}')

    echo ""
    log_info "Disk usage after cleanup: $disk_after"
    log_info "Available disk space: $disk_available"
    echo ""
}

# Print summary
print_summary() {
    local arch
    arch=$(detect_arch)

    log_success "vLLM CPU setup completed!"
    echo ""
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "Python Version:    $("${VENV_PATH}"/bin/python -V)"
    echo "Install Method:    Built from source"
    echo "Virtual Env:       ${VENV_PATH}"
    echo "Architecture:      ${arch}"
    echo "Max Jobs:          ${MAX_JOBS}"
    echo "AVX512 Disabled:   ${VLLM_CPU_DISABLE_AVX512}"
    echo "AVX512BF16:        ${VLLM_CPU_AVX512BF16}"
    echo "AVX512VNNI:        ${VLLM_CPU_AVX512VNNI}"
    echo "AMXBF16:           ${VLLM_CPU_AMXBF16}"
    echo "=========================================="
    echo ""
    echo "Requirements used:"
    echo "  Common:  ${COMMON_REQUIREMENTS}"
    echo "  Runtime: ${CPU_REQUIREMENTS}"
    echo "  Build:   ${CPU_BUILD_REQUIREMENTS}"

    if [[ "$arch" == "x86_64" ]]; then
        echo "Verifying Intel Extensions:"
        "${VENV_PATH}"/bin/python -c 'import intel_extension_for_pytorch as ipex; print("IPEX:", ipex.__version__)' 2>/dev/null || echo "IPEX: not available"
    fi

    echo ""
    echo "Verifying PyTorch installation:"
    "${VENV_PATH}"/bin/python -c 'import torch; print("PyTorch:", torch.__version__)' 2>/dev/null || echo "PyTorch: not installed"
    echo ""
    echo "Verifying vLLM installation:"
    "${VENV_PATH}"/bin/python -c 'import vllm; print("vLLM:", vllm.__version__)' 2>/dev/null || echo "vLLM: not installed"
    echo ""
}

# Main execution
main() {
    log_info "Starting vLLM CPU setup for Debian Trixie"

    parse_args "$@"
    check_root
    find_requirements_files
    install_system_deps
    install_uv
    setup_venv
    setup_env_vars
    install_python_deps
    install_vllm_from_source
    create_activation_script

    # Cleanup
    if [[ $NO_CLEANUP -eq 0 ]]; then
        cleanup_system
    else
        log_info "Skipping cleanup (--no-cleanup was used)"
    fi

    print_summary
}

# Run main
main "$@"
