#!/usr/bin/env bash
#
# Verification script to check that build cleanup is working properly
# This script checks disk usage before and after a wheel build
#

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

echo "=========================================="
echo "Build Cleanup Verification Script"
echo "=========================================="
echo

# Function to get disk usage
get_disk_usage() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sb "$path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Function to format bytes
format_bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt $((1024*1024)) ]]; then
        echo "$((bytes/1024))KB"
    elif [[ $bytes -lt $((1024*1024*1024)) ]]; then
        echo "$((bytes/1024/1024))MB"
    else
        echo "$((bytes/1024/1024/1024))GB"
    fi
}

# Paths to check
WORKSPACE="${WORKSPACE:-./build}"
HOME_CACHE="$HOME/.cache"
HOME_LOCAL="$HOME/.local/share"
TMP_DIR="/tmp"

echo "Checking disk usage BEFORE build..."
echo "-----------------------------------"

# Get initial sizes
workspace_before=$(get_disk_usage "$WORKSPACE")
uv_cache_before=$(get_disk_usage "$HOME/.cache/uv")
pip_cache_before=$(get_disk_usage "$HOME/.cache/pip")
uv_local_before=$(get_disk_usage "$HOME/.local/share/uv")

echo "Workspace: $(format_bytes $workspace_before) ($WORKSPACE)"
echo "uv cache: $(format_bytes $uv_cache_before) (~/.cache/uv)"
echo "pip cache: $(format_bytes $pip_cache_before) (~/.cache/pip)"
echo "uv local: $(format_bytes $uv_local_before) (~/.local/share/uv)"

# Count temp files
tmp_files_before=$(find /tmp -maxdepth 1 \( -name "pip-*" -o -name "tmp*vllm*" -o -name "tmp*wheel*" -o -name "tmp*build*" \) 2>/dev/null | wc -l)
echo "Temp files in /tmp: $tmp_files_before"
echo

# Wait for user to run build
echo "=========================================="
echo "Now run your build command, for example:"
echo "  ./build_wheels.sh --variant=noavx512 --python-versions=3.12"
echo "=========================================="
echo
read -p "Press ENTER when build is complete..."
echo

# Get final sizes
echo "Checking disk usage AFTER build..."
echo "-----------------------------------"

workspace_after=$(get_disk_usage "$WORKSPACE")
uv_cache_after=$(get_disk_usage "$HOME/.cache/uv")
pip_cache_after=$(get_disk_usage "$HOME/.cache/pip")
uv_local_after=$(get_disk_usage "$HOME/.local/share/uv")

echo "Workspace: $(format_bytes $workspace_after) ($WORKSPACE)"
echo "uv cache: $(format_bytes $uv_cache_after) (~/.cache/uv)"
echo "pip cache: $(format_bytes $pip_cache_after) (~/.cache/pip)"
echo "uv local: $(format_bytes $uv_local_after) (~/.local/share/uv)"

# Count temp files
tmp_files_after=$(find /tmp -maxdepth 1 \( -name "pip-*" -o -name "tmp*vllm*" -o -name "tmp*wheel*" -o -name "tmp*build*" \) 2>/dev/null | wc -l)
echo "Temp files in /tmp: $tmp_files_after"
echo

# Calculate changes
workspace_change=$((workspace_after - workspace_before))
uv_cache_change=$((uv_cache_after - uv_cache_before))
pip_cache_change=$((pip_cache_after - pip_cache_before))
uv_local_change=$((uv_local_after - uv_local_before))
tmp_files_change=$((tmp_files_after - tmp_files_before))

# Show results
echo "=========================================="
echo "RESULTS"
echo "=========================================="

success=1

if [[ $workspace_change -lt $((10*1024*1024)) ]]; then  # Less than 10MB change
    echo -e "${GREEN}✓ PASS${NC} - Workspace change: $(format_bytes $workspace_change) (acceptable)"
else
    echo -e "${RED}✗ FAIL${NC} - Workspace change: $(format_bytes $workspace_change) (too large!)"
    success=0
fi

if [[ $uv_cache_change -lt $((50*1024*1024)) ]]; then  # Less than 50MB change
    echo -e "${GREEN}✓ PASS${NC} - uv cache change: $(format_bytes $uv_cache_change) (acceptable)"
else
    echo -e "${YELLOW}⚠ WARN${NC} - uv cache change: $(format_bytes $uv_cache_change) (might need manual cleanup)"
fi

if [[ $pip_cache_change -lt $((50*1024*1024)) ]]; then  # Less than 50MB change
    echo -e "${GREEN}✓ PASS${NC} - pip cache change: $(format_bytes $pip_cache_change) (acceptable)"
else
    echo -e "${YELLOW}⚠ WARN${NC} - pip cache change: $(format_bytes $pip_cache_change) (might need manual cleanup)"
fi

if [[ $tmp_files_change -le 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC} - Temp files cleaned up (change: $tmp_files_change)"
else
    echo -e "${YELLOW}⚠ WARN${NC} - Temp files increased by: $tmp_files_change"
fi

echo
echo "=========================================="

if [[ $success -eq 1 ]]; then
    echo -e "${GREEN}Overall: CLEANUP IS WORKING!${NC}"
    echo "Disk space is being properly reclaimed after each wheel build."
else
    echo -e "${RED}Overall: CLEANUP NEEDS ATTENTION${NC}"
    echo "Workspace is accumulating too much data."
fi

echo "=========================================="
