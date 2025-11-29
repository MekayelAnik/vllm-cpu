#!/bin/bash
# Patch vLLM's cpu_extension.cmake for ARM64 cross-compilation
# When running under QEMU, /proc/cpuinfo shows host (x86) features
# This causes -mavx2 to be added, which fails on ARM64 targets
#
# Strategy: Insert ARM64 detection early and skip /proc/cpuinfo reading

set -e

CMAKE_FILE="cmake/cpu_extension.cmake"

if [ ! -f "$CMAKE_FILE" ]; then
    echo "Warning: $CMAKE_FILE not found, skipping patch"
    exit 0
fi

echo "Patching $CMAKE_FILE for ARM64 cross-compilation..."

# Backup original
cp "$CMAKE_FILE" "${CMAKE_FILE}.backup"

# Step 1: Add ARM64 detection block at the very beginning (after include)
# This sets CPUINFO with ARM content BEFORE the /proc/cpuinfo check
ARM64_BLOCK='
# =============================================================================
# ARM64 Linux cross-compilation support (added by vllm-cpu build)
# When running under QEMU, /proc/cpuinfo incorrectly shows host x86 features
# This must be placed BEFORE the /proc/cpuinfo check
# =============================================================================
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    message(STATUS "ARM64/AArch64 Linux detected - using ARM feature flags")
    # Set CPUINFO with ARM features to prevent x86 detection
    set(CPUINFO "Features : fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm")
    set(CPUINFO_RET 0)
    set(VLLM_ARM64_LINUX TRUE)
endif()
# =============================================================================
'

# Find first "set(" line after include to insert our block
FIRST_SET_LINE=$(grep -n "^set(" "$CMAKE_FILE" | head -1 | cut -d: -f1)
if [ -z "$FIRST_SET_LINE" ]; then
    FIRST_SET_LINE=5
fi

echo "Inserting ARM64 block after line $FIRST_SET_LINE"

# Insert ARM64 block
{
    head -n "$FIRST_SET_LINE" "$CMAKE_FILE"
    echo "$ARM64_BLOCK"
    tail -n "+$((FIRST_SET_LINE + 1))" "$CMAKE_FILE"
} > "${CMAKE_FILE}.tmp"
mv "${CMAKE_FILE}.tmp" "$CMAKE_FILE"

# Step 2: Guard the /proc/cpuinfo check to skip on ARM64
# Change: if (NOT MACOSX_FOUND)
# To:     if(NOT MACOSX_FOUND AND NOT VLLM_ARM64_LINUX)
sed -i 's/if (NOT MACOSX_FOUND)$/if(NOT MACOSX_FOUND AND NOT VLLM_ARM64_LINUX)/' "$CMAKE_FILE"

# Step 3: Add ARM64 Linux handling in the feature detection section
# After "if (MACOSX_FOUND AND CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")"
# and its endif, add elseif for ARM64 Linux

# Find the else() that follows Apple Silicon detection
# Pattern: "else()" followed by find_isa calls
ELSE_LINE=$(grep -n "^else()$" "$CMAKE_FILE" | while read line; do
    linenum=$(echo "$line" | cut -d: -f1)
    # Check if next line has find_isa
    nextline=$((linenum + 1))
    if sed -n "${nextline}p" "$CMAKE_FILE" | grep -q "find_isa"; then
        echo "$linenum"
        break
    fi
done)

if [ -n "$ELSE_LINE" ]; then
    echo "Found feature detection else() at line $ELSE_LINE"

    # Replace else() with elseif for ARM64 Linux
    ARM64_ELSEIF='elseif(VLLM_ARM64_LINUX)
    # ARM64 Linux - set features directly (CPUINFO already set above)
    message(STATUS "ARM64 Linux: Using pre-configured feature flags")
    set(ASIMD_FOUND ON)
    set(ARM_BF16_FOUND OFF)
    set(AVX2_FOUND OFF)
    set(AVX512_FOUND OFF)
    set(AVX512_DISABLED ON)
    set(POWER9_FOUND OFF)
    set(POWER10_FOUND OFF)
    set(POWER11_FOUND OFF)
    set(S390_FOUND OFF)
    set(RVV_FOUND OFF)
else()'

    # Use awk for reliable multi-line replacement
    awk -v line="$ELSE_LINE" -v replacement="$ARM64_ELSEIF" '
        NR == line { print replacement; next }
        { print }
    ' "$CMAKE_FILE" > "${CMAKE_FILE}.tmp"
    mv "${CMAKE_FILE}.tmp" "$CMAKE_FILE"
else
    echo "Warning: Could not find feature detection else() block"
fi

echo ""
echo "=== Patch Applied ==="
echo ""

# Verification
echo "Checking patch results..."

if grep -q "VLLM_ARM64_LINUX" "$CMAKE_FILE"; then
    echo "✓ ARM64 detection variable added"
else
    echo "✗ ERROR: ARM64 detection not found!"
    cat "$CMAKE_FILE"
    exit 1
fi

if grep -q "NOT VLLM_ARM64_LINUX" "$CMAKE_FILE"; then
    echo "✓ /proc/cpuinfo check is guarded"
else
    echo "✗ WARNING: /proc/cpuinfo guard may not be applied"
fi

if grep -q "elseif(VLLM_ARM64_LINUX)" "$CMAKE_FILE"; then
    echo "✓ ARM64 Linux feature detection added"
else
    echo "! Note: elseif block may not be needed for this version"
fi

echo ""
echo "=== Patched file preview ==="
echo "--- First 40 lines ---"
head -40 "$CMAKE_FILE"
echo ""
echo "--- /proc/cpuinfo section ---"
grep -n -B2 -A5 "NOT MACOSX_FOUND" "$CMAKE_FILE" | head -15
