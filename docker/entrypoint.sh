#!/bin/bash
set -e

# =============================================================================
# vLLM CPU Optimized Entrypoint Script v2.0
# =============================================================================
# Dynamically configures CPU performance settings based on available resources.
#
# This script auto-detects optimal settings at runtime if not explicitly
# configured by the user. Users can override any setting via:
#   docker run -e VAR=value
#
# RECOMMENDED DOCKER RUN OPTIONS for optimal performance:
#   docker run \
#     --cap-add SYS_NICE \
#     --security-opt seccomp=unconfined \
#     --shm-size 4g \
#     -e VLLM_CPU_KVCACHE_SPACE=8 \
#     ...
#
# User/Group Configuration:
#   PUID                      - User ID to run as (unset = root)
#   PGID                      - Group ID to run as (unset = root)
#
# CPU Performance Environment Variables (auto-configured if not set):
#   VLLM_CPU_KVCACHE_SPACE    - KV cache size in GiB (default: 25% of RAM)
#   VLLM_CPU_OMP_THREADS_BIND - Thread binding strategy (default: auto)
#   VLLM_CPU_NUM_OF_RESERVED_CPU - Reserved cores for async tasks (default: 1-2)
#   VLLM_CPU_SGL_KERNEL       - Enable SGL kernel for small batches (default: 0)
#   VLLM_CPU_MOE_PREPACK      - Enable MoE layer prepacking (default: 1)
#
# Server Configuration (passed to vLLM server):
#   VLLM_SERVER_HOST          - Server bind address (default: 0.0.0.0)
#   VLLM_SERVER_PORT          - Server port (default: 8000)
#   VLLM_API_KEY              - API key for authentication (optional)
#   VLLM_GENERATE_API_KEY     - Auto-generate secure API key if true (optional)
#   VLLM_DTYPE                - Data type (default: bfloat16, recommended for CPU)
#   VLLM_BLOCK_SIZE           - KV cache block size (default: 128, multiples of 32)
#   VLLM_MAX_NUM_BATCHED_TOKENS - Max tokens per batch (higher=throughput, lower=latency)
#   VLLM_TENSOR_PARALLEL_SIZE - Tensor parallelism for multi-socket (default: 1)
#   VLLM_MODEL                - Model to load (passed as --model argument)
#   VLLM_MAX_MODEL_LEN        - Maximum model context length (optional)
#
# Host-level optimizations for maximum performance (run on host, not container):
#   # Enable Transparent Huge Pages (recommended by Intel for LLM workloads)
#   echo always > /sys/kernel/mm/transparent_hugepage/enabled
#
#   # Enable NUMA balancing
#   echo 1 > /proc/sys/kernel/numa_balancing
#
# Reference: https://docs.vllm.ai/en/latest/getting_started/installation/cpu/
# =============================================================================

# =============================================================================
# PUID/PGID User Switching
# =============================================================================
# If PUID/PGID are set, create user and re-exec as that user
# This must happen before any other operations

if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
    # Only do user setup if we're currently root
    if [ "$(id -u)" = "0" ]; then
        echo "=== User Configuration ==="
        echo "Setting up user with PUID=${PUID}, PGID=${PGID}"

        # Create group if it doesn't exist
        if ! getent group vllm > /dev/null 2>&1; then
            groupadd -g "${PGID}" vllm
        fi

        # Create user if it doesn't exist
        if ! getent passwd vllm > /dev/null 2>&1; then
            useradd -u "${PUID}" -g "${PGID}" -d /data -s /bin/bash -M vllm
        fi

        # Set ownership of data directory (models, cache, config)
        chown -R "${PUID}:${PGID}" /data 2>/dev/null || true

        # Set ownership of vllm directory (for Python env access)
        chown -R "${PUID}:${PGID}" /vllm 2>/dev/null || true

        echo "Running as user: vllm (${PUID}:${PGID})"
        echo "==========================="

        # Re-exec this script as the vllm user
        exec gosu vllm "$0" "$@"
    fi
fi

# =============================================================================
# Display Banner
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/banner.sh" ]; then
    source "${SCRIPT_DIR}/banner.sh"
elif [ -f "/vllm/banner.sh" ]; then
    source "/vllm/banner.sh"
fi

# Detect platform
ARCH=$(uname -m)

# =============================================================================
# Helper Functions
# =============================================================================

get_physical_cores() {
    # Get number of physical CPU cores (excluding hyperthreads)
    # This is important for OpenMP thread binding - we want physical cores only
    if [ -f /proc/cpuinfo ]; then
        # Method 1: Use lscpu to count unique core IDs per socket
        local cores
        cores=$(lscpu -p=Core,Socket 2>/dev/null | grep -v '^#' | sort -u | wc -l)
        if [ "${cores}" -gt 0 ]; then
            echo "${cores}"
            return
        fi
    fi
    # Fallback: use nproc (includes hyperthreads, but better than nothing)
    nproc
}

get_logical_cores() {
    # Get total number of logical CPU cores (including hyperthreads)
    nproc
}

get_available_memory_gb() {
    # Get available memory in GiB
    if [ -f /proc/meminfo ]; then
        local mem_kb
        mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        if [ -n "${mem_kb}" ]; then
            echo $((mem_kb / 1024 / 1024))
            return
        fi
        # Fallback to total memory if MemAvailable not present
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        if [ -n "${mem_kb}" ]; then
            echo $((mem_kb / 1024 / 1024))
            return
        fi
    fi
    # Default fallback for very old systems
    echo "8"
}

get_total_memory_gb() {
    # Get total memory in GiB (for NUMA calculations)
    if [ -f /proc/meminfo ]; then
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        if [ -n "${mem_kb}" ]; then
            echo $((mem_kb / 1024 / 1024))
            return
        fi
    fi
    echo "8"
}

get_numa_nodes() {
    # Get number of NUMA nodes
    # Important: vLLM treats each NUMA node as a TP/PP rank
    if command -v numactl &> /dev/null; then
        local nodes
        nodes=$(numactl --hardware 2>/dev/null | grep "available:" | awk '{print $2}')
        if [ -n "${nodes}" ]; then
            echo "${nodes}"
            return
        fi
    fi
    # Fallback: check sysfs
    if [ -d /sys/devices/system/node ]; then
        local nodes
        nodes=$(find /sys/devices/system/node -maxdepth 1 -type d -name 'node*' 2>/dev/null | wc -l)
        if [ "${nodes}" -gt 0 ]; then
            echo "${nodes}"
            return
        fi
    fi
    echo "1"
}

check_numa_permissions() {
    # Check if NUMA syscalls are available (may be blocked in Docker)
    # Reference: https://docs.vllm.ai/en/latest/getting_started/installation/cpu/
    if command -v numactl &> /dev/null; then
        if ! numactl --show &> /dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}

check_cpu_features() {
    # Detect CPU instruction set features
    local features=""
    if [ -f /proc/cpuinfo ]; then
        local flags
        flags=$(grep -m1 'flags' /proc/cpuinfo | cut -d: -f2)

        # Check for key features used by vLLM CPU backend
        if echo "${flags}" | grep -qw 'avx512f'; then
            features="${features} AVX512"
        fi
        if echo "${flags}" | grep -qw 'avx512_vnni'; then
            features="${features} AVX512_VNNI"
        fi
        if echo "${flags}" | grep -qw 'avx512_bf16'; then
            features="${features} AVX512_BF16"
        fi
        if echo "${flags}" | grep -qw 'amx_bf16'; then
            features="${features} AMX_BF16"
        fi
        if echo "${flags}" | grep -qw 'amx_int8'; then
            features="${features} AMX_INT8"
        fi
    fi
    echo "${features}"
}

get_recommended_variant() {
    # Recommend the best vllm-cpu variant based on detected CPU features
    # Returns: variant name (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
    local arch="$1"
    local features="$2"

    # ARM64 only supports noavx512 (base build)
    if [ "${arch}" = "aarch64" ]; then
        echo "noavx512"
        return
    fi

    # x86_64: Check features from highest to lowest capability
    if echo "${features}" | grep -q "AMX_BF16"; then
        echo "amxbf16"
    elif echo "${features}" | grep -q "AVX512_BF16"; then
        echo "avx512bf16"
    elif echo "${features}" | grep -q "AVX512_VNNI"; then
        echo "avx512vnni"
    elif echo "${features}" | grep -q "AVX512"; then
        echo "avx512"
    else
        echo "noavx512"
    fi
}

show_variant_recommendation() {
    # Display variant recommendation at startup
    local current_variant="${VLLM_CPU_VARIANT:-unknown}"
    local recommended_variant="$1"
    local features="$2"

    echo ""
    echo "=== CPU Variant Recommendation ==="
    echo "Detected CPU features:${features:- (none detected)}"
    echo "Recommended variant: ${recommended_variant}"
    echo "Current variant:     ${current_variant}"

    if [ "${current_variant}" = "${recommended_variant}" ]; then
        echo "✓ You are using the optimal variant for your CPU!"
    elif [ "${current_variant}" = "unknown" ] || [ -z "${current_variant}" ]; then
        echo "⚠ Could not determine current variant."
        echo "  For best performance, use: vllm-cpu-${recommended_variant}"
    else
        # Determine if current variant is suboptimal or incompatible
        local current_level=0
        local recommended_level=0

        case "${current_variant}" in
            noavx512) current_level=0 ;;
            avx512) current_level=1 ;;
            avx512vnni) current_level=2 ;;
            avx512bf16) current_level=3 ;;
            amxbf16) current_level=4 ;;
        esac

        case "${recommended_variant}" in
            noavx512) recommended_level=0 ;;
            avx512) recommended_level=1 ;;
            avx512vnni) recommended_level=2 ;;
            avx512bf16) recommended_level=3 ;;
            amxbf16) recommended_level=4 ;;
        esac

        if [ "${current_level}" -gt "${recommended_level}" ]; then
            echo "⚠ WARNING: Current variant requires CPU features not available!"
            echo "  Your CPU supports up to: ${recommended_variant}"
            echo "  This may cause illegal instruction errors or crashes."
            echo "  Recommended: docker pull mekayelanik/vllm-cpu:${recommended_variant}-latest"
        else
            echo "ℹ You could get better performance with: vllm-cpu-${recommended_variant}"
            echo "  Upgrade: docker pull mekayelanik/vllm-cpu:${recommended_variant}-latest"
        fi
    fi
    echo "==================================="
}

# =============================================================================
# Resource Detection
# =============================================================================

PHYSICAL_CORES=$(get_physical_cores)
LOGICAL_CORES=$(get_logical_cores)
AVAILABLE_MEM_GB=$(get_available_memory_gb)
TOTAL_MEM_GB=$(get_total_memory_gb)
NUMA_NODES=$(get_numa_nodes)
CPU_FEATURES=$(check_cpu_features)
NUMA_OK=true
if ! check_numa_permissions; then
    NUMA_OK=false
fi

echo "=== Detected Hardware ==="
echo "Architecture: ${ARCH}"
echo "Physical CPU cores: ${PHYSICAL_CORES}"
echo "Logical CPU cores: ${LOGICAL_CORES}"
echo "Available memory: ${AVAILABLE_MEM_GB} GiB"
echo "Total memory: ${TOTAL_MEM_GB} GiB"
echo "NUMA nodes: ${NUMA_NODES}"
if [ -n "${CPU_FEATURES}" ]; then
    echo "CPU features:${CPU_FEATURES}"
fi
if [ "${NUMA_OK}" = "false" ]; then
    echo ""
    echo "WARNING: NUMA syscalls blocked (get_mempolicy: Operation not permitted)"
    echo "Performance may be suboptimal. To enable NUMA optimizations, run with:"
    echo "  docker run --cap-add SYS_NICE --security-opt seccomp=unconfined ..."
fi
if [ "${NUMA_NODES}" -gt 1 ]; then
    echo ""
    echo "Multi-socket system detected!"
    echo "Consider setting VLLM_TENSOR_PARALLEL_SIZE=${NUMA_NODES} for better performance"
    echo "Each NUMA node will be treated as a TP/PP rank."
    echo "Memory per NUMA node: ~$((TOTAL_MEM_GB / NUMA_NODES)) GiB"
fi
echo "========================="

# =============================================================================
# Variant Recommendation
# =============================================================================
# Show recommended variant based on detected CPU features
RECOMMENDED_VARIANT=$(get_recommended_variant "${ARCH}" "${CPU_FEATURES}")
show_variant_recommendation "${RECOMMENDED_VARIANT}" "${CPU_FEATURES}"

# =============================================================================
# Dynamic CPU Configuration
# =============================================================================

echo ""
echo "=== Configuring CPU Performance Settings ==="

# --- VLLM_CPU_KVCACHE_SPACE ---
# Auto-calculate based on available memory if not set
# Reference: https://docs.vllm.ai/en/latest/getting_started/installation/cpu/
# Rule: Use ~25% of available memory for KV cache
# IMPORTANT: For multi-NUMA systems, ensure KV cache + model weights fit in single NUMA node
if [ -z "${VLLM_CPU_KVCACHE_SPACE}" ] || [ "${VLLM_CPU_KVCACHE_SPACE}" = "0" ]; then
    if [ "${NUMA_NODES}" -gt 1 ]; then
        # For multi-NUMA: calculate based on per-node memory to avoid cross-NUMA access
        MEM_PER_NODE=$((AVAILABLE_MEM_GB / NUMA_NODES))
        CALCULATED_CACHE=$((MEM_PER_NODE / 4))
    else
        # For single-NUMA: use 25% of total available memory
        CALCULATED_CACHE=$((AVAILABLE_MEM_GB / 4))
    fi
    # Clamp between 1 and 64 GiB (default is 4 GiB in vLLM)
    if [ "${CALCULATED_CACHE}" -lt 1 ]; then
        CALCULATED_CACHE=1
    elif [ "${CALCULATED_CACHE}" -gt 64 ]; then
        CALCULATED_CACHE=64
    fi
    export VLLM_CPU_KVCACHE_SPACE="${CALCULATED_CACHE}"
    echo "VLLM_CPU_KVCACHE_SPACE=${VLLM_CPU_KVCACHE_SPACE} GiB (auto: 25% of available memory)"
else
    echo "VLLM_CPU_KVCACHE_SPACE=${VLLM_CPU_KVCACHE_SPACE} GiB (user-configured)"
fi

# --- VLLM_CPU_OMP_THREADS_BIND ---
# Configure OpenMP thread binding for optimal performance
# Reference: vLLM uses 'auto' for NUMA-aware binding internally
# For multi-rank (TP/PP), cores for different ranks are separated by '|'
if [ -z "${VLLM_CPU_OMP_THREADS_BIND}" ]; then
    if [ "${ARCH}" = "aarch64" ] && [ "${NUMA_OK}" = "false" ]; then
        # ARM64 without NUMA support: disable binding
        export VLLM_CPU_OMP_THREADS_BIND="nobind"
        echo "VLLM_CPU_OMP_THREADS_BIND=nobind (auto: NUMA not available on ARM64)"
    else
        # Default: let vLLM handle NUMA-aware binding
        export VLLM_CPU_OMP_THREADS_BIND="auto"
        echo "VLLM_CPU_OMP_THREADS_BIND=auto (NUMA-aware binding enabled)"
    fi
else
    echo "VLLM_CPU_OMP_THREADS_BIND=${VLLM_CPU_OMP_THREADS_BIND} (user-configured)"
fi

# --- VLLM_CPU_NUM_OF_RESERVED_CPU ---
# Reserve CPU cores for vLLM frontend (not used by OpenMP threads)
# These cores handle async tasks, tokenization, and API requests
if [ -z "${VLLM_CPU_NUM_OF_RESERVED_CPU}" ]; then
    if [ "${PHYSICAL_CORES}" -gt 32 ]; then
        export VLLM_CPU_NUM_OF_RESERVED_CPU=4
    elif [ "${PHYSICAL_CORES}" -gt 16 ]; then
        export VLLM_CPU_NUM_OF_RESERVED_CPU=2
    else
        export VLLM_CPU_NUM_OF_RESERVED_CPU=1
    fi
    echo "VLLM_CPU_NUM_OF_RESERVED_CPU=${VLLM_CPU_NUM_OF_RESERVED_CPU} (auto: based on ${PHYSICAL_CORES} cores)"
else
    echo "VLLM_CPU_NUM_OF_RESERVED_CPU=${VLLM_CPU_NUM_OF_RESERVED_CPU} (user-configured)"
fi

# --- VLLM_CPU_SGL_KERNEL ---
# Enable SGL (Single-Group-Layer) kernels optimized for small batch sizes
# Best for: AMX-enabled CPUs (Sapphire Rapids+), BF16 weights, shapes divisible by 32
# Reference: https://docs.vllm.ai/en/latest/configuration/env_vars/
if [ -z "${VLLM_CPU_SGL_KERNEL}" ]; then
    if [ "${ARCH}" = "x86_64" ]; then
        # Check for AMX support in CPU features or variant name
        if echo "${CPU_FEATURES}" | grep -q "AMX" || [ "${VLLM_CPU_VARIANT}" = "amxbf16" ]; then
            export VLLM_CPU_SGL_KERNEL=1
            echo "VLLM_CPU_SGL_KERNEL=1 (auto: AMX support detected)"
        else
            export VLLM_CPU_SGL_KERNEL=0
            echo "VLLM_CPU_SGL_KERNEL=0 (auto: AMX not detected)"
        fi
    else
        export VLLM_CPU_SGL_KERNEL=0
        echo "VLLM_CPU_SGL_KERNEL=0 (auto: x86_64 only feature)"
    fi
else
    echo "VLLM_CPU_SGL_KERNEL=${VLLM_CPU_SGL_KERNEL} (user-configured)"
fi

# --- VLLM_CPU_MOE_PREPACK ---
# Enable prepacking for MoE (Mixture of Experts) layers
# Reference: This is passed to ipex.llm.modules.GatedMLPMOE
if [ -z "${VLLM_CPU_MOE_PREPACK}" ]; then
    # Default to enabled (1) on supported CPUs
    export VLLM_CPU_MOE_PREPACK=1
    echo "VLLM_CPU_MOE_PREPACK=1 (auto: MoE prepacking enabled)"
else
    echo "VLLM_CPU_MOE_PREPACK=${VLLM_CPU_MOE_PREPACK} (user-configured)"
fi

# =============================================================================
# Memory Allocator Configuration
# =============================================================================

echo ""
echo "=== Memory Allocator Configuration ==="

# --- LD_PRELOAD (TCMalloc) ---
# Auto-detect and load TCMalloc for better memory performance
# TCMalloc provides better multi-threaded allocation than glibc malloc
if [ -z "${LD_PRELOAD}" ]; then
    TCMALLOC_PATH=""
    if [ "${ARCH}" = "x86_64" ] && [ -f /usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4 ]; then
        TCMALLOC_PATH="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"
    elif [ "${ARCH}" = "aarch64" ] && [ -f /usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4 ]; then
        TCMALLOC_PATH="/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4"
    fi

    if [ -n "${TCMALLOC_PATH}" ]; then
        export LD_PRELOAD="${TCMALLOC_PATH}"
        echo "LD_PRELOAD=${TCMALLOC_PATH} (TCMalloc enabled)"
    else
        echo "LD_PRELOAD not set (TCMalloc not found)"
    fi
else
    echo "LD_PRELOAD=${LD_PRELOAD} (user-configured)"
fi

# --- MALLOC_TRIM_THRESHOLD_ ---
# Tune glibc malloc memory trimming (lower = more aggressive)
# This helps reduce memory fragmentation
if [ -z "${MALLOC_TRIM_THRESHOLD_}" ]; then
    export MALLOC_TRIM_THRESHOLD_=100000
fi

# =============================================================================
# Configuration Summary
# =============================================================================
echo ""
echo "=== Final vLLM CPU Configuration ==="
echo "VLLM_CPU_KVCACHE_SPACE: ${VLLM_CPU_KVCACHE_SPACE} GiB"
echo "VLLM_CPU_OMP_THREADS_BIND: ${VLLM_CPU_OMP_THREADS_BIND}"
echo "VLLM_CPU_NUM_OF_RESERVED_CPU: ${VLLM_CPU_NUM_OF_RESERVED_CPU}"
echo "VLLM_CPU_SGL_KERNEL: ${VLLM_CPU_SGL_KERNEL}"
echo "VLLM_CPU_MOE_PREPACK: ${VLLM_CPU_MOE_PREPACK}"
echo "VLLM_CPU_VARIANT: ${VLLM_CPU_VARIANT:-not set}"
echo "LD_PRELOAD: ${LD_PRELOAD:-not set}"
echo "MALLOC_TRIM_THRESHOLD_: ${MALLOC_TRIM_THRESHOLD_}"
echo "====================================="

# =============================================================================
# Debug output (extended info when DEBUG enabled)
# =============================================================================
if [ "${VLLM_LOGGING_LEVEL}" = "DEBUG" ]; then
    echo ""
    echo "=== Extended Debug Info ==="
    echo "Platform: ${ARCH}"
    echo "Python: $(python --version 2>&1)"
    echo "vLLM: $(python -c 'import vllm; print(vllm.__version__)' 2>&1 || echo 'not installed')"
    echo "PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>&1 || echo 'not installed')"
    echo "VLLM_SERVER_HOST: ${VLLM_SERVER_HOST:-0.0.0.0}"
    echo "VLLM_SERVER_PORT: ${VLLM_SERVER_PORT:-8000}"
    echo "VLLM_API_KEY: ${VLLM_API_KEY:+(set)}"
    echo "HF_HOME: ${HF_HOME:-not set}"
    echo "VLLM_CACHE_ROOT: ${VLLM_CACHE_ROOT:-not set}"
    # Print all VLLM_* environment variables
    echo ""
    echo "All VLLM_* environment variables:"
    env | grep "^VLLM_" | sort || true
    echo "==========================="
fi

# =============================================================================
# Start vLLM server or execute custom command
# =============================================================================
echo ""
if [ $# -eq 0 ]; then
    # No arguments provided - start vLLM OpenAI-compatible server
    # Build command array for proper argument handling
    CMD="python -m vllm.entrypoints.openai.api_server"
    CMD="${CMD} --host ${VLLM_SERVER_HOST:-0.0.0.0}"
    CMD="${CMD} --port ${VLLM_SERVER_PORT:-8000}"

    # Model - required for server to start
    if [ -n "${VLLM_MODEL}" ]; then
        CMD="${CMD} --model ${VLLM_MODEL}"
    fi

    # Data type - bfloat16 recommended for CPU stability and AMX acceleration
    CMD="${CMD} --dtype ${VLLM_DTYPE:-bfloat16}"

    # Block size - multiples of 32, default 128 for CPU
    CMD="${CMD} --block-size ${VLLM_BLOCK_SIZE:-128}"

    # Tensor parallelism for multi-socket systems
    if [ -n "${VLLM_TENSOR_PARALLEL_SIZE}" ] && [ "${VLLM_TENSOR_PARALLEL_SIZE}" -gt 1 ]; then
        CMD="${CMD} --tensor-parallel-size ${VLLM_TENSOR_PARALLEL_SIZE}"
    fi

    # Pipeline parallelism
    if [ -n "${VLLM_PIPELINE_PARALLEL_SIZE}" ] && [ "${VLLM_PIPELINE_PARALLEL_SIZE}" -gt 1 ]; then
        CMD="${CMD} --pipeline-parallel-size ${VLLM_PIPELINE_PARALLEL_SIZE}"
    fi

    # Max model length
    if [ -n "${VLLM_MAX_MODEL_LEN}" ]; then
        CMD="${CMD} --max-model-len ${VLLM_MAX_MODEL_LEN}"
    fi

    # Max batched tokens - tune for throughput vs latency
    # Larger values = higher throughput, smaller values = lower latency
    if [ -n "${VLLM_MAX_NUM_BATCHED_TOKENS}" ]; then
        CMD="${CMD} --max-num-batched-tokens ${VLLM_MAX_NUM_BATCHED_TOKENS}"
    fi

    # Max number of sequences
    if [ -n "${VLLM_MAX_NUM_SEQS}" ]; then
        CMD="${CMD} --max-num-seqs ${VLLM_MAX_NUM_SEQS}"
    fi

    # Quantization method
    if [ -n "${VLLM_QUANTIZATION}" ]; then
        CMD="${CMD} --quantization ${VLLM_QUANTIZATION}"
    fi

    # Trust remote code (needed for some models)
    if [ "${VLLM_TRUST_REMOTE_CODE}" = "true" ] || [ "${VLLM_TRUST_REMOTE_CODE}" = "1" ]; then
        CMD="${CMD} --trust-remote-code"
    fi

    # Disable sliding window (for models that support it)
    if [ "${VLLM_DISABLE_SLIDING_WINDOW}" = "true" ] || [ "${VLLM_DISABLE_SLIDING_WINDOW}" = "1" ]; then
        CMD="${CMD} --disable-sliding-window"
    fi

    # Chat template
    if [ -n "${VLLM_CHAT_TEMPLATE}" ]; then
        CMD="${CMD} --chat-template ${VLLM_CHAT_TEMPLATE}"
    fi

    # Served model name (for API compatibility)
    if [ -n "${VLLM_SERVED_MODEL_NAME}" ]; then
        CMD="${CMD} --served-model-name ${VLLM_SERVED_MODEL_NAME}"
    fi

    # API key authentication
    # Auto-generate secure API key if requested
    if [ -z "${VLLM_API_KEY}" ] && [ "${VLLM_GENERATE_API_KEY}" = "true" ]; then
        VLLM_API_KEY=$(openssl rand -hex 32)
        export VLLM_API_KEY
        echo "========================================================" >&2
        echo "  AUTO-GENERATED API KEY (save this, shown only once):" >&2
        echo "  ${VLLM_API_KEY}" >&2
        echo "========================================================" >&2
        echo "" >&2
    fi

    if [ -n "${VLLM_API_KEY}" ]; then
        CMD="${CMD} --api-key ${VLLM_API_KEY}"
    fi

    # Additional arguments passed via VLLM_EXTRA_ARGS
    if [ -n "${VLLM_EXTRA_ARGS}" ]; then
        CMD="${CMD} ${VLLM_EXTRA_ARGS}"
    fi

    echo "=== Server Configuration ==="
    echo "Host: ${VLLM_SERVER_HOST:-0.0.0.0}"
    echo "Port: ${VLLM_SERVER_PORT:-8000}"
    echo "Model: ${VLLM_MODEL:-<not set - pass via args>}"
    echo "Dtype: ${VLLM_DTYPE:-bfloat16}"
    echo "Block size: ${VLLM_BLOCK_SIZE:-128}"
    echo "Tensor parallel: ${VLLM_TENSOR_PARALLEL_SIZE:-1}"
    echo "Pipeline parallel: ${VLLM_PIPELINE_PARALLEL_SIZE:-1}"
    echo "Max model length: ${VLLM_MAX_MODEL_LEN:-auto}"
    echo "Max batched tokens: ${VLLM_MAX_NUM_BATCHED_TOKENS:-auto}"
    echo "API key: ${VLLM_API_KEY:+(set)}"
    echo "============================="
    echo ""
    echo "Starting vLLM server..."
    echo "Command: ${CMD}"
    echo ""

    # Use exec to replace shell process with vLLM server
    # shellcheck disable=SC2086
    exec ${CMD}
else
    # Execute custom command (e.g., python script, bash, etc.)
    echo "Executing custom command: $*"
    exec "$@"
fi
