# syntax=docker/dockerfile:1.9
# vLLM CPU Docker Image - Minimal runtime using uv for Python management
#
# Build args:
#   VLLM_VERSION - vLLM version (e.g., 0.11.2) - REQUIRED
#   PYTHON_VERSION - Python version (e.g., 3.12) - auto-detected if "auto" or empty
#   VARIANT - CPU variant (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
#   USE_GITHUB_RELEASE - Set to "true" to use GitHub release wheels instead of PyPI
#
# Runtime args:
#   PUID/PGID - User/Group ID to run as (unset = root)
#   DATA_DIR - Data directory for models/cache (default: /data)
#   VLLM_SERVER_HOST/PORT - Server bind address and port
#
# Recommended run options:
#   docker run --cap-add SYS_NICE --security-opt seccomp=unconfined --shm-size 4g ...

ARG BASE_IMAGE=debian:trixie-slim

# Stage 1: Detect Python version from available wheels
FROM ${BASE_IMAGE} AS python-detector

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates jq

ARG VLLM_VERSION
ARG PYTHON_VERSION=auto
ARG VARIANT=noavx512
ARG USE_GITHUB_RELEASE=false

COPY detect_python_version.sh /detect_python_version.sh
RUN chmod +x /detect_python_version.sh && \
    case "${VARIANT}" in \
        noavx512) PACKAGE_NAME="vllm-cpu" ;; \
        avx512) PACKAGE_NAME="vllm-cpu-avx512" ;; \
        avx512vnni) PACKAGE_NAME="vllm-cpu-avx512vnni" ;; \
        avx512bf16) PACKAGE_NAME="vllm-cpu-avx512bf16" ;; \
        amxbf16) PACKAGE_NAME="vllm-cpu-amxbf16" ;; \
        *) PACKAGE_NAME="vllm-cpu" ;; \
    esac && \
    /detect_python_version.sh "${PACKAGE_NAME}" "${VLLM_VERSION}" "${PYTHON_VERSION}" "${USE_GITHUB_RELEASE}"

# Stage 2: Runtime image
FROM ${BASE_IMAGE} AS runtime

COPY --from=python-detector /python_version.txt /tmp/python_version.txt

ARG VLLM_VERSION
ARG PYTHON_VERSION=auto
ARG VARIANT=noavx512
ARG USE_GITHUB_RELEASE=false

# OCI Image Labels
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
      vllm.variant="${VARIANT}" \
      vllm.version="${VLLM_VERSION}" \
      vllm.upstream.url="https://github.com/vllm-project/vllm"

# Python settings
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# vLLM Core Settings
ENV VLLM_TARGET_DEVICE=cpu
ENV VLLM_CPU_VARIANT=${VARIANT}

# User/Group Configuration
ENV PUID=""
ENV PGID=""

# Data directories
ENV DATA_DIR=/data
ENV VLLM_CACHE_ROOT=/data/cache/vllm
ENV VLLM_CONFIG_ROOT=/data/config/vllm
ENV VLLM_ASSETS_CACHE=/data/cache/vllm/assets

# Memory optimization
ENV MALLOC_TRIM_THRESHOLD_=100000

# Logging
ENV VLLM_CONFIGURE_LOGGING=1
ENV VLLM_LOGGING_LEVEL=INFO
ENV VLLM_LOGGING_CONFIG_PATH=""
ENV VLLM_LOGGING_STREAM="ext://sys.stdout"
ENV VLLM_LOGGING_PREFIX=""
ENV VLLM_LOGGING_COLOR=auto
ENV VLLM_LOG_STATS_INTERVAL=10

# API Server
ENV VLLM_SERVER_HOST="0.0.0.0"
ENV VLLM_SERVER_PORT="8000"
ENV VLLM_API_KEY=""
ENV VLLM_DEBUG_LOG_API_SERVER_RESPONSE=false
ENV VLLM_HTTP_TIMEOUT_KEEP_ALIVE=5
ENV VLLM_KEEP_ALIVE_ON_ENGINE_DEATH=0
ENV VLLM_SERVER_DEV_MODE=0

# Model Loading
ENV VLLM_MODEL=""
ENV VLLM_TOKENIZER=""
ENV VLLM_USE_MODELSCOPE=false
ENV VLLM_ALLOW_LONG_MAX_MODEL_LEN=0
ENV VLLM_MODEL_REDIRECT_PATH=""

# HuggingFace
ENV HF_TOKEN=""
ENV HF_HOME=/data/models
ENV TRANSFORMERS_CACHE=/data/models
ENV HF_HUB_OFFLINE=""
ENV TRANSFORMERS_OFFLINE=""

# Multimodal
ENV VLLM_IMAGE_FETCH_TIMEOUT=5
ENV VLLM_VIDEO_FETCH_TIMEOUT=30
ENV VLLM_AUDIO_FETCH_TIMEOUT=10
ENV VLLM_MEDIA_URL_ALLOW_REDIRECTS=1
ENV VLLM_MEDIA_LOADING_THREAD_COUNT=8
ENV VLLM_MAX_AUDIO_CLIP_FILESIZE_MB=25
ENV VLLM_VIDEO_LOADER_BACKEND=opencv
ENV VLLM_MEDIA_CONNECTOR=http
ENV VLLM_MM_INPUT_CACHE_GIB=4

# LoRA
ENV VLLM_ALLOW_RUNTIME_LORA_UPDATING=0
ENV VLLM_LORA_RESOLVER_CACHE_DIR=""

# Distributed
ENV VLLM_PORT=""
ENV VLLM_HOST_IP=""
ENV VLLM_RPC_BASE_PATH=/tmp
ENV VLLM_RPC_TIMEOUT=10000
ENV VLLM_WORKER_MULTIPROC_METHOD=fork
ENV VLLM_ENABLE_V1_MULTIPROCESSING=1
ENV LOCAL_RANK=0

# Engine
ENV VLLM_ENGINE_ITERATION_TIMEOUT_S=60
ENV VLLM_RINGBUFFER_WARNING_INTERVAL=60
ENV VLLM_SLEEP_WHEN_IDLE=0

# Plugins
ENV VLLM_PLUGINS=""

# Usage Statistics
ENV VLLM_NO_USAGE_STATS=0
ENV VLLM_DO_NOT_TRACK=0
ENV VLLM_USAGE_SOURCE=production

# S3 Storage
ENV S3_ACCESS_KEY_ID=""
ENV S3_SECRET_ACCESS_KEY=""
ENV S3_ENDPOINT_URL=""

# Debugging
ENV VLLM_TRACE_FUNCTION=0
ENV VLLM_DEBUG_DUMP_PATH=""
ENV VLLM_PATTERN_MATCH_DEBUG=""
ENV VLLM_COMPUTE_NANS_IN_LOGITS=0

# Compilation
ENV VLLM_DISABLE_COMPILE_CACHE=""
ENV VLLM_USE_AOT_COMPILE=""
ENV VLLM_FORCE_AOT_LOAD=0
ENV VLLM_USE_BYTECODE_HOOK=1
ENV VLLM_USE_STANDALONE_COMPILE=1

# Serialization
ENV VLLM_MSGPACK_ZERO_COPY_THRESHOLD=256
ENV VLLM_ALLOW_INSECURE_SERIALIZATION=0

# Tool/Function Calling
ENV VLLM_TOOL_PARSE_REGEX_TIMEOUT_SECONDS=1
ENV VLLM_TOOL_JSON_ERROR_AUTOMATIC_RETRY=0

# Grammar/Constrained Decoding
ENV VLLM_XGRAMMAR_CACHE_MB=512
ENV VLLM_V1_USE_OUTLINES_CACHE=0

# Advanced
ENV VLLM_MLA_DISABLE=0
ENV VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=300
ENV VLLM_MQ_MAX_CHUNK_BYTES_MB=16
ENV VLLM_V1_OUTPUT_PROC_CHUNK_SIZE=128

# Install runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libnuma1 \
    numactl \
    libtcmalloc-minimal4 \
    curl \
    procps \
    openssl \
    wget \
    ca-certificates \
    binutils \
    gosu

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Create directories
RUN mkdir -p /vllm /data/models /data/cache/vllm /data/config/vllm

WORKDIR /vllm

# Environment for uv-managed Python
ENV VIRTUAL_ENV=/vllm/venv
ENV PATH="/vllm/venv/bin:$PATH"
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never

# Install Python, vLLM, and cleanup in single layer to minimize image size
COPY setup_vllm.sh cleanup.sh /tmp/
RUN --mount=type=cache,id=uv-${VARIANT},target=/root/.cache/uv,sharing=locked \
    chmod +x /tmp/setup_vllm.sh /tmp/cleanup.sh && \
    /tmp/setup_vllm.sh "${VARIANT}" "${VLLM_VERSION}" "${USE_GITHUB_RELEASE}" && \
    /tmp/cleanup.sh && \
    rm -f /tmp/setup_vllm.sh /tmp/cleanup.sh

# Store Python version
RUN echo "VLLM_PYTHON_VERSION=$(cat /vllm/python_version.txt)" >> /etc/environment

# Copy entrypoint scripts
COPY entrypoint.sh banner.sh /vllm/
RUN chmod +x /vllm/entrypoint.sh /vllm/banner.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${VLLM_SERVER_PORT:-8000}/health || exit 1

ENTRYPOINT ["/vllm/entrypoint.sh"]
