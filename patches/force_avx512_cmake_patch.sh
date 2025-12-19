#!/bin/bash
# force_avx512_cmake_patch.sh - Patch vLLM's CMake to enable AVX512 code compilation
#
# Problem: vLLM's cmake/cpu_extension.cmake checks /proc/cpuinfo for AVX512 support.
# When building in containers (manylinux) on non-AVX512 hardware, this check fails
# and AVX512-specific code (including SGL kernels) is not compiled.
#
# This patch adds VLLM_CPU_FORCE_AVX512 environment variable support that enables
# AVX512 code compilation regardless of build machine capabilities.
#
# IMPORTANT: This patch should ONLY be applied to AVX512 variants:
#   - vllm-cpu-avx512
#   - vllm-cpu-avx512vnni
#   - vllm-cpu-avx512bf16
#   - vllm-cpu-amxbf16
#
# Do NOT apply to vllm-cpu (noavx512) variant!
#
# Usage:
#   export VLLM_CPU_FORCE_AVX512=1
#   bash patches/force_avx512_cmake_patch.sh
#   python setup.py bdist_wheel
#

set -euo pipefail

CMAKE_FILE="cmake/cpu_extension.cmake"

# Ensure we're in the vLLM source root
if [ ! -f "$CMAKE_FILE" ]; then
    echo "ERROR: $CMAKE_FILE not found. Run this from vLLM source root."
    echo "Current directory: $(pwd)"
    exit 1
fi

echo "Patching $CMAKE_FILE to support VLLM_CPU_FORCE_AVX512..."

# Check if already patched
if grep -q "VLLM_CPU_FORCE_AVX512" "$CMAKE_FILE"; then
    echo "Already patched, skipping."
    exit 0
fi

# Create a backup
cp "$CMAKE_FILE" "${CMAKE_FILE}.backup"

# Verify the target patterns exist before patching
if ! grep -q 'set(ENABLE_AMXBF16 \$ENV{VLLM_CPU_AMXBF16})' "$CMAKE_FILE"; then
    echo "WARNING: Expected pattern 'set(ENABLE_AMXBF16 \$ENV{VLLM_CPU_AMXBF16})' not found."
    echo "vLLM version may have different CMake structure. Trying alternative approach..."

    # Alternative: insert after any ENABLE_ variable definition
    if grep -q 'set(ENABLE_.*\$ENV{VLLM_CPU_' "$CMAKE_FILE"; then
        # Find the last ENABLE_ env var definition and insert after it
        LAST_ENABLE_LINE=$(grep -n 'set(ENABLE_.*\$ENV{VLLM_CPU_' "$CMAKE_FILE" | tail -1 | cut -d: -f1)
        if [ -n "$LAST_ENABLE_LINE" ]; then
            sed -i "${LAST_ENABLE_LINE}a\\
\\
# Enable AVX512 code compilation (added by vllm-cpu build system)\\
# When building on non-AVX512 hardware (e.g., manylinux containers),\\
# set VLLM_CPU_FORCE_AVX512=1 to compile AVX512 code paths\\
set(FORCE_AVX512 \$ENV{VLLM_CPU_FORCE_AVX512})" "$CMAKE_FILE"
            echo "Inserted FORCE_AVX512 definition after line $LAST_ENABLE_LINE"
        else
            echo "ERROR: Could not find insertion point for FORCE_AVX512 definition"
            exit 1
        fi
    else
        echo "ERROR: Cannot find any ENABLE_ environment variable definitions in CMake file"
        exit 1
    fi
else
    # Primary approach: insert after ENABLE_AMXBF16 definition
    sed -i '/^set(ENABLE_AMXBF16 \$ENV{VLLM_CPU_AMXBF16})/a\
\
# Enable AVX512 code compilation (added by vllm-cpu build system)\
# When building on non-AVX512 hardware (e.g., manylinux containers),\
# set VLLM_CPU_FORCE_AVX512=1 to compile AVX512 code paths\
set(FORCE_AVX512 $ENV{VLLM_CPU_FORCE_AVX512})' "$CMAKE_FILE"
    echo "Inserted FORCE_AVX512 definition after ENABLE_AMXBF16"
fi

# Verify the find_isa pattern exists
if ! grep -q 'find_isa(\${CPUINFO} "avx512f" AVX512_FOUND)' "$CMAKE_FILE"; then
    echo "WARNING: Expected pattern 'find_isa(\${CPUINFO} \"avx512f\" AVX512_FOUND)' not found."
    echo "Trying alternative patterns..."

    # Try to find any line that sets AVX512_FOUND
    if grep -q 'AVX512_FOUND' "$CMAKE_FILE"; then
        # Find the first line that sets or checks AVX512_FOUND
        AVX512_LINE=$(grep -n 'find_isa.*avx512.*AVX512_FOUND\|AVX512_FOUND' "$CMAKE_FILE" | head -1 | cut -d: -f1)
        if [ -n "$AVX512_LINE" ]; then
            sed -i "${AVX512_LINE}a\\
    # Enable AVX512 compilation if FORCE_AVX512 is set (for cross-compilation)\\
    if (FORCE_AVX512)\\
        set(AVX512_FOUND ON)\\
        message(STATUS \"Forcing AVX512 support via VLLM_CPU_FORCE_AVX512 environment variable\")\\
    endif()" "$CMAKE_FILE"
            echo "Inserted FORCE_AVX512 override after line $AVX512_LINE"
        else
            echo "ERROR: Could not find insertion point for FORCE_AVX512 override"
            exit 1
        fi
    else
        echo "ERROR: Cannot find AVX512_FOUND in CMake file - incompatible vLLM version?"
        exit 1
    fi
else
    # Primary approach: insert after find_isa call
    sed -i '/find_isa(\${CPUINFO} "avx512f" AVX512_FOUND)/a\
    # Enable AVX512 compilation if FORCE_AVX512 is set (for cross-compilation)\
    if (FORCE_AVX512)\
        set(AVX512_FOUND ON)\
        message(STATUS "Forcing AVX512 support via VLLM_CPU_FORCE_AVX512 environment variable")\
    endif()' "$CMAKE_FILE"
    echo "Inserted FORCE_AVX512 override after find_isa call"
fi

# Verify the patch was applied correctly
echo ""
echo "Verifying patch..."
ERRORS=0

if ! grep -q 'set(FORCE_AVX512 \$ENV{VLLM_CPU_FORCE_AVX512})' "$CMAKE_FILE"; then
    echo "ERROR: FORCE_AVX512 variable definition not found after patching"
    ERRORS=$((ERRORS + 1))
fi

if ! grep -q 'if (FORCE_AVX512)' "$CMAKE_FILE"; then
    echo "ERROR: FORCE_AVX512 condition not found after patching"
    ERRORS=$((ERRORS + 1))
fi

if ! grep -q 'set(AVX512_FOUND ON)' "$CMAKE_FILE"; then
    echo "ERROR: AVX512_FOUND override not found after patching"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "Patch verification FAILED with $ERRORS errors"
    echo "Restoring backup..."
    cp "${CMAKE_FILE}.backup" "$CMAKE_FILE"
    exit 1
fi

echo "Patch verification PASSED"
echo ""
echo "Patch applied successfully."
echo ""
echo "Build with forced AVX512:"
echo "  export VLLM_CPU_FORCE_AVX512=1"
echo "  export VLLM_CPU_AVX512BF16=1  # for SGL kernels"
echo "  export VLLM_CPU_AVX512VNNI=1  # for SGL kernels"
echo ""
