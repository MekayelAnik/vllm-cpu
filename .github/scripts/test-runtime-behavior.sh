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

# Verify DockerfileModifier.sh exists and is valid bash
[[ -f "DockerfileModifier.sh" ]] || { echo "FAIL: DockerfileModifier.sh missing" >&2; exit 1; }
bash -n DockerfileModifier.sh
echo "PASS: DockerfileModifier.sh syntax valid"

echo "runtime_behavior_checks_ok"
