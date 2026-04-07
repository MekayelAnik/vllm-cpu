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

ARG BASE_IMAGE=debian:stable-slim
ARG TARGETPLATFORM

# Stage 1: Detect Python version from available wheels
FROM ${BASE_IMAGE} AS python-detector

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates jq

ARG VLLM_VERSION
# Pin Python 3.13 — unified wheel uses stable ABI (abi3), works with any Python >= 3.8
ARG PYTHON_VERSION=3.13
ARG VARIANT=noavx512
ARG USE_GITHUB_RELEASE=false

COPY docker/detect_python_version.sh /detect_python_version.sh
RUN --mount=type=secret,id=GITHUB_TOKEN,required=false \
    chmod +x /detect_python_version.sh && \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || echo "") && \
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
# Pin Python 3.13 — unified wheel uses stable ABI (abi3), works with any Python >= 3.8
ARG PYTHON_VERSION=3.13
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
      org.opencontainers.image.base.name="docker.io/library/debian:stable-slim" \
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
ENV HF_TOKEN=""
ENV HF_HOME=/data/models

# Memory optimization
ENV MALLOC_TRIM_THRESHOLD_=100000

# OpenTelemetry
ENV OTEL_PROPAGATORS=none
ENV OTEL_TRACES_EXPORTER=none

# Docker convenience vars (read by entrypoint.sh, unset before launching vLLM)
ENV VLLM_MODEL=""
ENV VLLM_TOKENIZER=""
ENV VLLM_SERVER_HOST="0.0.0.0"
ENV VLLM_SERVER_PORT="8000"
ENV VLLM_SLEEP_WHEN_IDLE=0
ENV VLLM_MM_INPUT_CACHE_GIB=4

# Install runtime dependencies + create directories (single layer)
# build-essential (g++) is required for PyTorch inductor (torch.compile) JIT kernel compilation
# zlib1g-dev: required for proper zlib linkage on ARM64 (prevents decompression errors)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    libnuma1 \
    numactl \
    libtcmalloc-minimal4 \
    curl \
    jq \
    procps \
    openssl \
    wget \
    ca-certificates \
    binutils \
    gosu \
    build-essential \
    zlib1g-dev && \
    mkdir -p /vllm /data/models /data/cache/vllm /data/config/vllm

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /vllm

# Environment for uv-managed Python
ENV VIRTUAL_ENV=/vllm/venv
ENV PATH="/vllm/venv/bin:$PATH"
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never

# Install Python, vLLM, cleanup, and restore headers in single layer
# setup_vllm.sh handles: install, patches, torch header restoration
COPY docker/setup_vllm.sh docker/cleanup.sh /tmp/
RUN --mount=type=cache,id=uv-${VARIANT}-v2,target=/root/.cache/uv,sharing=locked \
    --mount=type=secret,id=GITHUB_TOKEN,required=false \
    chmod +x /tmp/setup_vllm.sh /tmp/cleanup.sh && \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN 2>/dev/null || echo "") && \
    /tmp/setup_vllm.sh "${VARIANT}" "${VLLM_VERSION}" "${USE_GITHUB_RELEASE}" && \
    /tmp/cleanup.sh && \
    rm -f /tmp/setup_vllm.sh /tmp/cleanup.sh

# Copy entrypoint scripts + store Python version (single layer)
COPY docker/entrypoint.sh docker/banner.sh /vllm/
RUN chmod +x /vllm/entrypoint.sh /vllm/banner.sh && \
    echo "VLLM_PYTHON_VERSION=$(cat /vllm/python_version.txt)" >> /etc/environment

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${VLLM_SERVER_PORT:-8000}/health || exit 1

ENTRYPOINT ["/vllm/entrypoint.sh"]
