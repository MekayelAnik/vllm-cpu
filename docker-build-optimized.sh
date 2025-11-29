#!/usr/bin/env bash
#
# Optimized Docker-based wheel builder for vLLM CPU
# Uses Docker Buildx for efficient multi-platform builds with caching
#
# Usage:
#   ./docker-build-optimized.sh [OPTIONS]
#
# Options:
#   --variant=NAME              Variant to build (vllm-cpu, vllm-cpu-avx512, etc.)
#   --vllm-versions=VERSION     vLLM version(s) to build
#   --python-versions=VERSION   Python version(s) to build
#   --platform=ARCH             Target platform (linux/amd64, linux/arm64, all)
#   --output-dir=PATH           Output directory for wheels (default: ./dist)
#   --cache-from=REF            Cache source (e.g., type=registry,ref=user/app)
#   --cache-to=REF              Cache destination
#   --builder=NAME              Buildx builder name (default: vllm-cpu-builder)
#   --no-cache                  Build without cache
#   --push                      Push image to registry
#   --load                      Load image to local Docker (single platform only)
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
PLATFORM="linux/amd64"
OUTPUT_DIR="$(pwd)/dist"
BUILDER_NAME="vllm-cpu-builder"
CACHE_FROM=""
CACHE_TO=""
NO_CACHE=""
PUSH_IMAGE=0
LOAD_IMAGE=0
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
                PLATFORM="linux/amd64,linux/arm64"
            fi
            shift
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --builder=*)
            BUILDER_NAME="${1#*=}"
            shift
            ;;
        --cache-from=*)
            CACHE_FROM="--cache-from=${1#*=}"
            shift
            ;;
        --cache-to=*)
            CACHE_TO="--cache-to=${1#*=}"
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --push)
            PUSH_IMAGE=1
            shift
            ;;
        --load)
            LOAD_IMAGE=1
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

log_info "Optimized Docker-based vLLM CPU wheel builder"
log_info "=============================================="
log_info "Variant: $VARIANT"
log_info "vLLM versions: ${VLLM_VERSIONS:-latest}"
log_info "Python versions: $PYTHON_VERSIONS"
log_info "Platform: $PLATFORM"
log_info "Output: $OUTPUT_DIR"
log_info "Builder: $BUILDER_NAME"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    log_error "Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    log_error "Docker Buildx is not available"
    log_error "Please install Docker 19.03 or later with Buildx support"
    exit 1
fi

# Create or use existing buildx builder
log_info "Setting up Docker Buildx builder..."
if docker buildx inspect "$BUILDER_NAME" &> /dev/null; then
    log_info "Using existing builder: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
else
    log_info "Creating new builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" \
        --driver docker-container \
        --bootstrap \
        --use
fi

# Install QEMU for cross-platform builds if needed
if [[ "$PLATFORM" == *"arm64"* ]] || [[ $BUILD_ALL_PLATFORMS -eq 1 ]]; then
    log_info "Installing QEMU for multi-platform support..."
    docker run --rm --privileged tonistiigi/binfmt --install all || \
        log_warning "QEMU installation may have failed (might already be installed)"
fi

# Prepare build arguments
BUILD_ARGS="--variant=$VARIANT"
[[ -n "$VLLM_VERSIONS" ]] && BUILD_ARGS="$BUILD_ARGS --vllm-versions=$VLLM_VERSIONS"
BUILD_ARGS="$BUILD_ARGS --python-versions=$PYTHON_VERSIONS"

# Determine output type
OUTPUT_TYPE=""
if [[ $PUSH_IMAGE -eq 1 ]]; then
    OUTPUT_TYPE="--push"
elif [[ $LOAD_IMAGE -eq 1 ]]; then
    if [[ "$PLATFORM" == *","* ]]; then
        log_error "Cannot use --load with multiple platforms"
        log_error "Use --push to push to a registry, or specify a single platform"
        exit 1
    fi
    OUTPUT_TYPE="--load"
fi

# Build the image
log_info "Building Docker image with Buildx..."
log_info "Command: docker buildx build --platform $PLATFORM $OUTPUT_TYPE"

BUILD_CMD=(
    docker buildx build
    --platform "$PLATFORM"
    --tag "vllm-cpu-builder:latest"
    --build-arg "BUILDKIT_INLINE_CACHE=1"
    $NO_CACHE
    $CACHE_FROM
    $CACHE_TO
    $OUTPUT_TYPE
    -f Dockerfile.optimized
    .
)

if ! "${BUILD_CMD[@]}"; then
    log_error "Failed to build Docker image"
    exit 1
fi
log_success "Docker image built successfully"

# If we're not pushing or loading, we need to export the image
if [[ $PUSH_IMAGE -eq 0 ]] && [[ $LOAD_IMAGE -eq 0 ]]; then
    log_info "Loading image to local Docker (required for running build)..."
    # For multi-platform, we need to build for local platform only to load
    LOCAL_PLATFORM="linux/$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')"

    if ! docker buildx build \
        --platform "$LOCAL_PLATFORM" \
        --tag "vllm-cpu-builder:latest" \
        --load \
        $CACHE_FROM \
        -f Dockerfile.optimized \
        .; then
        log_error "Failed to load image for local platform"
        exit 1
    fi
fi

# Run the build in container
log_info ""
log_info "Running wheel build in container..."
log_info "===================================="

# Prepare volume mounts
VOLUME_ARGS="-v $OUTPUT_DIR:/build/dist"

# Add ccache volume for persistent caching across builds
CCACHE_DIR="${OUTPUT_DIR}/../.ccache"
mkdir -p "$CCACHE_DIR"
VOLUME_ARGS="$VOLUME_ARGS -v $(realpath "$CCACHE_DIR"):/build/.ccache"

# Run build
if ! docker run --rm \
    --platform "linux/$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')" \
    $VOLUME_ARGS \
    vllm-cpu-builder:latest \
    ./build_wheels.sh $BUILD_ARGS; then
    log_error "Build failed in container"
    exit 1
fi

# Show built wheels
echo ""
log_success "Build complete! Wheels are in: $OUTPUT_DIR"
log_info "Built wheels:"
if ls "$OUTPUT_DIR"/*.whl &>/dev/null; then
    ls -lh "$OUTPUT_DIR"/*.whl
else
    log_warning "No wheels found in $OUTPUT_DIR"
fi

echo ""
log_info "Build cache saved in: $CCACHE_DIR"
log_info ""
log_info "To test a wheel:"
echo "  docker run --rm -v \$(pwd)/dist:/wheels python:3.12-slim \\"
echo "    sh -c 'pip install /wheels/vllm_cpu-*.whl && python -c \"import vllm; print(vllm.__version__)\"'"
echo ""
log_info "To rebuild with cache (much faster):"
echo "  $0 --variant=$VARIANT --vllm-versions=$VLLM_VERSIONS --python-versions=$PYTHON_VERSIONS"
