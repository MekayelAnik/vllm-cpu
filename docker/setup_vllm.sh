#!/bin/sh
# =============================================================================
# setup_vllm.sh - Install Python and vLLM package with version fallback
# =============================================================================
# This script handles Python installation via uv and vLLM package installation
# from PyPI with fallback to GitHub releases. If installation fails, it falls
# back to lower Python versions (3.13 → 3.12 → 3.11 → 3.10 → 3.9).
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

# Detect architecture
ARCH=$(uname -m)
case "${ARCH}" in
    x86_64) WHEEL_ARCH="x86_64" ;;
    aarch64) WHEEL_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: ${ARCH}" >&2 && exit 1 ;;
esac

echo "=== vLLM Setup ==="
echo "Variant: ${VARIANT}"
echo "Package: ${PACKAGE_NAME}"
echo "Version: ${VLLM_VERSION}"
echo "Architecture: ${WHEEL_ARCH}"
echo ""

# =============================================================================
# Helper Functions
# =============================================================================

# Install Python and create virtual environment
# Arguments: $1 = Python version (e.g., "3.13")
# Returns: 0 on success, 1 on failure
install_python() {
    _py_version="$1"
    echo "Installing Python ${_py_version}..."

    # Clean up any existing venv
    rm -rf /vllm/venv

    # Install Python via uv (temporarily allow downloads)
    if ! UV_PYTHON_DOWNLOADS=automatic uv python install "${_py_version}"; then
        echo "Failed to install Python ${_py_version}"
        return 1
    fi

    if ! uv venv /vllm/venv --python "${_py_version}"; then
        echo "Failed to create venv for Python ${_py_version}"
        return 1
    fi

    # Set up environment for installation
    export VIRTUAL_ENV=/vllm/venv
    export PATH="/vllm/venv/bin:$PATH"

    echo "Python ${_py_version} installed successfully"
    return 0
}

# Try to install vLLM package
# Arguments: $1 = Python version
# Returns: 0 on success, 1 on failure
try_install_vllm() {
    _try_py_version="$1"
    _install_success=false

    echo ""
    echo "=== Attempting vLLM installation for Python ${_try_py_version} ==="

    # Try PyPI first unless explicitly requesting GitHub
    if [ "${USE_GITHUB_RELEASE}" != "true" ]; then
        echo "Attempting PyPI installation with CPU-only PyTorch..."

        # Try base version first, then .post1, .post2, .post3
        for VERSION_SUFFIX in "" ".post1" ".post2" ".post3"; do
            INSTALL_VERSION="${VLLM_VERSION}${VERSION_SUFFIX}"
            echo "Trying ${PACKAGE_NAME}==${INSTALL_VERSION}..."

            if uv pip install --no-progress "${PACKAGE_NAME}==${INSTALL_VERSION}" \
                --index-url "${PYTORCH_INDEX}" \
                --extra-index-url "${PYPI_INDEX}" \
                --index-strategy unsafe-best-match 2>/dev/null; then
                echo "Successfully installed ${PACKAGE_NAME}==${INSTALL_VERSION} from PyPI"
                _install_success=true
                break
            else
                echo "Failed: ${INSTALL_VERSION}"
            fi
        done
    fi

    # Fallback to GitHub release if PyPI failed
    if [ "${_install_success}" = "false" ]; then
        echo "Trying GitHub release..."

        PYTHON_TAG="cp$(echo "${_try_py_version}" | tr -d '.')"
        PACKAGE_NAME_UNDERSCORE=$(echo "${PACKAGE_NAME}" | tr '-' '_')

        for VERSION_SUFFIX in "" ".post1" ".post2" ".post3"; do
            INSTALL_VERSION="${VLLM_VERSION}${VERSION_SUFFIX}"
            WHEEL_NAME="${PACKAGE_NAME_UNDERSCORE}-${INSTALL_VERSION}-${PYTHON_TAG}-${PYTHON_TAG}-manylinux_2_17_${WHEEL_ARCH}.manylinux2014_${WHEEL_ARCH}.whl"
            WHEEL_URL="https://github.com/MekayelAnik/vllm-cpu/releases/download/v${VLLM_VERSION}/${WHEEL_NAME}"

            echo "Trying wheel: ${WHEEL_NAME}"
            if wget -q "${WHEEL_URL}" -O "/tmp/${WHEEL_NAME}" 2>/dev/null; then
                echo "Downloaded: ${WHEEL_NAME}"

                # Install with CPU-only PyTorch index for dependencies
                if uv pip install --no-progress "/tmp/${WHEEL_NAME}" \
                    --index-url "${PYTORCH_INDEX}" \
                    --extra-index-url "${PYPI_INDEX}" \
                    --index-strategy unsafe-best-match 2>/dev/null; then
                    rm -f "/tmp/${WHEEL_NAME}"
                    echo "Successfully installed from GitHub release"
                    _install_success=true
                    break
                else
                    rm -f "/tmp/${WHEEL_NAME}"
                    echo "Failed to install wheel dependencies"
                fi
            fi
        done
    fi

    if [ "${_install_success}" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Main Installation Logic with Python Version Fallback
# =============================================================================

# Read detected Python version
if [ ! -f /tmp/python_version.txt ]; then
    echo "ERROR: /tmp/python_version.txt not found" >&2
    echo "Run detect_python_version.sh first" >&2
    exit 1
fi

DETECTED_PY=$(cat /tmp/python_version.txt)
echo "Detected Python version: ${DETECTED_PY}"

# Build list of Python versions to try (starting with detected, then fallback)
# Extract minor version number
DETECTED_MINOR=$(echo "${DETECTED_PY}" | cut -d. -f2)

# Create fallback list: detected version, then decreasing versions down to 3.9
PYTHON_VERSIONS="${DETECTED_PY}"
MINOR=${DETECTED_MINOR}
while [ "${MINOR}" -gt 9 ]; do
    MINOR=$((MINOR - 1))
    PYTHON_VERSIONS="${PYTHON_VERSIONS} 3.${MINOR}"
done

echo "Python version fallback order: ${PYTHON_VERSIONS}"
echo ""

# Try each Python version
INSTALL_SUCCESS=false
FINAL_PY_VERSION=""

for PY_VERSION in ${PYTHON_VERSIONS}; do
    echo "============================================================"
    echo "Trying Python ${PY_VERSION}..."
    echo "============================================================"

    # Install Python
    if ! install_python "${PY_VERSION}"; then
        echo "Failed to install Python ${PY_VERSION}, trying next version..."
        continue
    fi

    # Try to install vLLM
    if try_install_vllm "${PY_VERSION}"; then
        INSTALL_SUCCESS=true
        FINAL_PY_VERSION="${PY_VERSION}"
        break
    else
        echo ""
        echo "vLLM installation failed for Python ${PY_VERSION}"
        if [ "${PY_VERSION}" != "3.9" ]; then
            echo "Falling back to lower Python version..."
        fi
    fi
done

# Check if installation succeeded
if [ "${INSTALL_SUCCESS}" = "false" ]; then
    echo "============================================================" >&2
    echo "ERROR: Could not install ${PACKAGE_NAME} ${VLLM_VERSION}" >&2
    echo "============================================================" >&2
    echo "Tried Python versions: ${PYTHON_VERSIONS}" >&2
    echo "Architecture: ${WHEEL_ARCH}" >&2
    echo "" >&2
    echo "Possible causes:" >&2
    echo "  - No wheel exists for any Python version on ${WHEEL_ARCH}" >&2
    echo "  - Package not yet published to PyPI" >&2
    echo "  - No GitHub release exists for this version" >&2
    echo "============================================================" >&2
    exit 1
fi

# Store final version for later reference
echo "${FINAL_PY_VERSION}" > /vllm/python_version.txt

if [ "${FINAL_PY_VERSION}" != "${DETECTED_PY}" ]; then
    echo ""
    echo "NOTE: Fell back from Python ${DETECTED_PY} to ${FINAL_PY_VERSION}"
fi

# =============================================================================
# Verify installation
# =============================================================================
echo ""
echo "=== Verifying Installation ==="

# Ensure we're using the correct venv
export VIRTUAL_ENV=/vllm/venv
export PATH="/vllm/venv/bin:$PATH"

python -c "import vllm; print(f'vLLM version: {vllm.__version__}')"
python -c "import vllm; print(vllm.__version__)" > /vllm/vllm_version.txt

echo ""
echo "=== Setup Complete ==="
echo "Python: ${FINAL_PY_VERSION}"
echo "vLLM: $(cat /vllm/vllm_version.txt)"
