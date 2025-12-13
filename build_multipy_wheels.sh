#!/usr/bin/env bash
#
# Multi-Python Version Wheel Builder for vLLM CPU
#
# This script builds vLLM CPU wheels for Python 3.9, 3.10, 3.11, 3.12, and 3.13
# using cibuildwheel in a Docker container with manylinux support.
#
# Usage:
#   ./build_multipy_wheels.sh [OPTIONS]
#
# Options:
#   --variant=NAME           Variant to build (noavx512, avx512, avx512vnni, avx512bf16, amxbf16, all)
#   --vllm-version=VERSION   vLLM version to build (default: latest from git)
#   --max-jobs=N             Parallel build jobs (default: CPU count)
#   --help                   Show this help

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
VARIANT="noavx512"
VLLM_VERSION=""
MAX_JOBS=$(nproc)
WORKSPACE="/mnt/PYTHON-AI-PROJECTS/vllm-cpu"
OUTPUT_DIR="$WORKSPACE/dist"

# Logging functions
log_info() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') [$$] ${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') [$$] ${GREEN}[SUCCESS]${NC} $*" >&2; }
log_error() { echo -e "$(date +'%Y-%m-%d %H:%M:%S') [$$] ${RED}[ERROR]${NC} $*" >&2; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --variant=*)
            VARIANT="${1#*=}"
            shift
            ;;
        --vllm-version=*)
            VLLM_VERSION="${1#*=}"
            shift
            ;;
        --max-jobs=*)
            MAX_JOBS="${1#*=}"
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

log_info "Building vLLM CPU wheels for Python 3.9-3.13"
log_info "Variant: $VARIANT"
log_info "Output: $OUTPUT_DIR"

# Install cibuildwheel if not available
if ! command -v cibuildwheel &> /dev/null; then
    log_info "Installing cibuildwheel..."
    pip install cibuildwheel
fi

# Set environment variables for cibuildwheel
export CIBW_BUILD="cp39-* cp310-* cp311-* cp312-* cp313-*"
export CIBW_SKIP="*-musllinux_*"  # Skip musl-based Linux (Alpine)
export CIBW_PLATFORM="linux"
export CIBW_MANYLINUX_X86_64_IMAGE="manylinux_2_28"
export CIBW_MANYLINUX_AARCH64_IMAGE="manylinux_2_28"
export CIBW_BUILD_VERBOSITY=1
export CIBW_ENVIRONMENT="MAX_JOBS=$MAX_JOBS VLLM_TARGET_DEVICE=cpu"

# Set variant-specific flags
case "$VARIANT" in
    noavx512)
        export CIBW_ENVIRONMENT="$CIBW_ENVIRONMENT VLLM_CPU_AVX512VNNI=OFF VLLM_CPU_AVX512BF16=OFF VLLM_CPU_AMX=OFF"
        ;;
    avx512)
        export CIBW_ENVIRONMENT="$CIBW_ENVIRONMENT VLLM_CPU_AVX512VNNI=OFF VLLM_CPU_AVX512BF16=OFF VLLM_CPU_AMX=OFF"
        ;;
    avx512vnni)
        export CIBW_ENVIRONMENT="$CIBW_ENVIRONMENT VLLM_CPU_AVX512BF16=OFF VLLM_CPU_AMX=OFF"
        ;;
    avx512bf16)
        export CIBW_ENVIRONMENT="$CIBW_ENVIRONMENT VLLM_CPU_AMX=OFF"
        ;;
    amxbf16)
        # All features enabled
        ;;
    *)
        log_error "Unknown variant: $VARIANT"
        exit 1
        ;;
esac

# Clone or update vLLM
if [[ ! -d "$WORKSPACE/build/vllm" ]]; then
    log_info "Cloning vLLM repository..."
    mkdir -p "$WORKSPACE/build"
    git clone https://github.com/vllm-project/vllm.git "$WORKSPACE/build/vllm"
fi

cd "$WORKSPACE/build/vllm"

# Checkout specific version if requested
if [[ -n "$VLLM_VERSION" ]]; then
    log_info "Checking out version: $VLLM_VERSION"
    git fetch --tags
    if git checkout "v$VLLM_VERSION" 2>/dev/null || git checkout "$VLLM_VERSION" 2>/dev/null; then
        log_success "Checked out version $VLLM_VERSION"
    else
        log_error "Version $VLLM_VERSION not found"
        exit 1
    fi
fi

# Build wheels using cibuildwheel
log_info "Building wheels for all Python versions..."
cibuildwheel --output-dir "$OUTPUT_DIR"

log_success "Wheels built successfully!"

# Clean up build artifacts immediately after build
log_info "Cleaning up build artifacts..."

# 1. Remove CMake build artifacts
if [[ -d "$WORKSPACE/build/vllm/build" ]]; then
    log_info "Removing CMake build artifacts..."
    rm -rf "$WORKSPACE/build/vllm/build"
fi

# 2. Remove .egg-info directories
if compgen -G "$WORKSPACE/build/vllm/*.egg-info" > /dev/null 2>&1; then
    log_info "Removing .egg-info directories..."
    rm -rf "$WORKSPACE/build/vllm"/*.egg-info
fi

# 3. Remove Python cache
if [[ -d "$WORKSPACE/build/vllm/__pycache__" ]]; then
    log_info "Removing Python cache..."
    find "$WORKSPACE/build/vllm/" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$WORKSPACE/build/vllm/" -type f -name "*.pyc" -delete 2>/dev/null || true
fi

# 4. Reset git repository
if [[ -d "$WORKSPACE/build/vllm/.git" ]]; then
    log_info "Resetting git repository..."
    (cd "$WORKSPACE/build/vllm" && git reset --hard HEAD >/dev/null 2>&1 && git clean -fd >/dev/null 2>&1) || true
fi

# 5. Clean uv cache
if command -v uv &>/dev/null; then
    log_info "Cleaning uv cache..."
    uv cache clean 2>/dev/null || log_error "Failed to clean uv cache (continuing anyway)"
fi

# 6. Clean pip cache
if [[ -d "$HOME/.cache/pip" ]]; then
    log_info "Cleaning pip cache..."
    rm -rf "$HOME/.cache/pip"/* 2>/dev/null || log_error "Failed to clean pip cache (continuing anyway)"
fi

# 7. Remove temporary build files from /tmp
log_info "Cleaning temporary build files..."
find /tmp -maxdepth 1 \( \
    -name "pip-*" -o \
    -name "tmp*vllm*" -o \
    -name "tmp*wheel*" -o \
    -name "tmp*build*" -o \
    -name ".tmp*" \
\) -mmin +5 -exec rm -rf {} + 2>/dev/null || true

# 8. Clean uv data directory
if [[ -d "$HOME/.local/share/uv" ]]; then
    log_info "Cleaning uv data directory..."
    rm -rf "$HOME/.local/share/uv"/* 2>/dev/null || log_error "Failed to clean uv data (continuing anyway)"
fi

log_success "Cleanup complete!"

log_info "Output directory: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.whl
