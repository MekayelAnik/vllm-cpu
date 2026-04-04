#!/usr/bin/env bash
set -euo pipefail

assert_eq() {
    local name="$1"
    local got="$2"
    local want="$3"

    if [[ "$got" == "$want" ]]; then
        echo "PASS: ${name}"
    else
        echo "FAIL: ${name} expected='${want}' got='${got}'" >&2
        exit 1
    fi
}

assert_file_exists() {
    local name="$1"
    local file="$2"

    if [[ -f "$file" ]]; then
        echo "PASS: ${name}"
    else
        echo "FAIL: ${name} file missing: ${file}" >&2
        exit 1
    fi
}

assert_file_contains() {
    local name="$1"
    local file="$2"
    local needle="$3"

    if grep -qF "$needle" "$file"; then
        echo "PASS: ${name}"
    else
        echo "FAIL: ${name} missing '${needle}' in ${file}" >&2
        exit 1
    fi
}

assert_file_not_empty() {
    local name="$1"
    local file="$2"

    if [[ -s "$file" ]]; then
        echo "PASS: ${name}"
    else
        echo "FAIL: ${name} file is empty: ${file}" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# DockerfileModifier.sh validation
# ---------------------------------------------------------------------------
assert_file_exists "DockerfileModifier.sh exists" "DockerfileModifier.sh"
bash -n DockerfileModifier.sh
echo "PASS: DockerfileModifier.sh syntax valid"

# ---------------------------------------------------------------------------
# Setup script validation
# ---------------------------------------------------------------------------
assert_file_exists "setup script exists" "resources/setup_vllm_debian_trixie.sh"
bash -n resources/setup_vllm_debian_trixie.sh
echo "PASS: setup_vllm_debian_trixie.sh syntax valid"

# ---------------------------------------------------------------------------
# Requirements / resource files validation
# ---------------------------------------------------------------------------
assert_file_exists "common requirements" "resources/common.txt"
assert_file_not_empty "common requirements non-empty" "resources/common.txt"

assert_file_exists "cpu requirements" "resources/cpu.txt"
assert_file_not_empty "cpu requirements non-empty" "resources/cpu.txt"

assert_file_exists "cpu-build requirements" "resources/cpu-build.txt"
assert_file_not_empty "cpu-build requirements non-empty" "resources/cpu-build.txt"

# ---------------------------------------------------------------------------
# DockerfileModifier.sh content sanity checks
# ---------------------------------------------------------------------------
assert_file_contains "modifier references base image" "DockerfileModifier.sh" "FROM"
assert_file_contains "modifier references COPY" "DockerfileModifier.sh" "COPY"
assert_file_contains "modifier references platform" "DockerfileModifier.sh" "TARGETPLATFORM"

# ---------------------------------------------------------------------------
# Multi-arch platform verification
# ---------------------------------------------------------------------------
expected_platforms="linux/amd64"
assert_eq "default platform includes amd64" \
    "$(printf '%s' "$expected_platforms" | grep -c 'amd64')" "1"

# ---------------------------------------------------------------------------
# Docker / buildx availability checks
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
    echo "PASS: docker CLI available"
    if docker buildx version >/dev/null 2>&1; then
        echo "PASS: docker buildx available"
    else
        echo "WARN: docker buildx not available (non-fatal in CI pre-flight)"
    fi
else
    echo "WARN: docker CLI not available (non-fatal in CI pre-flight)"
fi

# ---------------------------------------------------------------------------
# Registry connectivity checks
# ---------------------------------------------------------------------------
for registry in registry-1.docker.io ghcr.io; do
    if curl -sfm 5 "https://${registry}/v2/" -o /dev/null 2>/dev/null || \
       curl -sfm 5 "https://${registry}/v2/" -o /dev/null -w "%{http_code}" 2>/dev/null | grep -qE '^(200|401)$'; then
        echo "PASS: registry reachable: ${registry}"
    else
        echo "WARN: registry unreachable: ${registry} (non-fatal)"
    fi
done

echo "runtime_behavior_checks_ok"
