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
# Runtime args (set via -e):
#   PUID - User ID to run as (unset = root)
#   PGID - Group ID to run as (unset = root)
#   DATA_DIR - Data directory for models/cache (default: /data)
#   VLLM_SERVER_HOST - Server bind address (default: 0.0.0.0)
#   VLLM_SERVER_PORT - Server port (default: 8000)
#
# RECOMMENDED DOCKER RUN OPTIONS for optimal performance:
#   docker run \
#     --cap-add SYS_NICE \
#     --security-opt seccomp=unconfined \
#     --shm-size 4g \
#     -v /path/to/models:/data/models \
#     -e VLLM_CPU_KVCACHE_SPACE=8 \
#     -e VLLM_MODEL=meta-llama/Llama-3.2-1B-Instruct \
#     -p 8000:8000 \
#     mekayelanik/vllm-cpu:noavx512-latest
#
#   --cap-add SYS_NICE: Enables NUMA syscalls for memory binding
#   --security-opt seccomp=unconfined: Allows get_mempolicy for NUMA optimization
#   --shm-size 4g: Shared memory for tensor operations (increase for larger models)
#
# Reference: https://docs.vllm.ai/en/latest/getting_started/installation/cpu/
#
# Build Optimization Features:
#   - Multi-stage build for Python version detection
#   - BuildKit cache mounts for apt and uv packages
#   - Bytecode compilation for faster container startup
#   - Layer ordering optimized for cache efficiency
#   - Modular scripts for maintainability (detect_python_version.sh, setup_vllm.sh, cleanup.sh)
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

# Copy and run the Python version detection script
# This script handles all the complex logic for detecting the optimal Python version:
# 1. Checks PyPI for available wheels (filtered by architecture)
# 2. Falls back to GitHub releases if PyPI unavailable
# 3. Falls back to pyproject.toml requires-python
# 4. Verifies ALL pinned dependencies have wheels for the selected version
# 5. Falls back to lower Python versions if dependencies lack wheels
COPY detect_python_version.sh /detect_python_version.sh
RUN chmod +x /detect_python_version.sh && \
    # Map variant to package name
    case "${VARIANT}" in \
        noavx512) PACKAGE_NAME="vllm-cpu" ;; \
        avx512) PACKAGE_NAME="vllm-cpu-avx512" ;; \
        avx512vnni) PACKAGE_NAME="vllm-cpu-avx512vnni" ;; \
        avx512bf16) PACKAGE_NAME="vllm-cpu-avx512bf16" ;; \
        amxbf16) PACKAGE_NAME="vllm-cpu-amxbf16" ;; \
        *) PACKAGE_NAME="vllm-cpu" ;; \
    esac && \
    /detect_python_version.sh "${PACKAGE_NAME}" "${VLLM_VERSION}" "${PYTHON_VERSION}" "${USE_GITHUB_RELEASE}"

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

# =============================================================================
# OCI Image Labels (https://github.com/opencontainers/image-spec/blob/main/annotations.md)
# =============================================================================
# Standard OCI annotations for container image metadata
LABEL org.opencontainers.image.title="vLLM CPU (${VARIANT})" \
      org.opencontainers.image.description="Run large language models on CPU without a GPU. This ${VARIANT} build provides an OpenAI-compatible API server for local LLM inference." \
      org.opencontainers.image.version="${VLLM_VERSION}" \
      org.opencontainers.image.vendor="Md. Mekayel Anik" \
      org.opencontainers.image.authors="Md. Mekayel Anik <mekayel.anik@gmail.com>" \
      org.opencontainers.image.url="https://github.com/MekayelAnik/vllm-cpu" \
      org.opencontainers.image.source="https://github.com/MekayelAnik/vllm-cpu" \
      org.opencontainers.image.documentation="https://github.com/MekayelAnik/vllm-cpu#readme" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.base.name="docker.io/library/debian:trixie-slim" \
      org.opencontainers.image.ref.name="${VARIANT}-${VLLM_VERSION}" \
      # Custom labels for vLLM-specific metadata
      vllm.variant="${VARIANT}" \
      vllm.version="${VLLM_VERSION}" \
      vllm.upstream.url="https://github.com/vllm-project/vllm"

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
# User/Group Configuration (for running as non-root)
# -----------------------------------------------------------------------------
# PUID/PGID - User/Group ID for the vllm process
# If set, container runs as specified user; if unset, runs as root
# Set these to match your host user to avoid permission issues with mounted volumes
# Example: docker run -e PUID=1000 -e PGID=1000 ...
ENV PUID=""
ENV PGID=""

# Data directory (models, cache, config) - can be mounted as volume
# This is the primary directory users should mount for persistent storage
ENV DATA_DIR=/data

# Root directory for vLLM cache files
ENV VLLM_CACHE_ROOT=/data/cache/vllm

# Root directory for vLLM configuration files
ENV VLLM_CONFIG_ROOT=/data/config/vllm

# Path for storing downloaded assets (models, etc.)
ENV VLLM_ASSETS_CACHE=/data/cache/vllm/assets

# -----------------------------------------------------------------------------
# CPU Backend Specific Settings (vLLM CPU Optimization)
# Reference: https://docs.vllm.ai/en/latest/getting_started/installation/cpu/
# Reference: https://docs.vllm.ai/en/latest/configuration/env_vars/
# -----------------------------------------------------------------------------
# These settings are dynamically configured at runtime by the entrypoint script
# based on available resources. Set them explicitly to override auto-detection.
#
# VLLM_CPU_KVCACHE_SPACE: KV cache size in GiB
#   - Auto: 25% of available memory, clamped to 1-64 GiB
#   - For multi-NUMA: calculated per-node to avoid cross-NUMA access
#   - Larger values = more concurrent requests and longer contexts
#   - IMPORTANT: Ensure KV cache + model weights fit in single NUMA node
#   - Example: docker run -e VLLM_CPU_KVCACHE_SPACE=16 ...
#
# VLLM_CPU_OMP_THREADS_BIND: CPU core binding for OpenMP threads
#   - Auto: "auto" (NUMA-aware binding by vLLM)
#   - Options: "auto", "nobind", "0-31", "0-15|16-31" (for tensor parallel)
#   - For TP/PP: cores for different ranks separated by '|'
#   - Example: docker run -e VLLM_CPU_OMP_THREADS_BIND=0-15 ...
#
# VLLM_CPU_NUM_OF_RESERVED_CPU: Reserved cores for vLLM frontend
#   - Auto: 1 for <=16 cores, 2 for 17-32 cores, 4 for >32 cores
#   - These cores handle async tasks, tokenization, and API requests
#   - Example: docker run -e VLLM_CPU_NUM_OF_RESERVED_CPU=2 ...
#
# VLLM_CPU_SGL_KERNEL: SGL kernels optimized for small batch sizes
#   - Auto: 1 for AMX-enabled CPUs, 0 otherwise
#   - Best for: Sapphire Rapids+, BF16 weights, shapes divisible by 32
#   - Example: docker run -e VLLM_CPU_SGL_KERNEL=1 ...
#
# VLLM_CPU_MOE_PREPACK: Enable MoE layer prepacking optimization
#   - Auto: 1 (enabled) on supported CPUs
#   - Passed to ipex.llm.modules.GatedMLPMOE
#   - Set to 0 on unsupported CPUs if you encounter issues
#   - Example: docker run -e VLLM_CPU_MOE_PREPACK=0 ...
# -----------------------------------------------------------------------------

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
# API Server Settings (Docker entrypoint configuration)
# -----------------------------------------------------------------------------
# Server host and port (used by our entrypoint script)
# Note: These are our custom env vars for the API server, distinct from
# vLLM's internal VLLM_PORT/VLLM_HOST_IP used for distributed communication.
ENV VLLM_SERVER_HOST="0.0.0.0"
ENV VLLM_SERVER_PORT="8000"

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

# HuggingFace cache directory (inside DATA_DIR for unified storage)
ENV HF_HOME=/data/models
ENV TRANSFORMERS_CACHE=/data/models

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
    binutils \
    # For PUID/PGID user switching at runtime
    gosu

# Install uv - fast Python package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Create directories for app and data
# /data is the main volume mount point for persistent storage
# Ownership will be set at runtime based on PUID/PGID
RUN mkdir -p /vllm /data/models /data/cache/vllm /data/config/vllm

WORKDIR /vllm

# Set up environment for uv-managed Python
ENV VIRTUAL_ENV=/vllm/venv
ENV PATH="/vllm/venv/bin:$PATH"
# uv optimization settings for container builds
# UV_LINK_MODE=copy required when using cache mounts (different filesystems)
# UV_COMPILE_BYTECODE=1 improves container startup time (pre-compiles .pyc files)
# UV_PYTHON_DOWNLOADS=never ensures we use uv-installed Python, not download new ones
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never

# Copy and run the setup script (Python + vLLM installation)
# This script handles:
# 1. Installing Python via uv
# 2. Creating virtual environment
# 3. Installing vLLM from PyPI (with fallback to GitHub releases)
COPY setup_vllm.sh /setup_vllm.sh
RUN --mount=type=cache,target=/root/.cache/uv \
    chmod +x /setup_vllm.sh && \
    /setup_vllm.sh "${VARIANT}" "${VLLM_VERSION}" "${USE_GITHUB_RELEASE}"

# Copy and run the cleanup script (image optimization)
# This script handles all cleanup operations to minimize image size:
# - Removes GPU packages (triton, xformers, flash_attn)
# - Removes CUDA/NVIDIA libraries from PyTorch
# - Removes test directories and documentation
# - Strips debug symbols from shared libraries
# - Cleans up temporary files and caches
COPY cleanup.sh /cleanup.sh
RUN chmod +x /cleanup.sh && /cleanup.sh

# Store detected Python version as environment variable for runtime reference
# This allows querying the Python version without running python --version
RUN echo "VLLM_PYTHON_VERSION=$(cat /vllm/python_version.txt)" >> /etc/environment

# Copy entrypoint and banner scripts
COPY entrypoint.sh /vllm/entrypoint.sh
COPY banner.sh /vllm/banner.sh
RUN chmod +x /vllm/entrypoint.sh /vllm/banner.sh

# Health check using environment variable for port
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${VLLM_SERVER_PORT:-8000}/health || exit 1

# Use entrypoint script
ENTRYPOINT ["/vllm/entrypoint.sh"]
