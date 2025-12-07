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

    # Try PyPI first unless explicitly requesting GitHub release
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
    else
        echo "GitHub release mode enabled - skipping PyPI"
    fi

    # Try GitHub release if PyPI failed or GitHub release is explicitly requested
    if [ "${_install_success}" = "false" ]; then
        echo "Trying GitHub release..."

        PYTHON_TAG="cp$(echo "${_try_py_version}" | tr -d '.')"
        PACKAGE_NAME_UNDERSCORE=$(echo "${PACKAGE_NAME}" | tr '-' '_')

        # Build list of release tags to try:
        # 1. Full version as-is (e.g., v0.12.0 or v0.12.0.post1)
        # 2. For base versions: also try .post1, .post2, .post3 suffixes
        # 3. For postfix versions: also try base version and other postfixes
        BASE_VERSION=$(echo "${VLLM_VERSION}" | sed 's/\.\(post\|dev\|rc\|a\|b\)[0-9]*$//')
        RELEASE_TAGS="v${VLLM_VERSION}"
        # Add base version and postfix variants, avoiding duplicates
        for tag in "v${BASE_VERSION}" "v${BASE_VERSION}.post1" "v${BASE_VERSION}.post2" "v${BASE_VERSION}.post3"; do
            case " ${RELEASE_TAGS} " in
                *" ${tag} "*) ;;  # Already in list, skip
                *) RELEASE_TAGS="${RELEASE_TAGS} ${tag}" ;;
            esac
        done

        RELEASE_ASSETS=""
        for RELEASE_TAG in ${RELEASE_TAGS}; do
            echo "Querying GitHub API for release ${RELEASE_TAG}..."

            # Query GitHub API for available wheels in this release
            RELEASE_ASSETS=$(wget -q -O - \
                "https://api.github.com/repos/MekayelAnik/vllm-cpu/releases/tags/${RELEASE_TAG}" 2>/dev/null | \
                grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' | \
                sed 's/"browser_download_url"[[:space:]]*:[[:space:]]*"//;s/"$//' || echo "")

            if [ -n "${RELEASE_ASSETS}" ]; then
                echo "Found release: ${RELEASE_TAG}"
                break
            else
                echo "Release ${RELEASE_TAG} not found, trying next..."
            fi
        done

        if [ -z "${RELEASE_ASSETS}" ]; then
            echo "Failed to fetch release assets from GitHub API (tried: ${RELEASE_TAGS})"
        else
            echo "Found release assets, searching for matching wheel..."

            # Find wheel matching: package name, Python version, and architecture
            # Pattern: vllm_cpu-VERSION-cpXXX-cpXXX-*ARCH*.whl
            WHEEL_URL=""
            for asset_url in ${RELEASE_ASSETS}; do
                asset_name=$(basename "${asset_url}")
                # Check if this wheel matches our criteria
                case "${asset_name}" in
                    ${PACKAGE_NAME_UNDERSCORE}-*-${PYTHON_TAG}-${PYTHON_TAG}-*${WHEEL_ARCH}*.whl)
                        WHEEL_URL="${asset_url}"
                        WHEEL_NAME="${asset_name}"
                        echo "Found matching wheel: ${WHEEL_NAME}"
                        break
                        ;;
                esac
            done

            if [ -n "${WHEEL_URL}" ]; then
                echo "Installing from: ${WHEEL_URL}"

                # Use single pip install command with URL (PEP 440 style)
                # This installs the wheel directly with all dependencies from CPU PyTorch index
                if uv pip install --no-progress \
                    "${PACKAGE_NAME} @ ${WHEEL_URL}" \
                    --index-url "${PYTORCH_INDEX}" \
                    --extra-index-url "${PYPI_INDEX}" \
                    --index-strategy unsafe-best-match; then
                    echo "Successfully installed ${PACKAGE_NAME} from GitHub release"
                    _install_success=true
                else
                    echo "Failed to install from GitHub release URL, trying download method..."

                    # Fallback: download wheel and install locally
                    if wget -q "${WHEEL_URL}" -O "/tmp/${WHEEL_NAME}" 2>/dev/null; then
                        echo "Downloaded: ${WHEEL_NAME}"
                        if uv pip install --no-progress "/tmp/${WHEEL_NAME}" \
                            --index-url "${PYTORCH_INDEX}" \
                            --extra-index-url "${PYPI_INDEX}" \
                            --index-strategy unsafe-best-match; then
                            rm -f "/tmp/${WHEEL_NAME}"
                            echo "Successfully installed from downloaded wheel"
                            _install_success=true
                        else
                            rm -f "/tmp/${WHEEL_NAME}"
                            echo "Failed to install downloaded wheel"
                        fi
                    fi
                fi
            else
                echo "No matching wheel found for ${PACKAGE_NAME_UNDERSCORE} Python ${PYTHON_TAG} ${WHEEL_ARCH}"
            fi
        fi
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
# Create vllm package alias for platform detection
# =============================================================================
# vLLM's platform detection uses `importlib.metadata.version("vllm")` to check
# if the package contains "cpu" in its version string. Since our packages are
# named "vllm-cpu", "vllm-cpu-avx512", etc., we need to create a symlink so
# that version("vllm") returns the correct version with "cpu" in it.
echo ""
echo "=== Creating vllm package alias ==="
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
VLLM_CPU_DIST=$(find "${SITE_PACKAGES}" -maxdepth 1 -type d -name "vllm_cpu*.dist-info" | head -1)
if [ -n "${VLLM_CPU_DIST}" ] && [ -d "${VLLM_CPU_DIST}" ]; then
    VLLM_DIST="${SITE_PACKAGES}/vllm-0.0.0.dist-info"
    if [ ! -d "${VLLM_DIST}" ]; then
        # Create a minimal dist-info for "vllm" that returns the cpu version
        mkdir -p "${VLLM_DIST}"
        # Copy METADATA but change the Name to "vllm"
        if [ -f "${VLLM_CPU_DIST}/METADATA" ]; then
            # Get the version from the original package and ensure it contains "cpu"
            VLLM_VERSION=$(grep "^Version:" "${VLLM_CPU_DIST}/METADATA" | cut -d: -f2 | tr -d ' ')
            # Append +cpu if not already present (required for platform detection)
            # Use POSIX case statement instead of bash [[ ]] for /bin/sh compatibility
            case "${VLLM_VERSION}" in
                *cpu*) ;; # already contains "cpu", do nothing
                *) VLLM_VERSION="${VLLM_VERSION}+cpu" ;;
            esac
            cat > "${VLLM_DIST}/METADATA" << EOF
Metadata-Version: 2.1
Name: vllm
Version: ${VLLM_VERSION}
Summary: vLLM CPU package alias for platform detection
EOF
            echo "Created vllm package alias with version: ${VLLM_VERSION}"
        fi
    fi
else
    echo "WARNING: Could not find vllm-cpu dist-info directory"
fi

# =============================================================================
# Fix opentelemetry context issue (Python 3.12+ compatibility)
# =============================================================================
# The opentelemetry-api package has a StopIteration bug with Python 3.12+ when
# entry_points aren't properly registered during package installation. This
# causes "StopIteration" errors in _load_runtime_context() when importing vLLM.
#
# Root cause: The opentelemetry context/__init__.py uses next() on entry_points
# iterator which raises StopIteration when no entry points are found. This happens
# when entry_points.txt is missing or corrupted in the dist-info directory.
#
# Fix Strategy:
# 1. First try reinstalling opentelemetry packages
# 2. If that fails, manually create the entry_points.txt file
# 3. If still failing, patch the opentelemetry context/__init__.py directly
#
# References:
# - https://github.com/open-telemetry/opentelemetry-python/issues/3857
# - https://github.com/Azure/azure-sdk-for-python/issues/41535
echo ""
echo "=== Fixing opentelemetry compatibility ==="
if uv pip show opentelemetry-api >/dev/null 2>&1; then
    echo "Reinstalling opentelemetry packages for Python 3.12+ compatibility..."
    # Force reinstall to ensure entry_points are properly registered
    uv pip install --no-progress --force-reinstall \
        "opentelemetry-api>=1.25.0" \
        "opentelemetry-sdk>=1.25.0" \
        "opentelemetry-semantic-conventions>=0.46b0" \
        2>/dev/null || echo "opentelemetry reinstall skipped (packages may not be installed)"

    # Test if context loading works
    if python -c "from opentelemetry.context import get_current; get_current()" 2>/dev/null; then
        echo "opentelemetry context loading: OK"
    else
        echo "opentelemetry context loading failed, applying manual fix..."

        # Find the opentelemetry_api dist-info directory and ensure entry_points.txt exists
        OTEL_DIST=$(python -c "import site; import os; sp=site.getsitepackages()[0]; dirs=[d for d in os.listdir(sp) if d.startswith('opentelemetry_api') and d.endswith('.dist-info')]; print(os.path.join(sp, dirs[0]) if dirs else '')" 2>/dev/null)

        if [ -n "${OTEL_DIST}" ] && [ -d "${OTEL_DIST}" ]; then
            ENTRY_POINTS_FILE="${OTEL_DIST}/entry_points.txt"

            # Check if entry_points.txt exists and has the required entry
            if [ ! -f "${ENTRY_POINTS_FILE}" ] || ! grep -q "opentelemetry_context" "${ENTRY_POINTS_FILE}" 2>/dev/null; then
                echo "Creating/updating entry_points.txt in ${OTEL_DIST}..."

                # Create or append the required entry points
                cat >> "${ENTRY_POINTS_FILE}" << 'ENTRY_POINTS_EOF'

[opentelemetry_context]
contextvars_context = opentelemetry.context.contextvars_context:ContextVarsRuntimeContext
ENTRY_POINTS_EOF
                echo "entry_points.txt updated"
            fi
        fi

        # Verify the fix worked
        if python -c "from opentelemetry.context import get_current; get_current()" 2>/dev/null; then
            echo "opentelemetry context loading after manual fix: OK"
        else
            echo "WARNING: entry_points fix didn't work, patching context module directly..."

            # Final fix: Patch the opentelemetry/context/__init__.py file directly
            # This replaces the _load_runtime_context function with a robust version
            # Note: We can't import opentelemetry.context (it fails), so find the path manually
            OTEL_CONTEXT_INIT=$(python -c "import site; import os; sp=site.getsitepackages()[0]; p=os.path.join(sp,'opentelemetry','context'); print(p if os.path.isdir(p) else '')" 2>/dev/null || echo "")

            if [ -n "${OTEL_CONTEXT_INIT}" ] && [ -f "${OTEL_CONTEXT_INIT}/__init__.py" ]; then
                echo "Patching ${OTEL_CONTEXT_INIT}/__init__.py..."

                # Create a patched version that doesn't rely on entry_points
                python << PATCH_SCRIPT
import os
import sys

init_file = "${OTEL_CONTEXT_INIT}/__init__.py"

try:
    with open(init_file, 'r') as f:
        content = f.read()

    # Check if already patched
    if '_PATCHED_FOR_ENTRYPOINTS_' in content:
        print("Already patched")
        sys.exit(0)

    # The robust replacement function that handles missing entry_points
    patched_function = '''
# _PATCHED_FOR_ENTRYPOINTS_ - Patched to handle missing entry_points on ARM64/Python 3.12+
def _load_runtime_context() -> _RuntimeContext:
    """Initialize the RuntimeContext with fallback for missing entry_points."""
    from opentelemetry.context.contextvars_context import ContextVarsRuntimeContext

    default_context = "contextvars_context"
    configured_context = environ.get(OTEL_PYTHON_CONTEXT, default_context)

    # Try entry_points first
    try:
        eps = list(entry_points(group="opentelemetry_context", name=configured_context))
        if eps:
            return eps[0].load()()
    except Exception:
        pass

    # Fallback: directly instantiate ContextVarsRuntimeContext
    return ContextVarsRuntimeContext()

'''

    # Find and replace the existing _load_runtime_context function
    import re

    # Pattern to match the entire function definition
    # Matches from 'def _load_runtime_context' to just before '_RUNTIME_CONTEXT ='
    pattern = r'def _load_runtime_context\(\)[^\n]*\n(?:.*?\n)*?(?=_RUNTIME_CONTEXT\s*=)'

    if re.search(pattern, content):
        content = re.sub(pattern, patched_function, content)
        print(f"Replaced _load_runtime_context function")
    else:
        # Alternative: just insert our function before _RUNTIME_CONTEXT and comment out old one
        old_func_start = content.find('def _load_runtime_context()')
        if old_func_start != -1:
            # Comment out the old function by adding # to each line until _RUNTIME_CONTEXT
            runtime_ctx_pos = content.find('_RUNTIME_CONTEXT = _load_runtime_context()')
            if runtime_ctx_pos > old_func_start:
                old_func = content[old_func_start:runtime_ctx_pos]
                commented = '\n'.join('# ' + line for line in old_func.split('\n'))
                content = content[:old_func_start] + patched_function + commented + content[runtime_ctx_pos:]
                print("Inserted patched function and commented old one")

    with open(init_file, 'w') as f:
        f.write(content)

    print(f"Successfully patched {init_file}")

except Exception as e:
    print(f"Patch failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PATCH_SCRIPT

                # Verify the patch worked
                if python -c "from opentelemetry.context import get_current; get_current()" 2>/dev/null; then
                    echo "opentelemetry context loading after direct patch: OK"
                else
                    echo "ERROR: All opentelemetry fixes failed"
                fi
            else
                echo "ERROR: Could not locate opentelemetry context module"
            fi
        fi
    fi
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
