#!/usr/bin/env bash
#
# vLLM CPU Setup Script for Debian Trixie
# Based on vLLM's Dockerfile.cpu
# Uses official vLLM requirements: cpu.txt and cpu-build.txt
#
# Usage:
#   ./setup_vllm_debian_trixie.sh [OPTIONS]
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
#   --from-pypi                  Install from PyPI instead of building from source
#   --requirements-dir=PATH      Directory containing cpu.txt and cpu-build.txt
#   --no-cleanup                 Skip cleanup of build packages and caches
#   --help                       Show this help message
#
# Note: Default is to build from source. Use --from-pypi for faster installation.
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
BUILD_FROM_SOURCE=1  # Default to building from source
NO_CLEANUP=0
WORKSPACE="/vllm"
REQUIREMENTS_DIR=""

# Get CPU core count for MAX_JOBS
get_cpu_cores() {
    local cpu_cores=$(nproc)
    echo $cpu_cores
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

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --python-version=*)
                PYTHON_VERSION="${1#*=}"
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
                shift
                ;;
            --venv-path=*)
                VENV_PATH="${1#*=}"
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=1
                shift
                ;;
            --from-pypi)
                BUILD_FROM_SOURCE=0
                shift
                ;;
            --requirements-dir=*)
                REQUIREMENTS_DIR="${1#*=}"
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
    local arch=$(uname -m)
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
    local search_paths=(
        "${REQUIREMENTS_DIR}"
        "$(dirname "$0")"
        "/vllm/requirements"
        "/$WORKSPACE/requirements"
        "."
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -z "$path" ]]; then
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
    
    if [[ $BUILD_FROM_SOURCE -eq 1 ]] && [[ -z "$cpu_build_txt" ]]; then
        log_error "cpu-build.txt not found. Required for --build-from-source"
        exit 1
    fi
    
    export COMMON_REQUIREMENTS="$common_txt"
    export CPU_REQUIREMENTS="$cpu_txt"
    export CPU_BUILD_REQUIREMENTS="$cpu_build_txt"
    
    log_info "Found requirements files:"
    log_info "  Common:  $COMMON_REQUIREMENTS"
    log_info "  Runtime: $CPU_REQUIREMENTS"
    if [[ $BUILD_FROM_SOURCE -eq 1 ]]; then
        log_info "  Build:   $CPU_BUILD_REQUIREMENTS"
    fi
}

# Install system dependencies
install_system_deps() {
    if [[ $SKIP_DEPS -eq 1 ]]; then
        log_info "Skipping system dependency installation"
        return
    fi

    log_info "Installing system dependencies..."
    
    # Update package lists
    apt-get update -y
    
    # Install core dependencies
    apt-get install -y --no-install-recommends \
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
        xz-utils
    
    # Set gcc-14 as default
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 10 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-14
    
    log_success "System dependencies installed"
}

# Install uv package manager
install_uv() {
    log_info "Installing uv package manager..."
    
    if command -v uv &> /dev/null; then
        log_info "uv is already installed"
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="/root/.local/bin:$PATH"
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
        source "${VENV_PATH}/bin/activate"
        
        # Verify Python version matches
        local current_py_version=$(python --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
        if [[ "$current_py_version" != "$PYTHON_VERSION" ]]; then
            log_warning "Existing venv has Python $current_py_version, but $PYTHON_VERSION was requested"
            log_info "Recreating virtual environment..."
            deactivate || true
            rm -rf "${VENV_PATH}"
            uv venv --python "${PYTHON_VERSION}" --seed "${VENV_PATH}"
            source "${VENV_PATH}/bin/activate"
        fi
    else
        uv venv --python "${PYTHON_VERSION}" --seed "${VENV_PATH}"
        source "${VENV_PATH}/bin/activate"
    fi
    
    log_success "Virtual environment ready"
}

# Setup environment variables
setup_env_vars() {
    log_info "Setting up environment variables..."
    
    local arch=$(detect_arch)
    
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
    
    # Set LD_PRELOAD based on architecture
    if [[ "$arch" == "x86_64" ]]; then
        export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4:${VENV_PATH}/lib/libiomp5.so"
    else
        export LD_PRELOAD="/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4"
    fi
    
    log_success "Environment variables configured"
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies from official vLLM requirements..."
    
    # Upgrade pip
    uv pip install --upgrade pip
    
    # Check if torch and vllm are already installed
    local torch_installed=0
    local vllm_installed=0
    
    if python -c "import torch" 2>/dev/null; then
        local torch_version=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
        log_info "PyTorch already installed: $torch_version"
        torch_installed=1
    fi
    
    if python -c "import vllm" 2>/dev/null; then
        local vllm_version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)
        log_info "vLLM already installed: $vllm_version"
        vllm_installed=1
    fi
    
    # Install runtime dependencies from cpu.txt
    # uv pip install will automatically skip already satisfied packages
    log_info "Installing/updating runtime dependencies from cpu.txt..."
    uv pip install -r "${CPU_REQUIREMENTS}"
    
    if [[ $torch_installed -eq 1 ]] && [[ $vllm_installed -eq 1 ]]; then
        log_success "All packages verified/updated"
    else
        log_success "Python dependencies installed"
    fi
}

# Install build dependencies
install_build_deps() {
    log_info "Installing build dependencies from cpu-build.txt..."
    uv pip install -r "${CPU_BUILD_REQUIREMENTS}"
    log_success "Build dependencies installed"
}

# Install vLLM from source
install_vllm_from_source() {
    log_info "Installing vLLM from source..."
    
    # Check if vLLM is already installed
    if python -c "import vllm" 2>/dev/null; then
        local vllm_version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)
        log_info "vLLM $vllm_version is already installed"
        log_info "Skipping source build (use --from-pypi to reinstall or manually remove venv)"
        return
    fi
    
    # Install build dependencies first
    install_build_deps
    
    if [[ ! -d "$WORKSPACE" ]]; then
        mkdir -p "$WORKSPACE"
    fi
    
    cd "$WORKSPACE"
    
    # Clone vLLM if not already present
    if [[ ! -d "vllm" ]]; then
        log_info "Cloning vLLM repository..."
        git clone https://github.com/vllm-project/vllm.git
    else
        log_info "Using existing vLLM repository at $WORKSPACE/vllm"
        log_info "To use latest code: rm -rf $WORKSPACE/vllm and re-run"
    fi
    
    cd vllm
    
    # Build and install vLLM
    log_info "Building vLLM (this may take 30-60 minutes)..."
    VLLM_TARGET_DEVICE=cpu python3 setup.py bdist_wheel --dist-dir=dist --py-limited-api=cp38
    
    log_info "Installing vLLM wheel..."
    uv pip install dist/*.whl
    
    log_success "vLLM built and installed successfully"
}

# Install vLLM from PyPI
install_vllm_from_pypi() {
    log_info "Installing vLLM from PyPI..."
    
    # Check if vLLM is already installed
    if python -c "import vllm" 2>/dev/null; then
        local vllm_version=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)
        log_info "vLLM $vllm_version is already installed"
        log_info "Updating vLLM to latest version from PyPI..."
        uv pip install --upgrade vllm
    else
        uv pip install vllm
    fi
    
    log_success "vLLM installed from PyPI"
}

# Create activation script
create_activation_script() {
    log_info "Creating activation script..."
    
    local arch=$(detect_arch)
    
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
    export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4:${VENV_PATH}/lib/libiomp5.so"
else
    export LD_PRELOAD="/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4"
fi

# Activate virtual environment
source "${VENV_PATH}/bin/activate"

echo "vLLM CPU environment activated"
echo "Python: \$(python --version)"
echo "PyTorch: \$(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'not installed')"
echo "vLLM: \$(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null || echo 'not installed')"
EOF
    
    chmod +x "${VENV_PATH}/activate_vllm.sh"
    log_success "Activation script created at ${VENV_PATH}/activate_vllm.sh"
}

# Cleanup unnecessary packages and caches
# Cleanup unnecessary packages and caches
cleanup_system() {
    echo ""
    echo "=========================================="
    echo "🧹 CLEANUP PHASE STARTED"
    echo "=========================================="
    echo ""
    
    # Get disk usage before cleanup
    local disk_before=$(df -h / | awk 'NR==2 {print $3}')
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
        echo "  - cmake, ninja-build (build systems)"
        echo "  - gcc-14, g++-14, build-essential (compilers)"
        echo "  - binutils, make, autoconf, automake, libtool, pkg-config"
        echo ""
        
        # Remove build-only packages
        apt-get remove -y --purge \
            git \
            wget \
            curl \
            ccache \
            cmake \
            ninja-build \
            build-essential \
            gcc-14 \
            g++-14 \
            cpp-14 \
            binutils \
            make \
            autoconf \
            automake \
            libtool \
            pkg-config \
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
        
        # Show cache size before
        local apt_cache_size=$(du -sh /var/cache/apt 2>/dev/null | awk '{print $1}' || echo "0")
        log_info "APT cache size before: $apt_cache_size"
        
        apt-get autoclean -y
        apt-get clean -y
        rm -rf /var/lib/apt/lists/* 2>/dev/null || true
        rm -rf /var/cache/apt/archives/* 2>/dev/null || true
        rm -rf /var/cache/apt/*.bin 2>/dev/null || true
        rm -rf /var/cache/debconf/* 2>/dev/null || true
        rm -rf /var/lib/dpkg/*-old 2>/dev/null || true
        
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
    rm -rf /root/.cache/huggingface 2>/dev/null || true
    rm -rf /root/.cache/triton 2>/dev/null || true
    rm -rf /root/.cache/torch_extensions 2>/dev/null || true
    rm -rf /root/.cache/ccache 2>/dev/null || true
    rm -rf /root/.cache/* 2>/dev/null || true
    
    log_success "Python caches cleaned (freed ~$cache_size_before)"
    echo ""
    
    # Remove UV package manager caches
    echo "----------------------------------------"
    log_info "STEP 5: Cleaning UV package manager caches"
    echo "----------------------------------------"
    
    if [[ -d /root/.local/share/uv ]]; then
        local uv_size=$(du -sh /root/.local/share/uv 2>/dev/null | awk '{print $1}')
        log_info "UV cache size: $uv_size"
        rm -rf /root/.local/share/uv 2>/dev/null || true
        log_success "UV cache cleaned (freed ~$uv_size)"
    else
        log_info "No UV cache found"
    fi
    echo ""
    
    # Remove temporary files thoroughly
    echo "----------------------------------------"
    log_info "STEP 6: Removing temporary files"
    echo "----------------------------------------"
    
    local tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}' || echo "0")
    log_info "Temp directory size: $tmp_size"
    
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/tmp/* 2>/dev/null || true
    rm -f /tmp/.* 2>/dev/null || true
    
    log_success "Temporary files cleaned (freed ~$tmp_size)"
    echo ""
    
    # Clean Python bytecode in venv
    echo "----------------------------------------"
    log_info "STEP 7: Cleaning Python bytecode in virtual environment"
    echo "----------------------------------------"
    
    local bytecode_count=0
    if [[ -d "${VENV_PATH}" ]]; then
        bytecode_count=$(find "${VENV_PATH}" -name "*.pyc" -o -name "*.pyo" 2>/dev/null | wc -l)
        log_info "Found $bytecode_count bytecode files to remove"
        
        find "${VENV_PATH}" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
        find "${VENV_PATH}" -type f -name "*.pyc" -delete 2>/dev/null || true
        find "${VENV_PATH}" -type f -name "*.pyo" -delete 2>/dev/null || true
        find "${VENV_PATH}" -type f -name "*.whl" -delete 2>/dev/null || true
        
        log_success "Python bytecode cleaned"
    else
        log_info "Virtual environment not found"
    fi
    echo ""
    
    # Clean UV Python installation artifacts
    echo "----------------------------------------"
    log_info "STEP 8: Cleaning UV Python installation artifacts"
    echo "----------------------------------------"
    
    if [[ -d /opt/uv ]]; then
        find /opt/uv -type f -name "*.pyc" -delete 2>/dev/null || true
        find /opt/uv -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
        
        # Remove unused Python versions
        local removed_count=0
        find /opt/uv -name "cpython-*" -type d 2>/dev/null | while read dir; do
            if [[ ! "$dir" =~ ${PYTHON_VERSION} ]]; then
                rm -rf "$dir" 2>/dev/null && ((removed_count++)) || true
            fi
        done
        
        log_success "UV artifacts cleaned"
    else
        log_info "UV installation directory not found"
    fi
    echo ""
    
    # Remove vLLM source directory (ALWAYS if it exists)
    echo "----------------------------------------"
    log_info "STEP 9: Removing vLLM source repository"
    echo "----------------------------------------"
    
    if [[ -d "$WORKSPACE/vllm" ]]; then
        # Get size before deletion
        local vllm_size=$(du -sh "$WORKSPACE/vllm" 2>/dev/null | awk '{print $1}')
        log_info "vLLM source directory found: $WORKSPACE/vllm"
        log_info "Directory size: $vllm_size"
        log_info "Removing entire vLLM source directory..."
        
        # Show what's being removed
        echo "  Contents:"
        ls -lh "$WORKSPACE/vllm" 2>/dev/null | head -10 | awk '{print "    " $9}' || true
        echo ""
        
        # Remove directory
        cd / 2>/dev/null || true  # Move out of directory first
        rm -rf "$WORKSPACE/vllm" 2>/dev/null || true
        
        # Verify deletion
        if [[ ! -d "$WORKSPACE/vllm" ]]; then
            log_success "✅ vLLM source directory removed successfully (freed ~$vllm_size)"
        else
            log_error "❌ Failed to remove vLLM source directory at $WORKSPACE/vllm"
            log_warning "You may need to remove it manually: rm -rf $WORKSPACE/vllm"
        fi
    else
        log_info "vLLM source directory not found (already clean or never cloned)"
    fi
    echo ""
    
    # Clean workspace directory if empty
    if [[ -d "$WORKSPACE" ]] && [[ -z "$(ls -A $WORKSPACE 2>/dev/null)" ]]; then
        log_info "Removing empty workspace directory: $WORKSPACE"
        rmdir "$WORKSPACE" 2>/dev/null || true
    fi
    
    # Clean logs
    echo "----------------------------------------"
    log_info "STEP 10: Cleaning system logs"
    echo "----------------------------------------"
    
    local log_size=$(du -sh /var/log 2>/dev/null | awk '{print $1}' || echo "0")
    log_info "Log directory size: $log_size"
    
    rm -rf /var/log/*.log 2>/dev/null || true
    rm -rf /var/log/apt/* 2>/dev/null || true
    find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
    find /var/log -type f -name "*.old" -delete 2>/dev/null || true
    
    log_success "System logs cleaned"
    echo ""
    
    # Final summary
    echo "=========================================="
    echo "🎉 CLEANUP COMPLETED SUCCESSFULLY"
    echo "=========================================="
    
    # Get disk usage after cleanup
    local disk_after=$(df -h / | awk 'NR==2 {print $3}')
    local disk_available=$(df -h / | awk 'NR==2 {print $4}')
    
    echo ""
    log_info "Disk usage after cleanup: $disk_after"
    log_info "Available disk space: $disk_available"
    echo ""
    
    echo "✅ What was removed:"
    echo "   • Build tools (gcc, g++, cmake, ninja, git, etc.)"
    echo "   • APT package caches"
    echo "   • Python package caches (pip, uv, torch, huggingface)"
    echo "   • Temporary files (/tmp, /var/tmp)"
    echo "   • Python bytecode files (*.pyc, __pycache__)"
    echo "   • vLLM source repository"
    echo "   • System logs"
    echo ""
    
    echo "✅ What was kept:"
    echo "   • vLLM (installed in $VENV_PATH)"
    echo "   • PyTorch 2.8.0 + IPEX 2.8.0"
    echo "   • All runtime dependencies"
    echo "   • libtcmalloc, libnuma (runtime optimizations)"
    echo ""
    
    echo "=========================================="
    echo ""
}

# Print summary
print_summary() {
    local arch=$(detect_arch)
    local install_method
    
    if [[ $BUILD_FROM_SOURCE -eq 1 ]]; then
        install_method="source build"
    else
        install_method="PyPI"
    fi
    
    log_success "vLLM CPU setup completed!"
    echo ""
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "Python Version:    $(${VENV_PATH}/bin/python -V)"
    echo "Install Method:    ${install_method}"
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
    if [[ $BUILD_FROM_SOURCE -eq 1 ]]; then
        echo "  Build:   ${CPU_BUILD_REQUIREMENTS}"
    fi
    if [[ "$arch" == "x86_64" ]]; then
        echo "Verifying Intel Extensions:"
        "${VENV_PATH}"/bin/python -c 'import intel_extension_for_pytorch as ipex; print("IPEX:", ipex.__version__)'
    fi
    echo ""
    echo "Verifying Pytorch installation:"
    "${VENV_PATH}"/bin/python -c 'import torch; print("PyTorch:", torch.__version__)'
    echo ""
    echo "Verifying vLLM installation:"
    "${VENV_PATH}"/bin/python -c 'import vllm; print("vLLM:", vllm.__version__)'
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
    
    # Install vLLM
    if [[ $BUILD_FROM_SOURCE -eq 1 ]]; then
        install_vllm_from_source
    else
        install_vllm_from_pypi
    fi
    
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