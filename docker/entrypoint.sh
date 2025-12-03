#!/bin/bash
set -e

# =============================================================================
# vLLM CPU Optimized Entrypoint Script
# =============================================================================
# Dynamically configures CPU performance settings based on available resources.
#
# This script auto-detects optimal settings at runtime if not explicitly
# configured by the user. Users can override any setting via:
#   docker run -e VAR=value
#
# Environment Variables (auto-configured if not set):
#   VLLM_CPU_KVCACHE_SPACE    - KV cache size in GiB (default: 25% of RAM)
#   VLLM_CPU_OMP_THREADS_BIND - Thread binding strategy (default: auto)
#   VLLM_CPU_NUM_OF_RESERVED_CPU - Reserved cores for async tasks (default: 1-2)
#   VLLM_CPU_SGL_KERNEL       - Enable SGL kernel for AMX (default: 0)
#
# Server Configuration (passed to vLLM server):
#   VLLM_HOST                 - Server bind address (default: 0.0.0.0)
#   VLLM_PORT                 - Server port (default: 8000)
#   VLLM_API_KEY              - API key for authentication (optional)
#   VLLM_GENERATE_API_KEY     - Auto-generate secure API key if true (optional)
#   VLLM_DTYPE                - Data type (default: bfloat16, recommended for CPU)
#   VLLM_BLOCK_SIZE           - KV cache block size (default: 128, multiples of 32)
#   VLLM_MAX_NUM_BATCHED_TOKENS - Max tokens per batch (higher=throughput, lower=latency)
#   VLLM_TENSOR_PARALLEL_SIZE - Tensor parallelism for multi-socket (default: 1)
#
# Host-level optimizations for maximum performance (run on host, not container):
#   # Enable Transparent Huge Pages (recommended by Intel for LLM workloads)
#   echo always > /sys/kernel/mm/transparent_hugepage/enabled
#
#   # Enable NUMA balancing
#   echo 1 > /proc/sys/kernel/numa_balancing
#
# Reference: https://docs.vllm.ai/en/stable/getting_started/installation/cpu/
# =============================================================================

# =============================================================================
# Display Banner
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/banner.sh" ]; then
    source "${SCRIPT_DIR}/banner.sh"
elif [ -f "/app/banner.sh" ]; then
    source "/app/banner.sh"
fi

# Detect platform
ARCH=$(uname -m)

# =============================================================================
# Helper Functions
# =============================================================================

get_physical_cores() {
    # Get number of physical CPU cores (excluding hyperthreads)
    if [ -f /proc/cpuinfo ]; then
        # Method 1: Count unique core IDs per socket
        local cores=$(lscpu -p=Core,Socket 2>/dev/null | grep -v '^#' | sort -u | wc -l)
        if [ "${cores}" -gt 0 ]; then
            echo "${cores}"
            return
        fi
    fi
    # Fallback: use nproc (includes hyperthreads)
    nproc
}

get_available_memory_gb() {
    # Get available memory in GiB
    if [ -f /proc/meminfo ]; then
        local mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        if [ -n "${mem_kb}" ]; then
            echo $((mem_kb / 1024 / 1024))
            return
        fi
        # Fallback to total memory
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        if [ -n "${mem_kb}" ]; then
            echo $((mem_kb / 1024 / 1024))
            return
        fi
    fi
    # Default fallback
    echo "8"
}

get_numa_nodes() {
    # Get number of NUMA nodes
    if command -v numactl &> /dev/null; then
        local nodes=$(numactl --hardware 2>/dev/null | grep "available:" | awk '{print $2}')
        if [ -n "${nodes}" ]; then
            echo "${nodes}"
            return
        fi
    fi
    echo "1"
}

# =============================================================================
# Resource Detection
# =============================================================================

PHYSICAL_CORES=$(get_physical_cores)
AVAILABLE_MEM_GB=$(get_available_memory_gb)
NUMA_NODES=$(get_numa_nodes)

echo "=== Detected Resources ==="
echo "Physical CPU cores: ${PHYSICAL_CORES}"
echo "Available memory: ${AVAILABLE_MEM_GB} GiB"
echo "NUMA nodes: ${NUMA_NODES}"
if [ "${NUMA_NODES}" -gt 1 ]; then
    echo ""
    echo "Multi-socket system detected!"
    echo "Consider setting VLLM_TENSOR_PARALLEL_SIZE=${NUMA_NODES} for better performance"
fi
echo "=========================="

# =============================================================================
# Dynamic Configuration
# =============================================================================

# --- VLLM_CPU_KVCACHE_SPACE ---
# Auto-calculate based on available memory if not set
# Rule: Use ~25% of available memory for KV cache, min 1GB, max 64GB
if [ -z "${VLLM_CPU_KVCACHE_SPACE}" ] || [ "${VLLM_CPU_KVCACHE_SPACE}" = "0" ]; then
    # Calculate 25% of available memory
    CALCULATED_CACHE=$((AVAILABLE_MEM_GB / 4))
    # Clamp between 1 and 64 GiB
    if [ "${CALCULATED_CACHE}" -lt 1 ]; then
        CALCULATED_CACHE=1
    elif [ "${CALCULATED_CACHE}" -gt 64 ]; then
        CALCULATED_CACHE=64
    fi
    export VLLM_CPU_KVCACHE_SPACE="${CALCULATED_CACHE}"
    echo "Auto-configured VLLM_CPU_KVCACHE_SPACE=${VLLM_CPU_KVCACHE_SPACE} GiB (25% of ${AVAILABLE_MEM_GB} GiB available)"
fi

# --- VLLM_CPU_NUM_OF_RESERVED_CPU ---
# Auto-calculate based on core count if not set
# Rule: Reserve 1 core for small systems, 2 for larger systems (>16 cores)
if [ -z "${VLLM_CPU_NUM_OF_RESERVED_CPU}" ]; then
    if [ "${PHYSICAL_CORES}" -gt 16 ]; then
        export VLLM_CPU_NUM_OF_RESERVED_CPU=2
    else
        export VLLM_CPU_NUM_OF_RESERVED_CPU=1
    fi
    echo "Auto-configured VLLM_CPU_NUM_OF_RESERVED_CPU=${VLLM_CPU_NUM_OF_RESERVED_CPU} (${PHYSICAL_CORES} physical cores)"
fi

# --- VLLM_CPU_OMP_THREADS_BIND ---
# Keep 'auto' as default - vLLM handles NUMA-aware binding internally
# Only override for ARM64 without NUMA support
if [ -z "${VLLM_CPU_OMP_THREADS_BIND}" ]; then
    export VLLM_CPU_OMP_THREADS_BIND="auto"
fi

if [ "${ARCH}" = "aarch64" ] && [ "${VLLM_CPU_OMP_THREADS_BIND}" = "auto" ]; then
    if ! command -v numactl &> /dev/null || ! numactl --show &> /dev/null 2>&1; then
        export VLLM_CPU_OMP_THREADS_BIND="nobind"
        echo "Auto-configured VLLM_CPU_OMP_THREADS_BIND=nobind (NUMA not available on ARM64)"
    fi
fi

# --- VLLM_CPU_SGL_KERNEL ---
# Enable only for amxbf16 variant on x86_64
if [ -z "${VLLM_CPU_SGL_KERNEL}" ]; then
    if [ "${ARCH}" = "x86_64" ] && [ "${VLLM_CPU_VARIANT}" = "amxbf16" ]; then
        export VLLM_CPU_SGL_KERNEL=1
        echo "Auto-configured VLLM_CPU_SGL_KERNEL=1 (amxbf16 variant detected)"
    else
        export VLLM_CPU_SGL_KERNEL=0
    fi
fi

# --- LD_PRELOAD (TCMalloc) ---
# Auto-detect and load TCMalloc for better memory performance
if [ -z "${LD_PRELOAD}" ]; then
    if [ -f /usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4 ]; then
        export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"
        echo "Auto-configured LD_PRELOAD with TCMalloc (x86_64)"
    elif [ -f /usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4 ]; then
        export LD_PRELOAD="/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4"
        echo "Auto-configured LD_PRELOAD with TCMalloc (aarch64)"
    fi
fi

# =============================================================================
# Configuration Summary
# =============================================================================
echo ""
echo "=== vLLM CPU Configuration ==="
echo "VLLM_CPU_KVCACHE_SPACE: ${VLLM_CPU_KVCACHE_SPACE} GiB"
echo "VLLM_CPU_OMP_THREADS_BIND: ${VLLM_CPU_OMP_THREADS_BIND}"
echo "VLLM_CPU_NUM_OF_RESERVED_CPU: ${VLLM_CPU_NUM_OF_RESERVED_CPU}"
echo "VLLM_CPU_SGL_KERNEL: ${VLLM_CPU_SGL_KERNEL}"
echo "VLLM_CPU_VARIANT: ${VLLM_CPU_VARIANT:-not set}"
echo "LD_PRELOAD: ${LD_PRELOAD:-not set}"
echo "=============================="
echo ""

# =============================================================================
# Debug output (extended info when DEBUG enabled)
# =============================================================================
if [ "${VLLM_LOGGING_LEVEL}" = "DEBUG" ]; then
    echo "=== Extended Debug Info ==="
    echo "Platform: ${ARCH}"
    echo "Python: $(python --version 2>&1)"
    echo "vLLM: $(python -c 'import vllm; print(vllm.__version__)' 2>&1 || echo 'not installed')"
    echo "VLLM_HOST: ${VLLM_HOST:-0.0.0.0}"
    echo "VLLM_PORT: ${VLLM_PORT:-8000}"
    echo "VLLM_API_KEY: ${VLLM_API_KEY:+(set)}"
    echo "==========================="
    echo ""
fi

# =============================================================================
# Start vLLM server or execute custom command
# =============================================================================
if [ $# -eq 0 ]; then
    # No arguments provided - start vLLM OpenAI-compatible server
    CMD="python -m vllm.entrypoints.openai.api_server"
    CMD="${CMD} --host ${VLLM_HOST:-0.0.0.0}"
    CMD="${CMD} --port ${VLLM_PORT:-8000}"

    # Data type - bfloat16 recommended for CPU stability
    CMD="${CMD} --dtype ${VLLM_DTYPE:-bfloat16}"

    # Block size - multiples of 32, default 128
    CMD="${CMD} --block-size ${VLLM_BLOCK_SIZE:-128}"

    # Tensor parallelism for multi-socket systems
    if [ -n "${VLLM_TENSOR_PARALLEL_SIZE}" ] && [ "${VLLM_TENSOR_PARALLEL_SIZE}" -gt 1 ]; then
        CMD="${CMD} --tensor-parallel-size ${VLLM_TENSOR_PARALLEL_SIZE}"
    fi

    # Max batched tokens - tune for throughput vs latency
    if [ -n "${VLLM_MAX_NUM_BATCHED_TOKENS}" ]; then
        CMD="${CMD} --max-num-batched-tokens ${VLLM_MAX_NUM_BATCHED_TOKENS}"
    fi

    # API key authentication
    # Auto-generate secure API key if requested
    if [ -z "${VLLM_API_KEY}" ] && [ "${VLLM_GENERATE_API_KEY}" = "true" ]; then
        VLLM_API_KEY=$(openssl rand -hex 32)
        export VLLM_API_KEY
        echo "" >&2
        echo "========================================================" >&2
        echo "  AUTO-GENERATED API KEY (save this, shown only once):" >&2
        echo "  ${VLLM_API_KEY}" >&2
        echo "========================================================" >&2
        echo "" >&2
    fi

    if [ -n "${VLLM_API_KEY}" ]; then
        CMD="${CMD} --api-key ${VLLM_API_KEY}"
    fi

    echo ""
    echo "=== Server Configuration ==="
    echo "Host: ${VLLM_HOST:-0.0.0.0}"
    echo "Port: ${VLLM_PORT:-8000}"
    echo "Dtype: ${VLLM_DTYPE:-bfloat16}"
    echo "Block size: ${VLLM_BLOCK_SIZE:-128}"
    echo "Tensor parallel: ${VLLM_TENSOR_PARALLEL_SIZE:-1}"
    echo "Max batched tokens: ${VLLM_MAX_NUM_BATCHED_TOKENS:-auto}"
    echo "API key: ${VLLM_API_KEY:+(set)}"
    echo "============================="
    echo ""
    echo "Starting vLLM server..."
    echo "${CMD}"
    echo ""
    exec ${CMD}
else
    # Execute custom command (e.g., python script, bash, etc.)
    exec "$@"
fi
