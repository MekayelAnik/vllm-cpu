#!/bin/sh
# =============================================================================
# setup_vllm.sh - Install Python and vLLM package
# =============================================================================
# This script handles Python installation via uv and vLLM package installation
# from PyPI with fallback to GitHub releases.
#
# Usage:
#   ./setup_vllm.sh <variant> <vllm_version> <use_github_release>
#
# Arguments:
#   variant             - CPU variant (noavx512, avx512, avx512vnni, avx512bf16, amxbf16)
#   vllm_version        - Version of vLLM (e.g., 0.11.2)
#   use_github_release  - "true" to prefer GitHub releases over PyPI
#
# Environment:
#   Expects /tmp/python_version.txt to contain the detected Python version
#   Expects uv to be installed at /usr/local/bin/uv
#
# Output:
#   - Installs Python and creates venv at /vllm/venv
#   - Installs vLLM package with all dependencies
#   - Creates /vllm/python_version.txt and /vllm/vllm_version.txt
#
# Exit codes:
#   0 - Success
#   1 - Error (invalid arguments, installation failure, etc.)
# =============================================================================

set -e

# =============================================================================
# Configuration
# =============================================================================
VARIANT="${1:-noavx512}"
VLLM_VERSION="${2:-}"
USE_GITHUB_RELEASE="${3:-false}"

# Validate required arguments
if [ -z "${VLLM_VERSION}" ]; then
    echo "ERROR: VLLM_VERSION is required" >&2
    echo "Usage: $0 <variant> <vllm_version> [use_github_release]" >&2
    exit 1
fi

# Map variant to package name
case "${VARIANT}" in
    noavx512) PACKAGE_NAME="vllm-cpu" ;;
    avx512) PACKAGE_NAME="vllm-cpu-avx512" ;;
    avx512vnni) PACKAGE_NAME="vllm-cpu-avx512vnni" ;;
    avx512bf16) PACKAGE_NAME="vllm-cpu-avx512bf16" ;;
    amxbf16) PACKAGE_NAME="vllm-cpu-amxbf16" ;;
    *) echo "Unknown variant: ${VARIANT}" >&2 && exit 1 ;;
esac

# Index URLs
PYTORCH_INDEX="https://download.pytorch.org/whl/cpu"
PYPI_INDEX="https://pypi.org/simple"

echo "=== vLLM Setup ==="
echo "Variant: ${VARIANT}"
echo "Package: ${PACKAGE_NAME}"
echo "Version: ${VLLM_VERSION}"
echo ""

# =============================================================================
# Step 1: Install Python via uv
# =============================================================================
echo "=== Step 1: Installing Python ==="

# Read detected Python version
if [ ! -f /tmp/python_version.txt ]; then
    echo "ERROR: /tmp/python_version.txt not found" >&2
    echo "Run detect_python_version.sh first" >&2
    exit 1
fi

DETECTED_PY=$(cat /tmp/python_version.txt)
echo "Installing Python ${DETECTED_PY}..."

# Temporarily allow Python downloads for installation
# (UV_PYTHON_DOWNLOADS=never is set in Dockerfile for pip installs only)
UV_PYTHON_DOWNLOADS=automatic uv python install "${DETECTED_PY}"
uv venv /vllm/venv --python "${DETECTED_PY}"

# Store version for later reference
echo "${DETECTED_PY}" > /vllm/python_version.txt
echo "Python ${DETECTED_PY} installed successfully"
echo ""

# =============================================================================
# Step 2: Install vLLM package
# =============================================================================
echo "=== Step 2: Installing vLLM ==="
echo "Installing ${PACKAGE_NAME} version ${VLLM_VERSION}..."

# Activate virtual environment for this script
export VIRTUAL_ENV=/vllm/venv
export PATH="/vllm/venv/bin:$PATH"

PYPI_SUCCESS=false
PYPI_LAST_ERROR=""

# Try PyPI first unless explicitly requesting GitHub
if [ "${USE_GITHUB_RELEASE}" = "true" ]; then
    echo "Using GitHub release as requested..."
else
    echo "Attempting PyPI installation with CPU-only PyTorch..."

    # Try base version first, then .post1, .post2, .post3
    for VERSION_SUFFIX in "" ".post1" ".post2" ".post3"; do
        INSTALL_VERSION="${VLLM_VERSION}${VERSION_SUFFIX}"
        echo "Trying ${PACKAGE_NAME}==${INSTALL_VERSION}..."

        if PYPI_LAST_ERROR=$(uv pip install "${PACKAGE_NAME}==${INSTALL_VERSION}" \
            --index-url "${PYTORCH_INDEX}" \
            --extra-index-url "${PYPI_INDEX}" \
            --index-strategy unsafe-best-match 2>&1); then
            echo "Successfully installed ${PACKAGE_NAME}==${INSTALL_VERSION} from PyPI"
            PYPI_SUCCESS=true
            break
        else
            echo "Failed: ${INSTALL_VERSION}"
        fi
    done

    if [ "${PYPI_SUCCESS}" = "false" ]; then
        echo "PyPI installation failed for all version variants."
        echo "Last error: ${PYPI_LAST_ERROR}"
        echo "Falling back to GitHub release..."
    fi
fi

# Fallback to GitHub release
if [ "${PYPI_SUCCESS}" = "false" ]; then
    echo "Downloading from GitHub release..."

    # Detect architecture
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64) WHEEL_ARCH="x86_64" ;;
        aarch64) WHEEL_ARCH="aarch64" ;;
        *) echo "Unsupported architecture: ${ARCH}" >&2 && exit 1 ;;
    esac

    # Use tr to remove dots from Python version (POSIX-compatible)
    PYTHON_TAG="cp$(echo "${DETECTED_PY}" | tr -d '.')"
    echo "Looking for wheel: Python ${DETECTED_PY} (${PYTHON_TAG}), Arch: ${WHEEL_ARCH}"

    # Try base version first, then .post1, .post2, .post3
    WHEEL_DOWNLOADED=false
    PACKAGE_NAME_UNDERSCORE=$(echo "${PACKAGE_NAME}" | tr '-' '_')

    for VERSION_SUFFIX in "" ".post1" ".post2" ".post3"; do
        INSTALL_VERSION="${VLLM_VERSION}${VERSION_SUFFIX}"
        WHEEL_NAME="${PACKAGE_NAME_UNDERSCORE}-${INSTALL_VERSION}-${PYTHON_TAG}-${PYTHON_TAG}-manylinux_2_17_${WHEEL_ARCH}.manylinux2014_${WHEEL_ARCH}.whl"
        WHEEL_URL="https://github.com/MekayelAnik/vllm-cpu/releases/download/v${VLLM_VERSION}/${WHEEL_NAME}"

        echo "Trying wheel: ${WHEEL_URL}"
        if wget -q "${WHEEL_URL}" -O "/tmp/${WHEEL_NAME}" 2>/dev/null; then
            echo "Downloaded: ${WHEEL_NAME}"
            WHEEL_DOWNLOADED=true
            break
        fi
    done

    if [ "${WHEEL_DOWNLOADED}" = "false" ]; then
        echo "============================================================" >&2
        echo "ERROR: Could not install ${PACKAGE_NAME} ${VLLM_VERSION}" >&2
        echo "============================================================" >&2
        echo "Python version: ${DETECTED_PY}" >&2
        echo "Architecture: ${WHEEL_ARCH}" >&2
        echo "" >&2
        echo "Tried:" >&2
        echo "  1. PyPI: ${PACKAGE_NAME}==${VLLM_VERSION} (and .post1/.post2/.post3)" >&2
        echo "  2. GitHub: v${VLLM_VERSION} release wheels" >&2
        echo "" >&2
        echo "Possible causes:" >&2
        echo "  - No wheel exists for Python ${DETECTED_PY} on ${WHEEL_ARCH}" >&2
        echo "  - Package not yet published to PyPI" >&2
        echo "  - No GitHub release exists for this version" >&2
        echo "============================================================" >&2
        exit 1
    fi

    # Install with CPU-only PyTorch index for dependencies
    uv pip install "/tmp/${WHEEL_NAME}" \
        --index-url "${PYTORCH_INDEX}" \
        --extra-index-url "${PYPI_INDEX}" \
        --index-strategy unsafe-best-match

    rm -f "/tmp/${WHEEL_NAME}"
    echo "Successfully installed from GitHub release with CPU-only PyTorch"
fi

# =============================================================================
# Step 3: Verify installation
# =============================================================================
echo ""
echo "=== Step 3: Verifying Installation ==="

python -c "import vllm; print(f'vLLM version: {vllm.__version__}')"
python -c "import vllm; print(vllm.__version__)" > /vllm/vllm_version.txt

echo ""
echo "=== Setup Complete ==="
echo "Python: ${DETECTED_PY}"
echo "vLLM: $(cat /vllm/vllm_version.txt)"
