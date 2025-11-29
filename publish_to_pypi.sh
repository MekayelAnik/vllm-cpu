#!/usr/bin/env bash
#
# Publish vLLM CPU wheels to PyPI
#
# Version: 2.0.0
# Bash Version Required: 4.0+
#
# Usage:
#   ./publish_to_pypi.sh [OPTIONS]
#
# Options:
#   --test                   Publish to Test PyPI instead
#   --dist-dir=PATH          Directory containing wheels (default: ./dist)
#   --skip-build             Skip building, just publish existing wheels
#   --variant=NAME           Only publish specific variant
#   --help                   Show this help

# Check Bash version (require 4.0+)
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: This script requires Bash 4.0 or higher" >&2
    echo "Current version: ${BASH_VERSION}" >&2
    exit 1
fi

# Bash strict mode
set -euo pipefail
IFS=$'\n\t'

# Script metadata
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="2.0.0"

# Color codes (readonly)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging configuration
readonly LOG_TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'

# Configuration
TEST_PYPI=0
DIST_DIR="./dist"
SKIP_BUILD=0
VARIANT=""
PYPI_TOKEN=""
TEST_PYPI_TOKEN=""

# Cleanup state
CLEANUP_DONE=0

# Enhanced logging functions
log_info() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${GREEN}[SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] ${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "$(date +"$LOG_TIMESTAMP_FORMAT") [$$] [DEBUG] $*" >&2
    fi
}

# Enhanced cleanup function
cleanup() {
    local exit_code=$?

    # Prevent double execution
    if [[ "$CLEANUP_DONE" -eq 1 ]]; then
        return
    fi
    CLEANUP_DONE=1

    # Reset traps
    trap - EXIT ERR INT TERM

    # Clear any tokens from environment
    unset PYPI_TOKEN TEST_PYPI_TOKEN PYPI_API_TOKEN TEST_PYPI_API_TOKEN

    exit "$exit_code"
}

# Set trap for cleanup
trap cleanup EXIT

# Validate path to prevent directory traversal
validate_path() {
    local path="$1"
    local description="$2"

    # Resolve to absolute path
    local resolved_path
    if ! resolved_path=$(realpath -m "$path" 2>/dev/null); then
        log_error "Invalid path for $description: $path"
        return 1
    fi

    # Check for directory traversal attempts
    if [[ "$resolved_path" == *".."* ]]; then
        log_error "Directory traversal detected in $description: $path"
        return 1
    fi

    printf '%s' "$resolved_path"
    return 0
}

# Validate variant name
validate_variant() {
    local variant="$1"

    if ! [[ "$variant" =~ ^vllm-cpu(-[a-z0-9]+)?$ ]]; then
        log_error "Invalid variant name format: $variant"
        log_info "Expected format: vllm-cpu or vllm-cpu-avx512, etc."
        return 1
    fi

    return 0
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                TEST_PYPI=1
                shift
                ;;
            --dist-dir=*)
                DIST_DIR="${1#*=}"
                local validated_path
                if ! validated_path=$(validate_path "$DIST_DIR" "dist-dir"); then
                    exit 1
                fi
                DIST_DIR="$validated_path"
                shift
                ;;
            --skip-build)
                SKIP_BUILD=1
                shift
                ;;
            --variant=*)
                VARIANT="${1#*=}"
                if ! validate_variant "$VARIANT"; then
                    exit 1
                fi
                shift
                ;;
            --help)
                grep '^#' "$0" | grep -v '#!/' | sed 's/^# //'
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    if ! command -v twine &> /dev/null; then
        log_error "twine is required. Install with: pip install twine"
        exit 1
    fi

    if ! command -v realpath &> /dev/null; then
        log_error "realpath is required but not found"
        exit 1
    fi
}

# Safely load environment file with STRICT permission check
safe_load_env() {
    local env_file=".env"

    if [[ ! -f "$env_file" ]]; then
        log_debug "No .env file found"
        return 0
    fi

    # STRICT permission check - FAIL on unsafe permissions
    local perms
    perms=$(stat -c '%a' "$env_file" 2>/dev/null || stat -f '%A' "$env_file" 2>/dev/null || echo "000")

    # Extract permission digits
    local owner_perm="${perms:0:1}"
    local group_perm="${perms:1:1}"
    local other_perm="${perms:2:1}"

    # FAIL if group or world can read
    if [[ "$group_perm" =~ [4567] ]] || [[ "$other_perm" =~ [4567] ]]; then
        log_error ".env file has UNSAFE permissions: $perms"
        log_error "Secrets file must be readable ONLY by owner"
        log_error "Required permissions: 600 (owner read/write only)"
        log_error "Fix with: chmod 600 $env_file"
        return 1
    fi

    # Warn if overly permissive owner permissions
    if [[ "$owner_perm" == "7" ]]; then
        log_warning ".env file is executable (permissions: $perms)"
        log_warning "Consider: chmod 600 $env_file"
    fi

    log_debug "Loading environment from $env_file"

    # Read and parse .env safely (only load specific variables)
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Only load specific token variables
        if [[ "$line" =~ ^PYPI_API_TOKEN[[:space:]]*=[[:space:]]*(.*) ]]; then
            PYPI_TOKEN="${BASH_REMATCH[1]}"
            log_debug "Loaded PYPI_API_TOKEN from .env"
        elif [[ "$line" =~ ^TEST_PYPI_API_TOKEN[[:space:]]*=[[:space:]]*(.*) ]]; then
            TEST_PYPI_TOKEN="${BASH_REMATCH[1]}"
            log_debug "Loaded TEST_PYPI_API_TOKEN from .env"
        fi
    done < "$env_file"

    return 0
}

# Validate token format
validate_token() {
    local token="$1"
    local token_name="$2"

    # PyPI tokens should start with pypi-
    if ! [[ "$token" =~ ^pypi- ]]; then
        log_error "$token_name does not appear to be a valid PyPI token"
        log_error "Expected format: starts with 'pypi-'"
        return 1
    fi

    # Check minimum length (PyPI tokens are quite long)
    if [[ ${#token} -lt 50 ]]; then
        log_error "$token_name appears too short to be valid"
        log_error "PyPI tokens are typically 80+ characters"
        return 1
    fi

    return 0
}

# Load PyPI tokens
load_tokens() {
    log_info "Loading PyPI credentials..."

    # Try to load from environment first
    if [[ -n "${PYPI_API_TOKEN:-}" ]]; then
        PYPI_TOKEN="$PYPI_API_TOKEN"
        log_debug "Loaded PYPI_API_TOKEN from environment"
    fi

    if [[ -n "${TEST_PYPI_API_TOKEN:-}" ]]; then
        TEST_PYPI_TOKEN="$TEST_PYPI_API_TOKEN"
        log_debug "Loaded TEST_PYPI_API_TOKEN from environment"
    fi

    # Try to load from .env file (with STRICT permission check)
    if ! safe_load_env; then
        log_error "Failed to load .env file due to unsafe permissions"
        exit 1
    fi

    # Validate required token is present
    if [[ $TEST_PYPI -eq 1 ]]; then
        if [[ -z "$TEST_PYPI_TOKEN" ]]; then
            log_error "TEST_PYPI_API_TOKEN not found in environment or .env file"
            exit 1
        fi
        if ! validate_token "$TEST_PYPI_TOKEN" "TEST_PYPI_API_TOKEN"; then
            exit 1
        fi
        log_success "Test PyPI credentials validated"
    else
        if [[ -z "$PYPI_TOKEN" ]]; then
            log_error "PYPI_API_TOKEN not found in environment or .env file"
            exit 1
        fi
        if ! validate_token "$PYPI_TOKEN" "PYPI_API_TOKEN"; then
            exit 1
        fi
        log_success "PyPI credentials validated"
    fi
}

# Build wheels
build_wheels() {
    log_info "Building wheels..."

    if [[ ! -x "./build_wheels.sh" ]]; then
        log_error "build_wheels.sh not found or not executable"
        exit 1
    fi

    local -a build_args=("--output-dir=$DIST_DIR")

    if [[ -n "$VARIANT" ]]; then
        build_args+=("--variant=$VARIANT")
    fi

    if ! ./build_wheels.sh "${build_args[@]}"; then
        log_error "Wheel build failed"
        exit 1
    fi

    log_success "Wheels built"
}

# Validate wheels
validate_wheels() {
    log_info "Validating wheels..."

    if [[ ! -d "$DIST_DIR" ]]; then
        log_error "Distribution directory does not exist: $DIST_DIR"
        exit 1
    fi

    # Enable nullglob to handle no-match case
    shopt -s nullglob
    local wheels=("$DIST_DIR"/*.whl)
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        log_error "No wheels found in $DIST_DIR"
        exit 1
    fi

    log_info "Found ${#wheels[@]} wheel(s) to validate"

    # Check each wheel
    local failed=0
    local wheel
    for wheel in "${wheels[@]}"; do
        if [[ ! -f "$wheel" ]]; then
            log_warning "Not a file: $wheel"
            continue
        fi

        log_info "Checking $(basename "$wheel")..."
        if ! twine check "$wheel" 2>&1; then
            log_error "Validation failed for $wheel"
            failed=1
        fi
    done

    if [[ $failed -eq 1 ]]; then
        log_error "Some wheels failed validation"
        exit 1
    fi

    log_success "All wheels are valid"
}

# Validate wheel filename format and extract metadata
validate_wheel_metadata() {
    local wheel="$1"
    local basename
    basename=$(basename "$wheel")

    # Wheel filename format: {distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl
    # Example: vllm_cpu_avx512bf16-0.11.0-cp312-cp312-manylinux_2_17_x86_64.whl

    if ! [[ "$basename" =~ ^([a-zA-Z0-9_]+)-([0-9][0-9.]*[0-9])-(cp[0-9]+|py[0-9])-([a-z0-9_]+)-([a-z0-9_]+)\.whl$ ]]; then
        log_error "Invalid wheel filename format: $basename"
        log_error "Expected: {package}-{version}-{python}-{abi}-{platform}.whl"
        return 1
    fi

    local package_name="${BASH_REMATCH[1]}"
    local version="${BASH_REMATCH[2]}"
    local python_tag="${BASH_REMATCH[3]}"
    local abi_tag="${BASH_REMATCH[4]}"
    local platform_tag="${BASH_REMATCH[5]}"

    log_debug "Wheel metadata: package=$package_name version=$version python=$python_tag abi=$abi_tag platform=$platform_tag"

    # Convert underscores to hyphens for PyPI package name
    package_name=$(echo "$package_name" | tr '_' '-')

    echo "PACKAGE:$package_name|VERSION:$version|PYTHON:$python_tag|ABI:$abi_tag|PLATFORM:$platform_tag"
    return 0
}

# Publish wheels
publish_wheels() {
    local target
    if [[ $TEST_PYPI -eq 1 ]]; then
        target="Test PyPI"
    else
        target="PyPI"
    fi

    log_info "Publishing wheels to $target..."

    local -a repository_args=()
    local token=""

    if [[ $TEST_PYPI -eq 1 ]]; then
        repository_args=("--repository" "testpypi")
        token="$TEST_PYPI_TOKEN"
    else
        token="$PYPI_TOKEN"
    fi

    # Enable nullglob
    shopt -s nullglob
    local wheels=("$DIST_DIR"/*.whl)
    shopt -u nullglob

    if [[ ${#wheels[@]} -eq 0 ]]; then
        log_error "No wheels found in $DIST_DIR"
        exit 1
    fi

    log_info "Publishing ${#wheels[@]} wheel(s)..."

    # Validate all wheels before uploading
    log_info "Validating wheel metadata..."
    local wheel
    local validation_failed=0
    for wheel in "${wheels[@]}"; do
        if [[ ! -f "$wheel" ]]; then
            log_warning "Not a file: $wheel"
            continue
        fi

        local metadata
        if ! metadata=$(validate_wheel_metadata "$wheel"); then
            validation_failed=1
        else
            log_debug "$(basename "$wheel"): $metadata"
        fi
    done

    if [[ $validation_failed -eq 1 ]]; then
        log_error "Wheel metadata validation failed"
        exit 1
    fi
    log_success "All wheel metadata validated"

    # Publish each wheel
    for wheel in "${wheels[@]}"; do
        if [[ ! -f "$wheel" ]]; then
            log_warning "Not a file: $wheel"
            continue
        fi

        log_info "Uploading $(basename "$wheel")..."

        # Use temp file for password to avoid process exposure
        local temp_password
        temp_password=$(mktemp)
        chmod 600 "$temp_password"
        printf '%s' "$token" > "$temp_password"

        if twine upload \
            "${repository_args[@]}" \
            --username __token__ \
            --password "$(cat "$temp_password")" \
            --skip-existing \
            --non-interactive \
            "$wheel" 2>&1; then
            log_success "Uploaded $(basename "$wheel")"
        else
            local upload_exit=$?
            log_warning "Failed to upload $(basename "$wheel") (exit code: $upload_exit)"
            log_warning "This may be normal if the package already exists"
        fi

        # Clean up temp file immediately
        rm -f "$temp_password"
    done

    log_success "Publication complete"

    # Print upload summary
    log_info ""
    log_info "Upload Summary:"
    log_info "==============="
    for wheel in "${wheels[@]}"; do
        if [[ ! -f "$wheel" ]]; then
            continue
        fi
        local metadata
        if metadata=$(validate_wheel_metadata "$wheel" 2>/dev/null); then
            local package_name
            local version
            local python_tag
            package_name=$(echo "$metadata" | grep -oP 'PACKAGE:\K[^|]+')
            version=$(echo "$metadata" | grep -oP 'VERSION:\K[^|]+')
            python_tag=$(echo "$metadata" | grep -oP 'PYTHON:\K[^|]+')
            log_info "  ✓ $package_name == $version ($python_tag)"
        else
            log_info "  ✗ $(basename "$wheel") - validation failed"
        fi
    done
    log_info "==============="
}

# Print summary
print_summary() {
    local target
    if [[ $TEST_PYPI -eq 1 ]]; then
        target='Test PyPI'
    else
        target='PyPI'
    fi

    log_success "All wheels published to $target!"
    echo ""
    echo "=========================================="
    echo "Published Packages:"
    echo "=========================================="

    # Enable nullglob
    shopt -s nullglob
    local wheels=("$DIST_DIR"/*.whl)
    shopt -u nullglob

    local wheel
    for wheel in "${wheels[@]}"; do
        local basename
        basename=$(basename "$wheel")
        local package_name
        package_name=$(echo "$basename" | cut -d'-' -f1-2)
        echo "  - $package_name"
    done

    echo ""
    echo "=========================================="
    echo "Installation:"
    echo "=========================================="

    if [[ $TEST_PYPI -eq 1 ]]; then
        echo "  pip install --index-url https://test.pypi.org/simple/ vllm-cpu-*"
    else
        echo "  # Detect CPU and install optimal package"
        echo "  pip install vllm-cpu-detect"
        echo "  vllm-cpu-detect"
        echo ""
        echo "  # Or install specific variant"
        echo "  pip install vllm-cpu-avx512bf16"
    fi

    echo ""
}

# Main
main() {
    log_info "Starting vLLM CPU PyPI publisher v${SCRIPT_VERSION}"
    log_debug "Script: $SCRIPT_DIR/$SCRIPT_NAME"
    log_debug "Bash version: ${BASH_VERSION}"

    parse_args "$@"
    check_dependencies
    load_tokens

    # Build if needed
    if [[ $SKIP_BUILD -eq 0 ]]; then
        build_wheels
    else
        log_info "Skipping build (--skip-build)"
    fi

    # Validate wheels
    validate_wheels

    # Publish
    publish_wheels

    # Print summary
    print_summary
}

main "$@"
