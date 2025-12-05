#!/bin/sh
# =============================================================================
# cleanup.sh - Minimize Docker image size
# =============================================================================
# This script removes unnecessary files and packages to reduce the final
# Docker image size. It's designed to be run after vLLM installation.
#
# Usage:
#   ./cleanup.sh
#
# What it removes:
#   - GPU-related packages (triton, xformers, flash_attn, bitsandbytes)
#   - CUDA/NVIDIA libraries from PyTorch
#   - Unused PyTorch components (vulkan, mps, metal, caffe2)
#   - Test directories and documentation
#   - Static libraries and header files
#   - Debug symbols from shared libraries
#   - Unused system packages (binutils, wget)
#   - Locale data (keeps only en_US)
#
# NOTE: All cleanup commands use "|| true" to prevent build failures
# from non-critical cleanup operations.
#
# Exit codes:
#   0 - Always succeeds (cleanup failures are non-fatal)
# =============================================================================

echo "=== Starting Cleanup ==="
echo "Removing unnecessary files to minimize image size..."
echo ""

# =============================================================================
# 1. Clean uv cache and pip cache (not needed at runtime)
# =============================================================================
echo "Step 1: Cleaning uv and pip cache..."
# Note: uv cache may be mounted, so we also manually remove cached files
uv cache clean 2>/dev/null || true
rm -vrf /root/.cache/uv/* 2>/dev/null || true
rm -vrf /root/.cache/pip/* 2>/dev/null || true
rm -vrf /vllm/venv/pip-selfcheck.json 2>/dev/null || true

# =============================================================================
# 2. Remove pip/wheel (NOT setuptools - needed for distutils-precedence.pth)
# =============================================================================
echo "Step 2: Removing pip and wheel..."
rm -vrf /vllm/venv/lib/*/site-packages/pip* || true
rm -vrf /vllm/venv/lib/*/site-packages/wheel* || true

# =============================================================================
# 3. Remove GPU-specific packages
# =============================================================================
echo "Step 3: Removing GPU-specific packages..."

# Triton (GPU compiler - not needed for CPU inference)
# Saves ~100-200 MB
rm -vrf /vllm/venv/lib/*/site-packages/triton* || true

# xformers (GPU-specific memory optimization)
rm -vrf /vllm/venv/lib/*/site-packages/xformers* || true

# flash_attn (GPU-specific flash attention)
rm -vrf /vllm/venv/lib/*/site-packages/flash_attn* || true

# bitsandbytes (GPU quantization library)
rm -vrf /vllm/venv/lib/*/site-packages/bitsandbytes* || true

# onnx/onnxruntime (not needed for vLLM inference)
rm -vrf /vllm/venv/lib/*/site-packages/onnx* || true
rm -vrf /vllm/venv/lib/*/site-packages/onnxruntime* || true

# =============================================================================
# 4. Remove NVIDIA/CUDA stubs from torch (not needed for CPU)
# =============================================================================
echo "Step 4: Removing CUDA/NVIDIA libraries from PyTorch..."
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cuda* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cudnn* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*nvrtc* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*nccl* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cupti* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cufft* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cusparse* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cusolver* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*cublas* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*curand* || true
rm -vrf /vllm/venv/lib/*/site-packages/nvidia* || true

# =============================================================================
# 5. Remove unused PyTorch components
# =============================================================================
echo "Step 5: Removing unused PyTorch components..."

# caffe2 (legacy, deprecated since PyTorch 1.8, dead in PyTorch 2.x)
rm -vrf /vllm/venv/lib/*/site-packages/caffe2* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/libcaffe2* || true

# NOTE: Do NOT remove functorch - torch._dynamo.backends.debugging imports it
# (functorch.compile.min_cut_rematerialization_partition)

# torch native libraries not needed for CPU (vulkan, mps, metal)
# NOTE: Keep ALL torch/backends/* Python modules intact!
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*vulkan* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*mps* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/lib/*metal* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/_inductor/codegen/cuda* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/_inductor/codegen/triton* || true

# tensorboard integration (not needed at runtime)
# NOTE: Keep torch/profiler - it's imported at torch startup!
rm -vrf /vllm/venv/lib/*/site-packages/tensorboard* || true
rm -vrf /vllm/venv/lib/*/site-packages/torch/utils/tensorboard* || true

# Torch C++ frontend headers (not needed at runtime)
rm -vrf /vllm/venv/lib/*/site-packages/torch/include || true

# Torch share data (example scripts)
rm -vrf /vllm/venv/lib/*/site-packages/torch/share || true

# Torch distributed extras (not needed for single-node CPU)
# NOTE: Do NOT remove torch/distributed/rpc - it's imported at torch startup
rm -vrf /vllm/venv/lib/*/site-packages/torch/distributed/elastic/rendezvous/etcd* || true

# =============================================================================
# 6. Remove safetensors rust source files
# =============================================================================
echo "Step 6: Removing source files..."
rm -vrf /vllm/venv/lib/*/site-packages/safetensors/*.rs || true
rm -vrf /vllm/venv/lib/*/site-packages/safetensors/src || true

# =============================================================================
# 7. Remove test directories and documentation
# =============================================================================
echo "Step 7: Removing test directories and documentation..."
# IMPORTANT: Skip torch entirely - torch/testing is a required module
# IMPORTANT: Skip numpy entirely - numpy._core.tests._natype is imported at runtime by scipy
find /vllm/venv/lib/*/site-packages -depth -type d \( \
    -name "tests" -o -name "test" -o -name "*_tests" -o \
    -name "docs" -o -name "doc" -o -name "examples" -o -name "benchmarks" \
    \) ! -path "*/torch/*" ! -path "*/numpy/*" -exec rm -vrf {} \; 2>/dev/null || true

# =============================================================================
# 8. Remove unnecessary files by extension
# =============================================================================
echo "Step 8: Removing unnecessary file types..."
find /vllm/venv -type f \( \
    -name "*.md" -o -name "*.rst" -o -name "*.pyi" -o \
    -name "LICENSE*" -o -name "COPYING*" -o -name "CHANGELOG*" -o \
    -name "HISTORY*" -o -name "AUTHORS*" -o -name "CONTRIBUTORS*" -o \
    -name "*.h" -o -name "*.hpp" -o -name "*.a" -o \
    \( -name "*.txt" ! -name "requirements*.txt" ! -name "top_level.txt" \) \
    \) -delete 2>/dev/null || true

# =============================================================================
# 9. Remove .dist-info files except essential ones
# =============================================================================
echo "Step 9: Cleaning .dist-info directories..."
find /vllm/venv -path "*/.dist-info/*" -type f \
    ! -name "METADATA" ! -name "RECORD" ! -name "WHEEL" \
    ! -name "top_level.txt" ! -name "entry_points.txt" \
    -delete 2>/dev/null || true

# =============================================================================
# 10. Remove __pycache__ and include directories
# =============================================================================
echo "Step 10: Removing __pycache__ and include directories..."
find /vllm/venv -depth -type d \( -name "__pycache__" -o -name "include" \) \
    -exec rm -vrf {} \; 2>/dev/null || true

# =============================================================================
# 11. Strip debug symbols from shared libraries
# =============================================================================
echo "Step 11: Stripping debug symbols from shared libraries..."
find /vllm/venv /root/.local/share/uv -type f -name "*.so*" \
    -exec strip --strip-all {} \; 2>/dev/null || true

# =============================================================================
# 12. Clean up uv-managed Python installation
# =============================================================================
echo "Step 12: Cleaning uv-managed Python installation..."
find /root/.local/share/uv/python -type f -name "*.a" -delete 2>/dev/null || true
find /root/.local/share/uv/python -type f -name "*.pyo" -delete 2>/dev/null || true
find /root/.local/share/uv/python -depth -type d \( \
    -name "test" -o -name "tests" -o -name "idle_test" -o -name "__pycache__" -o \
    -name "tkinter" -o -name "idlelib" -o -name "turtledemo" -o \
    -name "ensurepip" -o -name "lib2to3" \
    \) -exec rm -vrf {} \; 2>/dev/null || true
rm -vrf /root/.local/share/uv/python/*/share/man 2>/dev/null || true
rm -vrf /root/.local/share/uv/python/*/share/doc 2>/dev/null || true
rm -vrf /root/.local/share/uv/python/*/lib/*/lib-tk 2>/dev/null || true
rm -vrf /root/.local/share/uv/python/*/lib/*/tkinter 2>/dev/null || true
rm -vrf /root/.local/share/uv/python/*/lib/*/config-* 2>/dev/null || true
rm -vrf /root/.local/share/uv/python/*/include 2>/dev/null || true

# =============================================================================
# 13. Remove locale data (keep only en_US)
# =============================================================================
echo "Step 13: Removing unused locale data..."
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' \
    -exec rm -vrf {} \; 2>/dev/null || true
rm -vrf /usr/share/doc /usr/share/man /usr/share/info 2>/dev/null || true

# =============================================================================
# 14. Remove uv binary and build tools
# =============================================================================
echo "Step 14: Removing build tools..."
rm -vf /usr/local/bin/uv
apt-get purge -y --auto-remove binutils wget 2>/dev/null || true
rm -vrf /var/lib/apt/lists/* /var/cache/apt/archives/* /var/log/apt/* /var/log/dpkg.log 2>/dev/null || true

# =============================================================================
# 15. Clean temp files and apt cache
# =============================================================================
echo "Step 15: Cleaning temporary files..."
rm -vrf /tmp/* /var/tmp/* /var/lib/apt/lists/* /var/cache/apt/archives/* \
    /var/log/* /root/.cache/* 2>/dev/null || true

# =============================================================================
# 16. Remove additional unused packages
# =============================================================================
echo "Step 16: Removing additional unused packages..."

# Remove .egg-info directories (not needed at runtime)
find /vllm/venv -type d -name "*.egg-info" -exec rm -vrf {} \; 2>/dev/null || true

# Remove empty directories
find /vllm/venv -type d -empty -delete 2>/dev/null || true

# =============================================================================
# Report results
# =============================================================================
echo ""
echo "=== Cleanup Complete ==="
du -sh /vllm/venv 2>/dev/null || true
du -sh /root/.local/share/uv/python 2>/dev/null || true
du -sh /vllm 2>/dev/null || true
