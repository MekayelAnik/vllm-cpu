#!/usr/bin/env bash
set -euo pipefail

bash -n DockerfileModifier.sh
bash -n .github/scripts/normalize-dispatch-inputs.sh
bash -n .github/scripts/fetch-releases.sh
bash -n .github/scripts/check-existing-tags.sh
bash -n .github/scripts/registry-sync.sh
bash -n .github/scripts/test-registry-sync.sh

echo "script_syntax_ok"

bash .github/scripts/test-runtime-behavior.sh
bash .github/scripts/test-registry-sync.sh

echo "preflight_shell_tests_ok"
