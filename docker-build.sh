#!/usr/bin/env bash
#
# Docker-based wheel builder for vLLM CPU
# Builds wheels in isolated Docker containers with cross-platform support
#
# Usage:
#   ./docker-build.sh [OPTIONS]
#
# Options:
#   --variant=NAME              Variant to build (vllm-cpu, vllm-cpu-avx512, etc.)
#   --vllm-versions=VERSION     vLLM version(s) to build
#   --python-versions=VERSION   Python version(s) to build
#   --platform=ARCH             Target platform (linux/amd64, linux/arm64, all)
#   --output-dir=PATH           Output directory for wheels (default: ./dist)
#   --no-cache                  Build Docker image without cache
#   --help                      Show this help

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
VARIANT="vllm-cpu"
VLLM_VERSIONS=""
PYTHON_VERSIONS="3.12"
PLATFORM="linux/amd64"  # Default to x86_64
OUTPUT_DIR="$(pwd)/dist"
NO_CACHE=""
BUILD_ALL_PLATFORMS=0

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Show help
show_help() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# //'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --variant=*)
            VARIANT="${1#*=}"
            shift
            ;;
        --vllm-versions=*)
            VLLM_VERSIONS="${1#*=}"
            shift
            ;;
        --python-versions=*)
            PYTHON_VERSIONS="${1#*=}"
            shift
            ;;
        --platform=*)
            PLATFORM="${1#*=}"
            if [[ "$PLATFORM" == "all" ]]; then
                BUILD_ALL_PLATFORMS=1
            fi
            shift
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

log_info "Docker-based vLLM CPU wheel builder"
log_info "===================================="
log_info "Variant: $VARIANT"
log_info "vLLM versions: ${VLLM_VERSIONS:-latest}"
log_info "Python versions: $PYTHON_VERSIONS"
log_info "Platform: $PLATFORM"
log_info "Output: $OUTPUT_DIR"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    log_error "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Build Docker image
log_info "Building Docker image..."
if ! docker build $NO_CACHE -t vllm-cpu-builder:latest .; then
    log_error "Failed to build Docker image"
    exit 1
fi
log_success "Docker image built: vllm-cpu-builder:latest"

# Function to build for a specific platform
build_for_platform() {
    local platform="$1"
    local platform_name="${platform//\//-}"  # linux/amd64 -> linux-amd64

    log_info ""
    log_info "Building for platform: $platform"
    log_info "=================================="

    # Check if cross-platform build is needed
    local host_arch
    host_arch=$(uname -m)

    if [[ "$platform" == "linux/arm64" && "$host_arch" == "x86_64" ]] || \
       [[ "$platform" == "linux/amd64" && "$host_arch" == "aarch64" ]]; then
        log_info "Cross-platform build detected, ensuring QEMU is available..."

        # Register QEMU handlers if not already done
        if ! docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &>/dev/null; then
            log_warning "Failed to register QEMU handlers (may already be registered)"
        fi
    fi

    # Prepare build arguments
    local build_args="--variant=$VARIANT"
    [[ -n "$VLLM_VERSIONS" ]] && build_args="$build_args --vllm-versions=$VLLM_VERSIONS"
    build_args="$build_args --python-versions=$PYTHON_VERSIONS"

    # Run build in container
    log_info "Running: docker run --platform $platform vllm-cpu-builder $build_args"

    if ! docker run --rm \
        --platform "$platform" \
        -v "$OUTPUT_DIR:/build/dist" \
        vllm-cpu-builder:latest \
        ./build_wheels.sh $build_args; then
        log_error "Build failed for platform: $platform"
        return 1
    fi

    log_success "Build completed for $platform"
    return 0
}

# Build for specified platform(s)
if [[ $BUILD_ALL_PLATFORMS -eq 1 ]]; then
    log_info "Building for all platforms: linux/amd64, linux/arm64"

    build_for_platform "linux/amd64" || exit 1
    build_for_platform "linux/arm64" || exit 1

    log_success "All platforms built successfully!"
else
    build_for_platform "$PLATFORM" || exit 1
fi

# Show built wheels
echo ""
log_success "Build complete! Wheels are in: $OUTPUT_DIR"
log_info "Built wheels:"
ls -lh "$OUTPUT_DIR"/*.whl 2>/dev/null || log_warning "No wheels found in $OUTPUT_DIR"

echo ""
log_info "To test a wheel:"
echo "  docker run --rm -v \$(pwd)/dist:/wheels python:3.12-slim \\"
echo "    sh -c 'pip install /wheels/vllm_cpu-*.whl && python -c \"import vllm; print(vllm.__version__)\"'"
