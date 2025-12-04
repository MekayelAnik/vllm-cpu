# syntax=docker/dockerfile:1.9
# ============================================================================
# vLLM CPU Docker Image
# ============================================================================
# Minimal runtime image using uv for Python management
#
# This Dockerfile builds runtime images from pre-built PyPI wheels
# with fallback to GitHub releases if PyPI is unavailable.
#
# Uses debian:trixie-slim + uv for smaller image size compared to python base images.
#
# Build args:
#   VLLM_VERSION - vLLM version (e.g., 0.11.2) - REQUIRED
#   PYTHON_VERSION - Python version (e.g., 3.12) - auto-detected if "auto" or empty
#   VARIANT - CPU variant (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
#   USE_GITHUB_RELEASE - Set to "true" to use GitHub release wheels instead of PyPI
#
# Build Optimization Features:
#   - Multi-stage build for Python version detection
#   - BuildKit cache mounts for apt and uv packages
#   - Bytecode compilation for faster container startup
#   - Layer ordering optimized for cache efficiency
# ============================================================================

ARG BASE_IMAGE=debian:trixie-slim

# =============================================================================
# Stage 1: Detect Python version from available wheels on PyPI/GitHub
# =============================================================================
FROM ${BASE_IMAGE} AS python-detector

# Use cache mount for apt to speed up rebuilds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates jq

ARG VLLM_VERSION
ARG PYTHON_VERSION=auto
ARG VARIANT=noavx512
ARG USE_GITHUB_RELEASE=false

# Detect highest available CPython version from PyPI or GitHub releases
# Priority: 1) Explicit PYTHON_VERSION, 2) PyPI wheels, 3) GitHub release wheels, 4) Fallback
RUN set -ex && \
    # Map variant to package name
    case "${VARIANT}" in \
        noavx512) PACKAGE_NAME="vllm-cpu" ;; \
        avx512) PACKAGE_NAME="vllm-cpu-avx512" ;; \
        avx512vnni) PACKAGE_NAME="vllm-cpu-avx512vnni" ;; \
        avx512bf16) PACKAGE_NAME="vllm-cpu-avx512bf16" ;; \
        amxbf16) PACKAGE_NAME="vllm-cpu-amxbf16" ;; \
        *) PACKAGE_NAME="vllm-cpu" ;; \
    esac && \
    \
    if [ -n "${PYTHON_VERSION}" ] && [ "${PYTHON_VERSION}" != "auto" ]; then \
        echo "${PYTHON_VERSION}" > /python_version.txt; \
        echo "Using explicitly specified Python version: ${PYTHON_VERSION}"; \
    else \
        echo "Auto-detecting Python version for ${PACKAGE_NAME}==${VLLM_VERSION}..."; \
        PYTHON_VER=""; \
        \
        # Method 1: Check PyPI for available wheels
        if [ "${USE_GITHUB_RELEASE}" != "true" ]; then \
            echo "Checking PyPI for available wheels..."; \
            PYPI_JSON=$(curl -sfL --max-time 15 "https://pypi.org/pypi/${PACKAGE_NAME}/${VLLM_VERSION}/json" 2>/dev/null || echo ""); \
            if [ -n "${PYPI_JSON}" ]; then \
                # Extract CPython versions from wheel filenames (e.g., cp310, cp311, cp312, cp313)
                # Get highest version available
                PYTHON_VER=$(echo "${PYPI_JSON}" | jq -r '.urls[].filename' 2>/dev/null | \
                    grep -oE 'cp3[0-9]+' | \
                    sed 's/cp3/3./' | \
                    sort -t. -k2 -n -r | \
                    head -1 || echo ""); \
                if [ -n "${PYTHON_VER}" ]; then \
                    echo "Found highest CPython on PyPI: ${PYTHON_VER}"; \
                fi; \
            fi; \
        fi && \
        \
        # Method 2: Check GitHub releases if PyPI failed or was skipped
        if [ -z "${PYTHON_VER}" ]; then \
            echo "Checking GitHub releases for available wheels..."; \
            GH_API="https://api.github.com/repos/MekayelAnik/vllm-cpu/releases/tags/v${VLLM_VERSION}"; \
            GH_JSON=$(curl -sfL --max-time 15 "${GH_API}" 2>/dev/null || echo ""); \
            if [ -n "${GH_JSON}" ]; then \
                # Extract CPython versions from wheel asset names
                PYTHON_VER=$(echo "${GH_JSON}" | jq -r '.assets[].name' 2>/dev/null | \
                    grep -E "^${PACKAGE_NAME//-/_}" | \
                    grep -oE 'cp3[0-9]+' | \
                    sed 's/cp3/3./' | \
                    sort -t. -k2 -n -r | \
                    head -1 || echo ""); \
                if [ -n "${PYTHON_VER}" ]; then \
                    echo "Found highest CPython on GitHub: ${PYTHON_VER}"; \
                fi; \
            fi; \
        fi && \
        \
        # Method 3: Fallback to pyproject.toml requires-python
        if [ -z "${PYTHON_VER}" ]; then \
            echo "No wheels found, checking vLLM pyproject.toml..."; \
            PYPROJECT_URL="https://raw.githubusercontent.com/vllm-project/vllm/v${VLLM_VERSION}/pyproject.toml"; \
            REQUIRES_PYTHON=$(curl -sfL --max-time 15 "${PYPROJECT_URL}" 2>/dev/null | \
                grep -E '^requires-python' | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo ""); \
            if echo "${REQUIRES_PYTHON}" | grep -qE '<[0-9]+\.[0-9]+'; then \
                MAX_PY=$(echo "${REQUIRES_PYTHON}" | grep -oE '<[0-9]+\.[0-9]+' | head -1 | tr -d '<'); \
                MAX_MINOR=$(echo "${MAX_PY}" | cut -d. -f2); \
                PYTHON_VER="3.$((MAX_MINOR - 1))"; \
                echo "Derived from requires-python (<${MAX_PY}): ${PYTHON_VER}"; \
            fi; \
        fi && \
        \
        # Method 4: Ultimate fallback
        if [ -z "${PYTHON_VER}" ]; then \
            PYTHON_VER="3.12"; \
            echo "All detection methods failed, using fallback: ${PYTHON_VER}"; \
        fi && \
        \
        echo "${PYTHON_VER}" > /python_version.txt; \
    fi && \
    echo "=== Final Python version: $(cat /python_version.txt) ==="

# =============================================================================
# Stage 2: Runtime image
# =============================================================================
FROM ${BASE_IMAGE} AS runtime

# Copy detected Python version from previous stage
COPY --from=python-detector /python_version.txt /tmp/python_version.txt

# Build arguments
ARG VLLM_VERSION
ARG PYTHON_VERSION=auto
ARG VARIANT=noavx512
ARG USE_GITHUB_RELEASE=false

# Labels (Note: vllm.python label is set later after Python version detection)
LABEL org.opencontainers.image.title="vLLM CPU (${VARIANT})"
LABEL org.opencontainers.image.description="vLLM CPU inference engine - ${VARIANT} variant"
LABEL org.opencontainers.image.version="${VLLM_VERSION}"
LABEL org.opencontainers.image.vendor="Mekayel Anik"
LABEL org.opencontainers.image.source="https://github.com/MekayelAnik/vllm-cpu"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL vllm.variant="${VARIANT}"

# =============================================================================
# Environment Variables - All vLLM Runtime Configuration
# =============================================================================
# Reference: https://docs.vllm.ai/en/latest/configuration/env_vars/
#
# Users can override any of these at runtime with:
#   docker run -e VLLM_LOGGING_LEVEL=DEBUG ...
# =============================================================================

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# -----------------------------------------------------------------------------
# vLLM Core Settings
# -----------------------------------------------------------------------------
# Target device (cpu for this image)
ENV VLLM_TARGET_DEVICE=cpu

# CPU variant identifier (for reference)
ENV VLLM_CPU_VARIANT=${VARIANT}

# -----------------------------------------------------------------------------
# Cache and Storage Paths
# -----------------------------------------------------------------------------
# Root directory for vLLM cache files
ENV VLLM_CACHE_ROOT=/root/.cache/vllm

# Root directory for vLLM configuration files
ENV VLLM_CONFIG_ROOT=/root/.config/vllm

# Path for storing downloaded assets (models, etc.)
ENV VLLM_ASSETS_CACHE=/root/.cache/vllm/assets

# -----------------------------------------------------------------------------
# CPU Backend Specific Settings (vLLM CPU Optimization)
# Reference: https://docs.vllm.ai/en/stable/getting_started/installation/cpu/
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# CPU Performance Settings (Auto-configured by entrypoint if not set)
# -----------------------------------------------------------------------------
# These settings are dynamically configured at runtime based on available
# resources. Set them explicitly to override auto-detection.
#
# VLLM_CPU_KVCACHE_SPACE: KV cache size in GiB
#   - Auto: 25% of available memory, clamped to 1-64 GiB
#   - Larger values = more concurrent requests and longer contexts
#   - Example: docker run -e VLLM_CPU_KVCACHE_SPACE=16 ...
#
# VLLM_CPU_OMP_THREADS_BIND: CPU core binding for OpenMP threads
#   - Auto: "auto" (NUMA-aware binding by vLLM)
#   - Options: "auto", "nobind", "0-31", "0-15|16-31" (for tensor parallel)
#   - Example: docker run -e VLLM_CPU_OMP_THREADS_BIND=0-15 ...
#
# VLLM_CPU_NUM_OF_RESERVED_CPU: Reserved cores for vLLM frontend
#   - Auto: 1 for <=16 cores, 2 for >16 cores
#   - Example: docker run -e VLLM_CPU_NUM_OF_RESERVED_CPU=2 ...
#
# VLLM_CPU_SGL_KERNEL: Small-batch optimized kernels (x86_64 + AMX only)
#   - Auto: 1 for amxbf16 variant, 0 otherwise
#   - Example: docker run -e VLLM_CPU_SGL_KERNEL=1 ...
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Variant/Platform-Specific Settings
# These are configured at runtime by entrypoint based on variant and platform
# -----------------------------------------------------------------------------
# VLLM_CPU_SGL_KERNEL: Set to 1 only for amxbf16 variant on x86_64
#   - Requires: AMX instruction set, BF16 weights, shapes divisible by 32
#   - Provides better performance for MoE models and small-batch scenarios

# -----------------------------------------------------------------------------
# OpenMP Threading Settings
# -----------------------------------------------------------------------------
# OMP_NUM_THREADS is intentionally NOT set here.
# vLLM manages thread count internally via VLLM_CPU_OMP_THREADS_BIND.
# Only set OMP_NUM_THREADS if using VLLM_CPU_OMP_THREADS_BIND=nobind.
# Example: docker run -e VLLM_CPU_OMP_THREADS_BIND=nobind -e OMP_NUM_THREADS=16 ...

# -----------------------------------------------------------------------------
# Memory Optimization (glibc malloc tuning)
# -----------------------------------------------------------------------------
# Memory allocator tuning - helps prevent memory fragmentation
# Lower values = more aggressive memory trimming
ENV MALLOC_TRIM_THRESHOLD_=100000

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------
# Whether vLLM configures logging (1=yes, 0=no)
ENV VLLM_CONFIGURE_LOGGING=1

# Logging level: DEBUG, INFO, WARNING, ERROR, CRITICAL
ENV VLLM_LOGGING_LEVEL=INFO

# Custom logging configuration file path
ENV VLLM_LOGGING_CONFIG_PATH=""

# Logging output stream
ENV VLLM_LOGGING_STREAM="ext://sys.stdout"

# Prefix for all log messages
ENV VLLM_LOGGING_PREFIX=""

# Colored logging: "auto", "1" (always), "0" (never)
ENV VLLM_LOGGING_COLOR=auto

# Interval in seconds to log statistics (default: 10)
ENV VLLM_LOG_STATS_INTERVAL=10

# -----------------------------------------------------------------------------
# API Server Settings
# -----------------------------------------------------------------------------
# Server host and port (used by entrypoint)
ENV VLLM_HOST="0.0.0.0"
ENV VLLM_PORT="8000"

# API key for authentication (optional)
ENV VLLM_API_KEY=""

# Debug logging for API server responses
ENV VLLM_DEBUG_LOG_API_SERVER_RESPONSE=false

# HTTP keep-alive timeout in seconds
ENV VLLM_HTTP_TIMEOUT_KEEP_ALIVE=5

# Keep server alive even if engine crashes
ENV VLLM_KEEP_ALIVE_ON_ENGINE_DEATH=0

# Development mode (enables additional debug endpoints)
ENV VLLM_SERVER_DEV_MODE=0

# -----------------------------------------------------------------------------
# Model Loading Settings
# -----------------------------------------------------------------------------
# Use ModelScope instead of HuggingFace Hub
ENV VLLM_USE_MODELSCOPE=false

# Allow sequence length greater than model's config.json
ENV VLLM_ALLOW_LONG_MAX_MODEL_LEN=0

# Model redirect path (JSON file mapping repo_id to local folder)
ENV VLLM_MODEL_REDIRECT_PATH=""

# -----------------------------------------------------------------------------
# HuggingFace Settings
# -----------------------------------------------------------------------------
# HuggingFace token for gated models
ENV HF_TOKEN=""
ENV HUGGING_FACE_HUB_TOKEN=""

# HuggingFace cache directory
ENV HF_HOME=/root/.cache/huggingface
ENV TRANSFORMERS_CACHE=/root/.cache/huggingface

# Offline mode
ENV HF_HUB_OFFLINE=""
ENV TRANSFORMERS_OFFLINE=""

# -----------------------------------------------------------------------------
# Multimodal Settings
# -----------------------------------------------------------------------------
# Timeout for fetching images (seconds)
ENV VLLM_IMAGE_FETCH_TIMEOUT=5

# Timeout for fetching videos (seconds)
ENV VLLM_VIDEO_FETCH_TIMEOUT=30

# Timeout for fetching audio (seconds)
ENV VLLM_AUDIO_FETCH_TIMEOUT=10

# Allow HTTP redirects when fetching media
ENV VLLM_MEDIA_URL_ALLOW_REDIRECTS=1

# Max threads for media loading
ENV VLLM_MEDIA_LOADING_THREAD_COUNT=8

# Max audio file size in MB
ENV VLLM_MAX_AUDIO_CLIP_FILESIZE_MB=25

# Video loader backend
ENV VLLM_VIDEO_LOADER_BACKEND=opencv

# Media connector implementation
ENV VLLM_MEDIA_CONNECTOR=http

# Multimodal input cache size in GiB
ENV VLLM_MM_INPUT_CACHE_GIB=4

# -----------------------------------------------------------------------------
# LoRA Settings
# -----------------------------------------------------------------------------
# Allow runtime LoRA adapter loading/unloading
ENV VLLM_ALLOW_RUNTIME_LORA_UPDATING=0

# Local directory for LoRA adapter cache
ENV VLLM_LORA_RESOLVER_CACHE_DIR=""

# -----------------------------------------------------------------------------
# Distributed Settings (for multi-process inference)
# -----------------------------------------------------------------------------
# Internal communication port (NOT the API server port)
ENV VLLM_PORT=""

# Host IP for distributed communication
ENV VLLM_HOST_IP=""

# RPC base path for frontend-backend communication
ENV VLLM_RPC_BASE_PATH=/tmp

# RPC timeout in milliseconds
ENV VLLM_RPC_TIMEOUT=10000

# Multiprocessing method: "fork" or "spawn"
ENV VLLM_WORKER_MULTIPROC_METHOD=fork

# Enable V1 multiprocessing
ENV VLLM_ENABLE_V1_MULTIPROCESSING=1

# Local rank for distributed setting
ENV LOCAL_RANK=0

# -----------------------------------------------------------------------------
# Engine Settings
# -----------------------------------------------------------------------------
# Timeout for each engine iteration in seconds
ENV VLLM_ENGINE_ITERATION_TIMEOUT_S=60

# Ring buffer warning interval
ENV VLLM_RINGBUFFER_WARNING_INTERVAL=60

# Sleep when idle (reduces CPU usage but adds latency)
ENV VLLM_SLEEP_WHEN_IDLE=0

# -----------------------------------------------------------------------------
# Plugin Settings
# -----------------------------------------------------------------------------
# Comma-separated list of plugins to load (empty = all, "" = none)
ENV VLLM_PLUGINS=""

# -----------------------------------------------------------------------------
# Usage Statistics
# -----------------------------------------------------------------------------
# Disable usage stats collection
ENV VLLM_NO_USAGE_STATS=0

# Do not track flag
ENV VLLM_DO_NOT_TRACK=0

# Usage source identifier
ENV VLLM_USAGE_SOURCE=production

# -----------------------------------------------------------------------------
# S3 Storage Settings (for tensorizer model loading)
# -----------------------------------------------------------------------------
ENV S3_ACCESS_KEY_ID=""
ENV S3_SECRET_ACCESS_KEY=""
ENV S3_ENDPOINT_URL=""

# -----------------------------------------------------------------------------
# Debugging and Profiling
# -----------------------------------------------------------------------------
# Trace function calls
ENV VLLM_TRACE_FUNCTION=0

# Debug dump path for fx graphs
ENV VLLM_DEBUG_DUMP_PATH=""

# Pattern match debugging
ENV VLLM_PATTERN_MATCH_DEBUG=""

# Check for NaN values in logits
ENV VLLM_COMPUTE_NANS_IN_LOGITS=0

# -----------------------------------------------------------------------------
# Compilation and Caching
# -----------------------------------------------------------------------------
# Disable compile cache
ENV VLLM_DISABLE_COMPILE_CACHE=""

# Use AOT (Ahead-of-Time) compilation
ENV VLLM_USE_AOT_COMPILE=""

# Force AOT load
ENV VLLM_FORCE_AOT_LOAD=0

# Use bytecode hook
ENV VLLM_USE_BYTECODE_HOOK=1

# Standalone compile (torch >= 2.9)
ENV VLLM_USE_STANDALONE_COMPILE=1

# -----------------------------------------------------------------------------
# Serialization Settings
# -----------------------------------------------------------------------------
# Threshold for msgpack zero-copy serialization
ENV VLLM_MSGPACK_ZERO_COPY_THRESHOLD=256

# Allow insecure pickle serialization
ENV VLLM_ALLOW_INSECURE_SERIALIZATION=0

# -----------------------------------------------------------------------------
# Tool/Function Calling Settings
# -----------------------------------------------------------------------------
# Regex timeout for tool parsing
ENV VLLM_TOOL_PARSE_REGEX_TIMEOUT_SECONDS=1

# Auto retry on tool JSON parsing failure
ENV VLLM_TOOL_JSON_ERROR_AUTOMATIC_RETRY=0

# -----------------------------------------------------------------------------
# Grammar/Constrained Decoding Settings
# -----------------------------------------------------------------------------
# XGrammar cache size in MB
ENV VLLM_XGRAMMAR_CACHE_MB=512

# Use outlines cache for V1
ENV VLLM_V1_USE_OUTLINES_CACHE=0

# -----------------------------------------------------------------------------
# Advanced Settings
# -----------------------------------------------------------------------------
# Disable MLA attention optimizations
ENV VLLM_MLA_DISABLE=0

# Execute model timeout for multiprocessing (TP > 1)
ENV VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=300

# Max chunk bytes for message queue (MB)
ENV VLLM_MQ_MAX_CHUNK_BYTES_MB=16

# V1 output processing chunk size
ENV VLLM_V1_OUTPUT_PROC_CHUNK_SIZE=128

# Install runtime dependencies
# Use cache mount for apt to speed up rebuilds across builds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    # Essential runtime
    libgomp1 \
    libnuma1 \
    numactl \
    # TCMalloc for better memory performance
    libtcmalloc-minimal4 \
    # For health checks and debugging
    curl \
    procps \
    # For API key generation
    openssl \
    # For downloading wheels if needed
    wget \
    # Required for uv to install Python
    ca-certificates \
    # For stripping debug symbols (removed after build)
    binutils

# Install uv - fast Python package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Create directories
RUN mkdir -p /app /models /root/.cache/huggingface /root/.cache/vllm

WORKDIR /app

# Install Python via uv and create virtual environment
# Uses auto-detected version from python-detector stage, or explicit PYTHON_VERSION if provided
RUN set -ex && \
    # Read detected Python version from previous stage
    DETECTED_PY=$(cat /tmp/python_version.txt) && \
    echo "Installing Python ${DETECTED_PY}..." && \
    uv python install "${DETECTED_PY}" && \
    uv venv /app/venv --python "${DETECTED_PY}" && \
    # Store version for later reference
    echo "${DETECTED_PY}" > /app/python_version.txt && \
    echo "Python ${DETECTED_PY} installed successfully"

# Set up environment for uv-managed Python
ENV VIRTUAL_ENV=/app/venv
ENV PATH="/app/venv/bin:$PATH"
# uv optimization settings for container builds
# UV_LINK_MODE=copy required when using cache mounts (different filesystems)
# UV_COMPILE_BYTECODE=1 improves container startup time (pre-compiles .pyc files)
# UV_PYTHON_DOWNLOADS=never ensures we use uv-installed Python, not download new ones
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never

# Install vLLM from PyPI or GitHub release
# Use cache mount for uv to speed up repeated builds and layer changes
# IMPORTANT: Use CPU-only PyTorch index to avoid CUDA bloat
RUN --mount=type=cache,target=/root/.cache/uv \
    set -ex && \
    # Map variant to package name
    case "${VARIANT}" in \
        noavx512) PACKAGE_NAME="vllm-cpu" ;; \
        avx512) PACKAGE_NAME="vllm-cpu-avx512" ;; \
        avx512vnni) PACKAGE_NAME="vllm-cpu-avx512vnni" ;; \
        avx512bf16) PACKAGE_NAME="vllm-cpu-avx512bf16" ;; \
        amxbf16) PACKAGE_NAME="vllm-cpu-amxbf16" ;; \
        *) echo "Unknown variant: ${VARIANT}" && exit 1 ;; \
    esac && \
    echo "Installing ${PACKAGE_NAME} version ${VLLM_VERSION}..." && \
    \
    # Configure index URLs for CPU-only PyTorch
    # - Primary index: PyTorch CPU-only wheels (torch, torchvision, torchaudio)
    # - Extra index: PyPI for vllm-cpu and other packages
    # - unsafe-best-match: Allow uv to pick best version across all indexes
    #   (required so vllm-cpu comes from PyPI while torch comes from PyTorch index)
    PYTORCH_INDEX="https://download.pytorch.org/whl/cpu" && \
    PYPI_INDEX="https://pypi.org/simple" && \
    \
    # Try PyPI first unless explicitly requesting GitHub
    if [ "${USE_GITHUB_RELEASE}" = "true" ]; then \
        echo "Using GitHub release as requested..." && \
        PYPI_SUCCESS=false; \
    else \
        echo "Attempting PyPI installation with CPU-only PyTorch..." && \
        if uv pip install "${PACKAGE_NAME}==${VLLM_VERSION}" \
            --index-url "${PYTORCH_INDEX}" \
            --extra-index-url "${PYPI_INDEX}" \
            --index-strategy unsafe-best-match 2>/dev/null; then \
            echo "Successfully installed from PyPI with CPU-only PyTorch" && \
            PYPI_SUCCESS=true; \
        else \
            echo "PyPI installation failed, falling back to GitHub release..." && \
            PYPI_SUCCESS=false; \
        fi; \
    fi && \
    \
    # Fallback to GitHub release
    if [ "${PYPI_SUCCESS}" = "false" ]; then \
        echo "Downloading from GitHub release..." && \
        # Detect architecture
        ARCH=$(uname -m) && \
        case "${ARCH}" in \
            x86_64) WHEEL_ARCH="x86_64" ;; \
            aarch64) WHEEL_ARCH="aarch64" ;; \
            *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
        esac && \
        # Get detected Python version (stored earlier in /app/python_version.txt)
        DETECTED_PY=$(cat /app/python_version.txt) && \
        PYTHON_TAG="cp${DETECTED_PY//./}" && \
        # Construct wheel filename
        WHEEL_NAME="${PACKAGE_NAME//-/_}-${VLLM_VERSION}-${PYTHON_TAG}-${PYTHON_TAG}-manylinux_2_17_${WHEEL_ARCH}.manylinux2014_${WHEEL_ARCH}.whl" && \
        WHEEL_URL="https://github.com/MekayelAnik/vllm-cpu/releases/download/v${VLLM_VERSION}/${WHEEL_NAME}" && \
        echo "Downloading wheel: ${WHEEL_URL}" && \
        wget -q "${WHEEL_URL}" -O "/tmp/${WHEEL_NAME}" && \
        # Install with CPU-only PyTorch index for dependencies
        uv pip install "/tmp/${WHEEL_NAME}" \
            --index-url "${PYTORCH_INDEX}" \
            --extra-index-url "${PYPI_INDEX}" \
            --index-strategy unsafe-best-match && \
        rm -f "/tmp/${WHEEL_NAME}" && \
        echo "Successfully installed from GitHub release with CPU-only PyTorch"; \
    fi && \
    \
    # Verify installation
    python -c "import vllm; print(f'vLLM version: {vllm.__version__}')" && \
    \
    # ==========================================================================
    # CLEANUP: Minimize image size
    # ==========================================================================
    echo "Cleaning up to minimize image size..." && \
    \
    # 1. Clean uv cache completely (not needed at runtime)
    uv cache clean && \
    \
    # 2. Remove Python bytecode cache (will be regenerated on first run if needed)
    #    Note: We compiled bytecode during install, but remove .pyc source caches
    find /app/venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type f -name "*.py[co]" -delete 2>/dev/null || true && \
    \
    # 3. Remove pip/setuptools cache and metadata not needed at runtime
    rm -rf /app/venv/lib/*/site-packages/pip* 2>/dev/null || true && \
    rm -rf /app/venv/lib/*/site-packages/setuptools* 2>/dev/null || true && \
    rm -rf /app/venv/lib/*/site-packages/wheel* 2>/dev/null || true && \
    rm -rf /app/venv/lib/*/site-packages/_distutils_hack* 2>/dev/null || true && \
    rm -rf /app/venv/lib/*/site-packages/pkg_resources* 2>/dev/null || true && \
    \
    # 4. Remove test directories from installed packages
    find /app/venv -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type d -name "test" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type d -name "testing" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type d -name "*_tests" -exec rm -rf {} + 2>/dev/null || true && \
    \
    # 5. Remove documentation and examples from packages
    find /app/venv -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type d -name "doc" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type d -name "examples" -exec rm -rf {} + 2>/dev/null || true && \
    find /app/venv -type d -name "benchmarks" -exec rm -rf {} + 2>/dev/null || true && \
    \
    # 6. Remove unnecessary files by extension
    find /app/venv -type f -name "*.md" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "*.rst" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "*.txt" ! -name "requirements*.txt" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "LICENSE*" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "COPYING*" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "CHANGELOG*" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "HISTORY*" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "AUTHORS*" -delete 2>/dev/null || true && \
    find /app/venv -type f -name "CONTRIBUTORS*" -delete 2>/dev/null || true && \
    \
    # 7. Remove .dist-info directories except METADATA and RECORD (needed for uninstall info)
    find /app/venv -path "*/.dist-info/*" -type f \
        ! -name "METADATA" ! -name "RECORD" ! -name "WHEEL" ! -name "top_level.txt" ! -name "entry_points.txt" \
        -delete 2>/dev/null || true && \
    \
    # 8. Remove static libraries (.a files) - not needed for runtime
    find /app/venv -type f -name "*.a" -delete 2>/dev/null || true && \
    \
    # 9. Strip debug symbols from shared libraries (significant size reduction)
    find /app/venv -type f -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true && \
    \
    # 10. Also strip system libraries that were installed
    find /root/.local/share/uv -type f -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true && \
    \
    # 11. Clean up uv-managed Python installation
    # Remove static libraries, test files, and documentation from Python itself
    find /root/.local/share/uv/python -type f -name "*.a" -delete 2>/dev/null || true && \
    find /root/.local/share/uv/python -type d -name "test" -exec rm -rf {} + 2>/dev/null || true && \
    find /root/.local/share/uv/python -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true && \
    find /root/.local/share/uv/python -type d -name "idle_test" -exec rm -rf {} + 2>/dev/null || true && \
    find /root/.local/share/uv/python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /root/.local/share/uv/python/*/share/man 2>/dev/null || true && \
    rm -rf /root/.local/share/uv/python/*/share/doc 2>/dev/null || true && \
    \
    # 12. Remove uv binary (not needed at runtime - packages already installed)
    rm -f /usr/local/bin/uv && \
    \
    # 13. Remove binutils (only needed for stripping, not at runtime)
    apt-get purge -y --auto-remove binutils && \
    apt-get clean && \
    \
    # 14. Clean temp files and apt cache
    rm -rf /tmp/* /var/tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/log/* && \
    rm -rf /root/.cache/* && \
    \
    # Report cleanup results
    echo "=== Cleanup complete ===" && \
    echo "Virtual environment size:" && \
    du -sh /app/venv || true && \
    echo "Python installation size:" && \
    du -sh /root/.local/share/uv/python 2>/dev/null || true && \
    echo "Total /app size:" && \
    du -sh /app || true

# Store detected Python version as environment variable for runtime reference
# This allows querying the Python version without running python --version
RUN echo "VLLM_PYTHON_VERSION=$(cat /app/python_version.txt)" >> /etc/environment

# Copy entrypoint and banner scripts
COPY entrypoint.sh /app/entrypoint.sh
COPY banner.sh /app/banner.sh
RUN chmod +x /app/entrypoint.sh /app/banner.sh

# Health check using environment variable for port
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${VLLM_PORT:-8000}/health || exit 1

# Use entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]