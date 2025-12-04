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
# IMPORTANT: Filter by current architecture to avoid selecting wheels that don't exist for this platform
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
    # Detect current architecture for wheel filtering
    ARCH=$(uname -m) && \
    case "${ARCH}" in \
        x86_64) WHEEL_ARCH="x86_64" ;; \
        aarch64) WHEEL_ARCH="aarch64" ;; \
        *) WHEEL_ARCH="${ARCH}" ;; \
    esac && \
    echo "Detecting Python version for architecture: ${WHEEL_ARCH}" && \
    \
    if [ -n "${PYTHON_VERSION}" ] && [ "${PYTHON_VERSION}" != "auto" ]; then \
        PYTHON_VER="${PYTHON_VERSION}"; \
        echo "Using explicitly specified Python version: ${PYTHON_VER}"; \
    else \
        echo "Auto-detecting Python version for ${PACKAGE_NAME}==${VLLM_VERSION}..."; \
        PYTHON_VER=""; \
        \
        # Method 1: Check PyPI for available wheels (filtered by architecture)
        if [ "${USE_GITHUB_RELEASE}" != "true" ]; then \
            echo "Checking PyPI for available ${WHEEL_ARCH} wheels..."; \
            PYPI_JSON=$(curl -sfL --max-time 15 "https://pypi.org/pypi/${PACKAGE_NAME}/${VLLM_VERSION}/json" 2>/dev/null || echo ""); \
            if [ -n "${PYPI_JSON}" ]; then \
                # Extract CPython versions from wheel filenames, filtering by architecture
                # e.g., vllm_cpu-0.11.0-cp312-cp312-manylinux_2_17_x86_64.whl
                PYTHON_VER=$(echo "${PYPI_JSON}" | jq -r '.urls[].filename' 2>/dev/null | \
                    grep "_${WHEEL_ARCH}" | \
                    grep -oE 'cp3[0-9]+' | \
                    sed 's/cp3/3./' | \
                    sort -t. -k2 -n -r | \
                    head -1 || echo ""); \
                if [ -n "${PYTHON_VER}" ]; then \
                    echo "Found highest CPython on PyPI for ${WHEEL_ARCH}: ${PYTHON_VER}"; \
                fi; \
            fi; \
        fi && \
        \
        # Method 2: Check GitHub releases if PyPI failed or was skipped (filtered by architecture)
        if [ -z "${PYTHON_VER}" ]; then \
            echo "Checking GitHub releases for available ${WHEEL_ARCH} wheels..."; \
            GH_API="https://api.github.com/repos/MekayelAnik/vllm-cpu/releases/tags/v${VLLM_VERSION}"; \
            GH_JSON=$(curl -sfL --max-time 15 "${GH_API}" 2>/dev/null || echo ""); \
            if [ -n "${GH_JSON}" ]; then \
                # Extract CPython versions from wheel asset names, filtering by architecture
                # Use tr to replace - with _ (POSIX-compatible, no bash-specific ${var//-/_})
                PACKAGE_NAME_UNDERSCORE=$(echo "${PACKAGE_NAME}" | tr '-' '_') && \
                PYTHON_VER=$(echo "${GH_JSON}" | jq -r '.assets[].name' 2>/dev/null | \
                    grep -E "^${PACKAGE_NAME_UNDERSCORE}" | \
                    grep "_${WHEEL_ARCH}" | \
                    grep -oE 'cp3[0-9]+' | \
                    sed 's/cp3/3./' | \
                    sort -t. -k2 -n -r | \
                    head -1 || echo ""); \
                if [ -n "${PYTHON_VER}" ]; then \
                    echo "Found highest CPython on GitHub for ${WHEEL_ARCH}: ${PYTHON_VER}"; \
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
        fi; \
    fi && \
    \
    # Method 5: Verify the vllm-cpu package AND ALL its pinned dependencies have wheels
    # IMPORTANT: We check ALL dependencies with pinned versions (==X.Y.Z) from requires_dist
    # Some packages like xgrammar==0.1.23 may lack wheels for newer Python versions
    # even if the latest version has them.
    # NOTE: This runs for BOTH explicit and auto-detected Python versions
    ORIGINAL_PY="${PYTHON_VER}" && \
    PYTHON_MINOR=$(echo "${PYTHON_VER}" | cut -d. -f2) && \
    echo "Fetching ${PACKAGE_NAME}==${VLLM_VERSION} dependency versions..." && \
    # Get the requires_dist from vllm-cpu to find ALL pinned versions
    VLLM_REQUIRES=$(curl -sfL --max-time 15 "https://pypi.org/pypi/${PACKAGE_NAME}/${VLLM_VERSION}/json" 2>/dev/null | \
        jq -r '.info.requires_dist[]' 2>/dev/null || echo "") && \
    # Extract ALL dependencies with pinned versions (==X.Y.Z format)
    # Format: "dep_name:pinned_version" for each pinned dependency
    # This catches packages like xgrammar, numba, depyf, outlines_core, etc.
    # IMPORTANT: Filter by platform markers - skip deps for other architectures
    # Logic: Skip if marker has ONLY the other platform (no "or" with our platform)
    # Also skip "extra ==" dependencies (optional features not installed by default)
    CRITICAL_DEPS="${PACKAGE_NAME}:${VLLM_VERSION}" && \
    # Determine our target platform for marker matching
    if [ "${WHEEL_ARCH}" = "aarch64" ]; then \
        OUR_PLATFORM="aarch64"; \
        OTHER_PLATFORM="x86_64"; \
    else \
        OUR_PLATFORM="x86_64"; \
        OTHER_PLATFORM="aarch64"; \
    fi && \
    # Process each pinned dependency line
    echo "${VLLM_REQUIRES}" | grep -E '^[a-zA-Z0-9_-]+==' | while read -r DEP_LINE; do \
        # Skip optional "extra ==" dependencies first
        if echo "${DEP_LINE}" | grep -q 'extra =='; then \
            continue; \
        fi && \
        # Check platform markers
        # If no platform_machine marker, include it (applies to all platforms)
        # If has "platform_machine ==" marker, check if our platform is included
        # If has "platform_machine !=" marker, check if our platform is NOT excluded
        if echo "${DEP_LINE}" | grep -q 'platform_machine'; then \
            # Check for exclusion marker (!=)
            if echo "${DEP_LINE}" | grep -q 'platform_machine !='; then \
                # Exclusion marker: skip only if OUR platform is excluded
                if [ "${OUR_PLATFORM}" = "aarch64" ]; then \
                    if echo "${DEP_LINE}" | grep -qE 'platform_machine != "(aarch64|arm64)"'; then \
                        continue; \
                    fi; \
                else \
                    if echo "${DEP_LINE}" | grep -q 'platform_machine != "x86_64"'; then \
                        continue; \
                    fi; \
                fi; \
            else \
                # Inclusion marker (==): include only if our platform is listed
                if [ "${OUR_PLATFORM}" = "aarch64" ]; then \
                    # For aarch64, also accept "arm64" as it's an alias
                    if echo "${DEP_LINE}" | grep -qE "(aarch64|arm64)"; then \
                        : ; \
                    else \
                        continue; \
                    fi; \
                else \
                    # For x86_64
                    if echo "${DEP_LINE}" | grep -q "x86_64"; then \
                        : ; \
                    else \
                        continue; \
                    fi; \
                fi; \
            fi; \
        fi && \
        # Extract dep_name:version
        DEP_ENTRY=$(echo "${DEP_LINE}" | sed 's/^\([a-zA-Z0-9_-]*\)==\([^;, ]*\).*/\1:\2/') && \
        DEP_NAME=$(echo "${DEP_ENTRY}" | cut -d: -f1) && \
        DEP_VER=$(echo "${DEP_ENTRY}" | cut -d: -f2) && \
        if [ -n "${DEP_NAME}" ] && [ -n "${DEP_VER}" ]; then \
            echo "${DEP_NAME}:${DEP_VER}"; \
        fi; \
    done > /tmp/pinned_deps.txt && \
    # Read deps from temp file (needed because while loop runs in subshell)
    while read -r DEP_ENTRY; do \
        if [ -n "${DEP_ENTRY}" ]; then \
            CRITICAL_DEPS="${CRITICAL_DEPS} ${DEP_ENTRY}"; \
        fi; \
    done < /tmp/pinned_deps.txt && \
    rm -f /tmp/pinned_deps.txt && \
    DEP_COUNT=$(echo "${CRITICAL_DEPS}" | wc -w | tr -d ' ') && \
    echo "Found ${DEP_COUNT} pinned dependencies for ${WHEEL_ARCH} to check" && \
    echo "Checking ${WHEEL_ARCH} wheel availability for: ${CRITICAL_DEPS}" && \
    # Fetch wheel lists for all critical dependencies (use | as record separator)
    DEP_WHEELS="" && \
    for DEP_SPEC in ${CRITICAL_DEPS}; do \
        DEP_NAME=$(echo "${DEP_SPEC}" | cut -d: -f1) && \
        DEP_VERSION=$(echo "${DEP_SPEC}" | cut -d: -f2) && \
        if [ -n "${DEP_VERSION}" ]; then \
            DEP_WHEEL_LIST=$(curl -sfL --max-time 10 "https://pypi.org/pypi/${DEP_NAME}/${DEP_VERSION}/json" 2>/dev/null | \
                jq -r '.urls[].filename' 2>/dev/null | tr '\n' ' ') && \
            DEP_WHEELS="${DEP_WHEELS}${DEP_NAME}:${DEP_WHEEL_LIST}|" && \
            echo "  ${DEP_NAME}==${DEP_VERSION}: $(echo "${DEP_WHEEL_LIST}" | wc -w | tr -d ' ') wheels"; \
        fi; \
    done && \
    # Try current version, then fall back: 3.13 -> 3.12 -> 3.11 -> 3.10 -> 3.9
    while [ "${PYTHON_MINOR}" -ge 9 ]; do \
        ALL_DEPS_OK=true && \
        MISSING_DEPS="" && \
        for DEP_SPEC in ${CRITICAL_DEPS}; do \
            DEP_NAME=$(echo "${DEP_SPEC}" | cut -d: -f1) && \
            DEP_WHEEL_LIST=$(echo "${DEP_WHEELS}" | tr '|' '\n' | grep "^${DEP_NAME}:" | cut -d: -f2-) && \
            if [ -n "${DEP_WHEEL_LIST}" ]; then \
                # IMPORTANT: Convert space-separated list to newlines BEFORE grep
                # Otherwise .* regex matches across multiple wheel filenames!
                # NOTE: grep -c always outputs a count (even 0), but returns exit code 1 on no match
                # Use "|| true" to prevent shell exit, NOT "|| echo 0" which corrupts the output
                HAS_WHEEL=$(echo "${DEP_WHEEL_LIST}" | tr ' ' '\n' | grep -c "cp3${PYTHON_MINOR}.*manylinux.*${WHEEL_ARCH}" || true) && \
                # Also check for universal wheels (py3-none-any)
                if [ "${HAS_WHEEL}" = "0" ]; then \
                    HAS_UNIVERSAL=$(echo "${DEP_WHEEL_LIST}" | tr ' ' '\n' | grep -c "py3-none-any" || true) && \
                    if [ "${HAS_UNIVERSAL}" != "0" ]; then \
                        HAS_WHEEL="1"; \
                    fi; \
                fi && \
                if [ "${HAS_WHEEL}" = "0" ]; then \
                    ALL_DEPS_OK=false && \
                    MISSING_DEPS="${MISSING_DEPS} ${DEP_NAME}"; \
                fi; \
            fi; \
        done && \
        if [ "${ALL_DEPS_OK}" = "true" ]; then \
            if [ "3.${PYTHON_MINOR}" != "${ORIGINAL_PY}" ]; then \
                echo "WARNING: Some dependencies lack wheels for Python ${ORIGINAL_PY} on ${WHEEL_ARCH}"; \
                echo "Falling back to Python 3.${PYTHON_MINOR} for dependency compatibility"; \
            else \
                echo "All critical dependencies have ${WHEEL_ARCH} wheels for Python ${PYTHON_VER}"; \
            fi; \
            PYTHON_VER="3.${PYTHON_MINOR}"; \
            break; \
        else \
            echo "Python 3.${PYTHON_MINOR}: Missing ${WHEEL_ARCH} wheels for:${MISSING_DEPS}"; \
        fi; \
        PYTHON_MINOR=$((PYTHON_MINOR - 1)); \
    done && \
    if [ "${PYTHON_MINOR}" -lt 9 ]; then \
        echo "WARNING: No Python version found with all dependency wheels, using 3.9 as fallback"; \
        PYTHON_VER="3.9"; \
    fi && \
    \
    echo "${PYTHON_VER}" > /python_version.txt && \
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

# Install Python via uv and create virtual environment
# Uses auto-detected version from python-detector stage, or explicit PYTHON_VERSION if provided
RUN set -ex && \
    # Read detected Python version from previous stage
    DETECTED_PY=$(cat /tmp/python_version.txt) && \
    echo "Installing Python ${DETECTED_PY}..." && \
    uv python install "${DETECTED_PY}" && \
    uv venv /vllm/venv --python "${DETECTED_PY}" && \
    # Store version for later reference
    echo "${DETECTED_PY}" > /vllm/python_version.txt && \
    echo "Python ${DETECTED_PY} installed successfully"

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
    # Also try .post1, .post2, etc. suffixes if base version fails
    PYPI_SUCCESS=false && \
    PYPI_LAST_ERROR="" && \
    DETECTED_PY=$(cat /vllm/python_version.txt) && \
    echo "Using Python ${DETECTED_PY} for installation..." && \
    if [ "${USE_GITHUB_RELEASE}" = "true" ]; then \
        echo "Using GitHub release as requested..."; \
    else \
        echo "Attempting PyPI installation with CPU-only PyTorch..." && \
        # Try base version first, then .post1, .post2, .post3
        for VERSION_SUFFIX in "" ".post1" ".post2" ".post3"; do \
            INSTALL_VERSION="${VLLM_VERSION}${VERSION_SUFFIX}" && \
            echo "Trying ${PACKAGE_NAME}==${INSTALL_VERSION}..." && \
            if PYPI_LAST_ERROR=$(uv pip install "${PACKAGE_NAME}==${INSTALL_VERSION}" \
                --index-url "${PYTORCH_INDEX}" \
                --extra-index-url "${PYPI_INDEX}" \
                --index-strategy unsafe-best-match 2>&1); then \
                echo "Successfully installed ${PACKAGE_NAME}==${INSTALL_VERSION} from PyPI" && \
                PYPI_SUCCESS=true && \
                break; \
            else \
                echo "Failed: ${INSTALL_VERSION}"; \
            fi; \
        done; \
        if [ "${PYPI_SUCCESS}" = "false" ]; then \
            echo "PyPI installation failed for all version variants." && \
            echo "Last error: ${PYPI_LAST_ERROR}" && \
            echo "Falling back to GitHub release..."; \
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
        # Use tr to remove dots from Python version (POSIX-compatible)
        PYTHON_TAG="cp$(echo "${DETECTED_PY}" | tr -d '.')" && \
        echo "Looking for wheel: Python ${DETECTED_PY} (${PYTHON_TAG}), Arch: ${WHEEL_ARCH}" && \
        # Try base version first, then .post1, .post2, .post3
        WHEEL_DOWNLOADED=false && \
        # Use tr to convert package name (POSIX-compatible)
        PACKAGE_NAME_UNDERSCORE=$(echo "${PACKAGE_NAME}" | tr '-' '_') && \
        for VERSION_SUFFIX in "" ".post1" ".post2" ".post3"; do \
            INSTALL_VERSION="${VLLM_VERSION}${VERSION_SUFFIX}" && \
            WHEEL_NAME="${PACKAGE_NAME_UNDERSCORE}-${INSTALL_VERSION}-${PYTHON_TAG}-${PYTHON_TAG}-manylinux_2_17_${WHEEL_ARCH}.manylinux2014_${WHEEL_ARCH}.whl" && \
            WHEEL_URL="https://github.com/MekayelAnik/vllm-cpu/releases/download/v${VLLM_VERSION}/${WHEEL_NAME}" && \
            echo "Trying wheel: ${WHEEL_URL}" && \
            if wget -q "${WHEEL_URL}" -O "/tmp/${WHEEL_NAME}" 2>/dev/null; then \
                echo "Downloaded: ${WHEEL_NAME}" && \
                WHEEL_DOWNLOADED=true && \
                break; \
            fi; \
        done && \
        if [ "${WHEEL_DOWNLOADED}" = "false" ]; then \
            echo "============================================================" && \
            echo "ERROR: Could not install ${PACKAGE_NAME} ${VLLM_VERSION}" && \
            echo "============================================================" && \
            echo "Python version: ${DETECTED_PY}" && \
            echo "Architecture: ${WHEEL_ARCH}" && \
            echo "" && \
            echo "Tried:" && \
            echo "  1. PyPI: ${PACKAGE_NAME}==${VLLM_VERSION} (and .post1/.post2/.post3)" && \
            echo "  2. GitHub: v${VLLM_VERSION} release wheels" && \
            echo "" && \
            echo "Possible causes:" && \
            echo "  - No wheel exists for Python ${DETECTED_PY} on ${WHEEL_ARCH}" && \
            echo "  - Package not yet published to PyPI" && \
            echo "  - No GitHub release exists for this version" && \
            echo "============================================================" && \
            exit 1; \
        fi && \
        # Install with CPU-only PyTorch index for dependencies
        uv pip install "/tmp/${WHEEL_NAME}" \
            --index-url "${PYTORCH_INDEX}" \
            --extra-index-url "${PYPI_INDEX}" \
            --index-strategy unsafe-best-match && \
        rm -f "/tmp/${WHEEL_NAME}" && \
        echo "Successfully installed from GitHub release with CPU-only PyTorch"; \
    fi && \
    \
    # Verify installation and save version for runtime banner display
    python -c "import vllm; print(f'vLLM version: {vllm.__version__}')" && \
    python -c "import vllm; print(vllm.__version__)" > /vllm/vllm_version.txt && \
    \
    # ==========================================================================
    # CLEANUP: Minimize image size
    # ==========================================================================
    # NOTE: All cleanup commands use "|| true" to prevent build failures
    # from non-critical cleanup operations. The vLLM installation is already
    # verified above, so cleanup failures are acceptable.
    # ==========================================================================
    echo "Cleaning up to minimize image size..." && \
    \
    # 1. Clean uv cache completely (not needed at runtime)
    uv cache clean || true && \
    \
    # 2. Remove pip/wheel (NOT setuptools - needed for distutils-precedence.pth)
    rm -rf /vllm/venv/lib/*/site-packages/pip* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/wheel* || true && \
    \
    # 3. Remove triton (GPU compiler - not needed for CPU inference)
    # Saves ~100-200 MB
    rm -rf /vllm/venv/lib/*/site-packages/triton* || true && \
    \
    # 4. Remove NVIDIA/CUDA stubs from torch (not needed for CPU)
    # These are placeholder libraries for GPU that bloat CPU images
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cuda* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cudnn* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*nvrtc* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*nccl* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cupti* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cufft* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cusparse* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cusolver* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*cublas* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*curand* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/nvidia* || true && \
    \
    # 5. Remove xformers if present (GPU-specific memory optimization)
    rm -rf /vllm/venv/lib/*/site-packages/xformers* || true && \
    \
    # 6. Remove caffe2 (legacy, deprecated since PyTorch 1.8, dead in PyTorch 2.x)
    # vLLM 0.8.5+ uses PyTorch 2.x which doesn't need caffe2
    rm -rf /vllm/venv/lib/*/site-packages/caffe2* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/libcaffe2* || true && \
    \
    # 7. Remove flash_attn (GPU-specific flash attention)
    rm -rf /vllm/venv/lib/*/site-packages/flash_attn* || true && \
    \
    # 8. Remove bitsandbytes (GPU quantization library)
    rm -rf /vllm/venv/lib/*/site-packages/bitsandbytes* || true && \
    \
    # 9. Remove onnx/onnxruntime (not needed for vLLM inference)
    rm -rf /vllm/venv/lib/*/site-packages/onnx* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/onnxruntime* || true && \
    \
    # 10. Remove torch native libraries not needed for CPU (vulkan, mps, metal)
    # NOTE: Keep ALL torch/backends/* Python modules intact!
    # PyTorch imports cuda, cudnn, mps, etc. at startup even on CPU.
    # These provide stub functionality and are required for imports to work.
    # Only remove native libraries (.so files) and codegen files, not Python code.
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*vulkan* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*mps* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/lib/*metal* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/_inductor/codegen/cuda* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/_inductor/codegen/triton* || true && \
    \
    # 11. Remove tensorboard integration (not needed at runtime)
    # NOTE: Keep torch/profiler - it's imported at torch startup!
    rm -rf /vllm/venv/lib/*/site-packages/tensorboard* || true && \
    rm -rf /vllm/venv/lib/*/site-packages/torch/utils/tensorboard* || true && \
    \
    # 12. Remove safetensors rust source files
    rm -rf /vllm/venv/lib/*/site-packages/safetensors/*.rs || true && \
    rm -rf /vllm/venv/lib/*/site-packages/safetensors/src || true && \
    \
    # 13. Remove functorch (legacy compatibility shim, merged into torch.func in PyTorch 2.0)
    # vLLM is inference-only and never uses functional transforms (vmap, grad, etc.)
    rm -rf /vllm/venv/lib/*/site-packages/functorch* || true && \
    \
    # 14. Remove test directories from installed packages
    # IMPORTANT: Skip torch entirely - torch/testing is a required module
    # 15. Remove documentation and examples from packages
    # Combined into single find for efficiency
    find /vllm/venv/lib/*/site-packages -depth -type d \( \
        -name "tests" -o -name "test" -o -name "*_tests" -o \
        -name "docs" -o -name "doc" -o -name "examples" -o -name "benchmarks" \
        \) ! -path "*/torch/*" -exec rm -rf {} \; 2>/dev/null || true && \
    \
    # 16. Remove unnecessary files by extension (consolidated find)
    find /vllm/venv -type f \( \
        -name "*.md" -o -name "*.rst" -o -name "*.pyi" -o \
        -name "LICENSE*" -o -name "COPYING*" -o -name "CHANGELOG*" -o \
        -name "HISTORY*" -o -name "AUTHORS*" -o -name "CONTRIBUTORS*" -o \
        -name "*.h" -o -name "*.hpp" -o -name "*.a" \
        \) -delete 2>/dev/null || true && \
    find /vllm/venv -type f -name "*.txt" ! -name "requirements*.txt" ! -name "top_level.txt" -delete 2>/dev/null || true && \
    \
    # 17. Remove .dist-info files except essential ones
    find /vllm/venv -path "*/.dist-info/*" -type f \
        ! -name "METADATA" ! -name "RECORD" ! -name "WHEEL" ! -name "top_level.txt" ! -name "entry_points.txt" \
        -delete 2>/dev/null || true && \
    \
    # 18. Remove __pycache__ and include directories (consolidated)
    find /vllm/venv -depth -type d \( -name "__pycache__" -o -name "include" \) -exec rm -rf {} \; 2>/dev/null || true && \
    \
    # 19. Strip debug symbols from shared libraries (significant size reduction)
    find /vllm/venv /root/.local/share/uv -type f -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true && \
    \
    # 20. Clean up uv-managed Python installation
    # Remove static libs, test dirs, and unused stdlib modules (tkinter, idle - not needed for headless inference)
    find /root/.local/share/uv/python -type f -name "*.a" -delete 2>/dev/null || true && \
    find /root/.local/share/uv/python -depth -type d \( \
        -name "test" -o -name "tests" -o -name "idle_test" -o -name "__pycache__" -o \
        -name "tkinter" -o -name "idlelib" -o -name "turtledemo" \
        \) -exec rm -rf {} \; 2>/dev/null || true && \
    rm -rf /root/.local/share/uv/python/*/share/man /root/.local/share/uv/python/*/share/doc 2>/dev/null || true && \
    rm -rf /root/.local/share/uv/python/*/lib/*/lib-tk 2>/dev/null || true && \
    rm -rf /root/.local/share/uv/python/*/lib/*/tkinter 2>/dev/null || true && \
    \
    # 21. Remove locale data (keep only en_US)
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} \; 2>/dev/null || true && \
    rm -rf /usr/share/doc /usr/share/man /usr/share/info 2>/dev/null || true && \
    \
    # 22. Remove uv binary and wget (not needed at runtime)
    rm -f /usr/local/bin/uv && \
    apt-get purge -y --auto-remove binutils wget && \
    apt-get clean && \
    \
    # 23. Clean temp files and apt cache
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/* /var/log/* /root/.cache/* && \
    \
    # 24. Report cleanup results
    echo "=== Cleanup complete ===" && \
    du -sh /vllm/venv || true && \
    du -sh /root/.local/share/uv/python 2>/dev/null || true && \
    du -sh /vllm || true

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