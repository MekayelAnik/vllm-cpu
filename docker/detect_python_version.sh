#!/bin/sh
# =============================================================================
# detect_python_version.sh - Detect optimal Python version for vLLM CPU
# =============================================================================
# This script detects the highest Python version that has pre-built wheels
# available for the vllm-cpu package and ALL its pinned dependencies.
#
# Usage:
#   ./detect_python_version.sh <package_name> <vllm_version> [python_version] [use_github_release]
#
# Arguments:
#   package_name        - vllm-cpu package variant (e.g., vllm-cpu, vllm-cpu-avx512)
#   vllm_version        - Version of vLLM (e.g., 0.11.2)
#   python_version      - Optional: explicit Python version or "auto" (default: auto)
#   use_github_release  - Optional: "true" to check GitHub releases first (default: false)
#
# Output:
#   Prints the detected Python version (e.g., "3.12") to stdout
#   Writes the version to /python_version.txt
#
# Exit codes:
#   0 - Success
#   1 - Error (invalid arguments, network failure, etc.)
# =============================================================================

set -e

# =============================================================================
# Configuration
# =============================================================================
PACKAGE_NAME="${1:-vllm-cpu}"
VLLM_VERSION="${2:-}"
PYTHON_VERSION="${3:-auto}"
USE_GITHUB_RELEASE="${4:-false}"
OUTPUT_FILE="${5:-/python_version.txt}"

# Validate required arguments
if [ -z "${VLLM_VERSION}" ]; then
    echo "ERROR: VLLM_VERSION is required" >&2
    echo "Usage: $0 <package_name> <vllm_version> [python_version] [use_github_release]" >&2
    exit 1
fi

# Detect current architecture
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64) WHEEL_ARCH="x86_64" ;;
    aarch64) WHEEL_ARCH="aarch64" ;;
    *) WHEEL_ARCH="${ARCH}" ;;
esac

echo "=== Python Version Detection ===" >&2
echo "Package: ${PACKAGE_NAME}" >&2
echo "Version: ${VLLM_VERSION}" >&2
echo "Architecture: ${WHEEL_ARCH}" >&2
echo "" >&2

# =============================================================================
# Helper Functions
# =============================================================================

# Check if a wheel exists for a given package/version/python/arch combination
# Checks 4 different wheel patterns:
#   1. cpXX-cpXX-manylinux (Python-version-specific)
#   2. py*-none-any (Universal pure-Python)
#   3. py*-none-manylinux*_arch (Universal with platform binaries)
#   4. cpXX-abi3-manylinux (ABI3 stable ABI, where XX <= target)
check_wheel_available() {
    local wheel_list="$1"
    local python_minor="$2"
    local arch="$3"

    # Check 1: Python-version-specific wheels (cpXX-cpXX-manylinux*_arch)
    if echo "${wheel_list}" | tr ' ' '\n' | grep -q "cp3${python_minor}.*manylinux.*${arch}"; then
        return 0
    fi

    # Check 2: Universal pure-Python wheels (py3-none-any or py2.py3-none-any)
    if echo "${wheel_list}" | tr ' ' '\n' | grep -q "py.*-none-any"; then
        return 0
    fi

    # Check 3: Universal wheels with platform-specific binaries (py*-none-manylinux*_arch)
    # Examples: intel-openmp has py2.py3-none-manylinux1_x86_64
    if echo "${wheel_list}" | tr ' ' '\n' | grep -q "py.*-none-manylinux.*${arch}"; then
        return 0
    fi

    # Check 4: ABI3 stable ABI wheels (cpXY-abi3-manylinux*_arch where XY <= target)
    # Examples: tokenizers only provides cp39-abi3 wheels which work for 3.9+
    for abi3_wheel in $(echo "${wheel_list}" | tr ' ' '\n' | grep -E "cp3[0-9]+-abi3-manylinux.*${arch}" 2>/dev/null); do
        abi3_min=$(echo "${abi3_wheel}" | grep -oE 'cp3[0-9]+' | sed 's/cp3//')
        if [ -n "${abi3_min}" ] && [ "${abi3_min}" -le "${python_minor}" ]; then
            return 0
        fi
    done

    return 1
}

# Fetch wheel list for a package version from PyPI
fetch_wheel_list() {
    local pkg_name="$1"
    local pkg_version="$2"

    curl -sfL --max-time 10 "https://pypi.org/pypi/${pkg_name}/${pkg_version}/json" 2>/dev/null | \
        jq -r '.urls[].filename' 2>/dev/null | tr '\n' ' '
}

# =============================================================================
# Main Detection Logic
# =============================================================================

PYTHON_VER=""

# Method 1: Use explicit Python version if provided
if [ -n "${PYTHON_VERSION}" ] && [ "${PYTHON_VERSION}" != "auto" ]; then
    PYTHON_VER="${PYTHON_VERSION}"
    echo "Using explicitly specified Python version: ${PYTHON_VER}" >&2
fi

# Method 2: Check PyPI for available wheels (filtered by architecture)
if [ -z "${PYTHON_VER}" ] && [ "${USE_GITHUB_RELEASE}" != "true" ]; then
    echo "Checking PyPI for available ${WHEEL_ARCH} wheels..." >&2
    PYPI_JSON=$(curl -sfL --max-time 15 "https://pypi.org/pypi/${PACKAGE_NAME}/${VLLM_VERSION}/json" 2>/dev/null || echo "")
    if [ -n "${PYPI_JSON}" ]; then
        # Extract CPython versions from wheel filenames, filtering by architecture
        PYTHON_VER=$(echo "${PYPI_JSON}" | jq -r '.urls[].filename' 2>/dev/null | \
            grep "_${WHEEL_ARCH}" | \
            grep -oE 'cp3[0-9]+' | \
            sed 's/cp3/3./' | \
            sort -t. -k2 -n -r | \
            head -1 || echo "")
        if [ -n "${PYTHON_VER}" ]; then
            echo "Found highest CPython on PyPI for ${WHEEL_ARCH}: ${PYTHON_VER}" >&2
        fi
    fi
fi

# Method 3: Check GitHub releases if PyPI failed or was skipped
if [ -z "${PYTHON_VER}" ]; then
    echo "Checking GitHub releases for available ${WHEEL_ARCH} wheels..." >&2

    # Build list of release tags to try:
    # 1. Full version as-is (e.g., v0.12.0 or v0.12.0.post1)
    # 2. For base versions: also try .post1, .post2, .post3 suffixes
    # 3. For postfix versions: also try base version and other postfixes
    BASE_VERSION=$(echo "${VLLM_VERSION}" | sed 's/\.\(post\|dev\|rc\|a\|b\)[0-9]*$//')
    GH_RELEASE_TAGS="v${VLLM_VERSION}"
    # Add base version and postfix variants, avoiding duplicates
    for tag in "v${BASE_VERSION}" "v${BASE_VERSION}.post1" "v${BASE_VERSION}.post2" "v${BASE_VERSION}.post3"; do
        case " ${GH_RELEASE_TAGS} " in
            *" ${tag} "*) ;;  # Already in list, skip
            *) GH_RELEASE_TAGS="${GH_RELEASE_TAGS} ${tag}" ;;
        esac
    done

    # Build auth header if GITHUB_TOKEN is available (avoids rate limiting)
    GH_AUTH_HEADER=""
    if [ -n "${GITHUB_TOKEN}" ]; then
        GH_AUTH_HEADER="-H \"Authorization: Bearer ${GITHUB_TOKEN}\""
        echo "Using GitHub token for API requests" >&2
    fi

    for GH_TAG in ${GH_RELEASE_TAGS}; do
        echo "Trying GitHub release tag: ${GH_TAG}..." >&2
        GH_API="https://api.github.com/repos/MekayelAnik/vllm-cpu/releases/tags/${GH_TAG}"
        if [ -n "${GITHUB_TOKEN}" ]; then
            GH_JSON=$(curl -sfL --max-time 15 -H "Authorization: Bearer ${GITHUB_TOKEN}" "${GH_API}" 2>/dev/null || echo "")
        else
            GH_JSON=$(curl -sfL --max-time 15 "${GH_API}" 2>/dev/null || echo "")
        fi
        if [ -n "${GH_JSON}" ] && echo "${GH_JSON}" | jq -e '.assets' >/dev/null 2>&1; then
            PACKAGE_NAME_UNDERSCORE=$(echo "${PACKAGE_NAME}" | tr '-' '_')
            PYTHON_VER=$(echo "${GH_JSON}" | jq -r '.assets[].name' 2>/dev/null | \
                grep -E "^${PACKAGE_NAME_UNDERSCORE}" | \
                grep "_${WHEEL_ARCH}" | \
                grep -oE 'cp3[0-9]+' | \
                sed 's/cp3/3./' | \
                sort -t. -k2 -n -r | \
                head -1 || echo "")
            if [ -n "${PYTHON_VER}" ]; then
                echo "Found highest CPython on GitHub (${GH_TAG}) for ${WHEEL_ARCH}: ${PYTHON_VER}" >&2
                break
            fi
        else
            echo "Release ${GH_TAG} not found or has no assets" >&2
        fi
    done
fi

# Method 4: Fallback to pyproject.toml requires-python
if [ -z "${PYTHON_VER}" ]; then
    echo "No wheels found, checking vLLM pyproject.toml..." >&2
    PYPROJECT_URL="https://raw.githubusercontent.com/vllm-project/vllm/v${VLLM_VERSION}/pyproject.toml"
    REQUIRES_PYTHON=$(curl -sfL --max-time 15 "${PYPROJECT_URL}" 2>/dev/null | \
        grep -E '^requires-python' | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "")
    if echo "${REQUIRES_PYTHON}" | grep -qE '<[0-9]+\.[0-9]+'; then
        MAX_PY=$(echo "${REQUIRES_PYTHON}" | grep -oE '<[0-9]+\.[0-9]+' | head -1 | tr -d '<')
        MAX_MINOR=$(echo "${MAX_PY}" | cut -d. -f2)
        PYTHON_VER="3.$((MAX_MINOR - 1))"
        echo "Derived from requires-python (<${MAX_PY}): ${PYTHON_VER}" >&2
    fi
fi

# Method 5: Ultimate fallback
if [ -z "${PYTHON_VER}" ]; then
    PYTHON_VER="3.12"
    echo "All detection methods failed, using fallback: ${PYTHON_VER}" >&2
fi

# =============================================================================
# Dependency Wheel Verification
# =============================================================================
# Verify the vllm-cpu package AND ALL its pinned dependencies have wheels
# Some packages like xgrammar may lack wheels for newer Python versions

echo "" >&2
echo "=== Verifying Dependency Wheels ===" >&2

ORIGINAL_PY="${PYTHON_VER}"
PYTHON_MINOR=$(echo "${PYTHON_VER}" | cut -d. -f2)

# Fetch requires_dist from vllm-cpu to find ALL pinned versions
echo "Fetching ${PACKAGE_NAME}==${VLLM_VERSION} dependency versions..." >&2
VLLM_REQUIRES=$(curl -sfL --max-time 15 "https://pypi.org/pypi/${PACKAGE_NAME}/${VLLM_VERSION}/json" 2>/dev/null | \
    jq -r '.info.requires_dist[]' 2>/dev/null || echo "")

# Build list of critical dependencies with pinned versions
# Format: "package_name:version package_name:version ..."
CRITICAL_DEPS="${PACKAGE_NAME}:${VLLM_VERSION}"

# Determine our target platform for marker matching
if [ "${WHEEL_ARCH}" = "aarch64" ]; then
    OUR_PLATFORM="aarch64"
else
    OUR_PLATFORM="x86_64"
fi

# Process each pinned dependency line
# Filter by platform markers and skip optional extras
echo "${VLLM_REQUIRES}" | grep -E '^[a-zA-Z0-9._-]+==' | while read -r DEP_LINE; do
    # Skip optional "extra ==" dependencies
    if echo "${DEP_LINE}" | grep -q 'extra =='; then
        continue
    fi

    # Check platform markers
    if echo "${DEP_LINE}" | grep -q 'platform_machine'; then
        # Check for exclusion marker (!=)
        if echo "${DEP_LINE}" | grep -q 'platform_machine !='; then
            # Exclusion marker: skip only if OUR platform is excluded
            if [ "${OUR_PLATFORM}" = "aarch64" ]; then
                if echo "${DEP_LINE}" | grep -qE 'platform_machine != "(aarch64|arm64)"'; then
                    continue
                fi
            else
                if echo "${DEP_LINE}" | grep -q 'platform_machine != "x86_64"'; then
                    continue
                fi
            fi
        else
            # Inclusion marker (==): include only if our platform is listed
            if [ "${OUR_PLATFORM}" = "aarch64" ]; then
                if ! echo "${DEP_LINE}" | grep -qE "(aarch64|arm64)"; then
                    continue
                fi
            else
                if ! echo "${DEP_LINE}" | grep -q "x86_64"; then
                    continue
                fi
            fi
        fi
    fi

    # Extract package_name:version
    DEP_ENTRY=$(echo "${DEP_LINE}" | sed 's/^\([a-zA-Z0-9._-]*\)==\([^;, ]*\).*/\1:\2/')
    DEP_NAME=$(echo "${DEP_ENTRY}" | cut -d: -f1)
    DEP_VER=$(echo "${DEP_ENTRY}" | cut -d: -f2)
    if [ -n "${DEP_NAME}" ] && [ -n "${DEP_VER}" ]; then
        echo "${DEP_NAME}:${DEP_VER}"
    fi
done > /tmp/pinned_deps.txt

# Read deps from temp file (needed because while loop runs in subshell)
while read -r DEP_ENTRY; do
    if [ -n "${DEP_ENTRY}" ]; then
        CRITICAL_DEPS="${CRITICAL_DEPS} ${DEP_ENTRY}"
    fi
done < /tmp/pinned_deps.txt
rm -f /tmp/pinned_deps.txt

DEP_COUNT=$(echo "${CRITICAL_DEPS}" | wc -w | tr -d ' ')
echo "Found ${DEP_COUNT} pinned dependencies for ${WHEEL_ARCH} to check" >&2

# Fetch wheel lists for all critical dependencies
# Store as pipe-separated records: "pkg_name:wheel1 wheel2 wheel3|pkg_name:wheel1..."
DEP_WHEELS=""
for DEP_SPEC in ${CRITICAL_DEPS}; do
    DEP_NAME=$(echo "${DEP_SPEC}" | cut -d: -f1)
    DEP_VERSION=$(echo "${DEP_SPEC}" | cut -d: -f2)
    if [ -n "${DEP_VERSION}" ]; then
        DEP_WHEEL_LIST=$(fetch_wheel_list "${DEP_NAME}" "${DEP_VERSION}")
        DEP_WHEELS="${DEP_WHEELS}${DEP_NAME}:${DEP_WHEEL_LIST}|"
        WHEEL_COUNT=$(echo "${DEP_WHEEL_LIST}" | wc -w | tr -d ' ')
        echo "  ${DEP_NAME}==${DEP_VERSION}: ${WHEEL_COUNT} wheels" >&2
    fi
done

# Try current version, then fall back: 3.13 -> 3.12 -> 3.11 -> 3.10 -> 3.9
echo "" >&2
echo "Checking Python version compatibility..." >&2
while [ "${PYTHON_MINOR}" -ge 9 ]; do
    ALL_DEPS_OK=true
    MISSING_DEPS=""

    for DEP_SPEC in ${CRITICAL_DEPS}; do
        DEP_NAME=$(echo "${DEP_SPEC}" | cut -d: -f1)
        DEP_WHEEL_LIST=$(echo "${DEP_WHEELS}" | tr '|' '\n' | grep "^${DEP_NAME}:" | cut -d: -f2-)

        if [ -n "${DEP_WHEEL_LIST}" ]; then
            if ! check_wheel_available "${DEP_WHEEL_LIST}" "${PYTHON_MINOR}" "${WHEEL_ARCH}"; then
                ALL_DEPS_OK=false
                MISSING_DEPS="${MISSING_DEPS} ${DEP_NAME}"
            fi
        fi
    done

    if [ "${ALL_DEPS_OK}" = "true" ]; then
        if [ "3.${PYTHON_MINOR}" != "${ORIGINAL_PY}" ]; then
            echo "WARNING: Some dependencies lack wheels for Python ${ORIGINAL_PY} on ${WHEEL_ARCH}" >&2
            echo "Falling back to Python 3.${PYTHON_MINOR} for dependency compatibility" >&2
        else
            echo "All critical dependencies have ${WHEEL_ARCH} wheels for Python ${PYTHON_VER}" >&2
        fi
        PYTHON_VER="3.${PYTHON_MINOR}"
        break
    else
        echo "Python 3.${PYTHON_MINOR}: Missing ${WHEEL_ARCH} wheels for:${MISSING_DEPS}" >&2
    fi

    PYTHON_MINOR=$((PYTHON_MINOR - 1))
done

if [ "${PYTHON_MINOR}" -lt 9 ]; then
    echo "WARNING: No Python version found with all dependency wheels, using 3.9 as fallback" >&2
    PYTHON_VER="3.9"
fi

# =============================================================================
# Output
# =============================================================================
echo "" >&2
echo "=== Final Python version: ${PYTHON_VER} ===" >&2

# Write to file for Dockerfile consumption
echo "${PYTHON_VER}" > "${OUTPUT_FILE}"

# Output to stdout for command substitution
echo "${PYTHON_VER}"
