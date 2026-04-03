#!/usr/bin/env bash
# =============================================================================
# fetch-upstream-releases.sh — Detect new vLLM upstream releases (v0.17.0+)
# =============================================================================
# Queries vllm-project/vllm GitHub Releases for new versions, then checks
# which ones are NOT yet published on PyPI as vllm-cpu wheels.
#
# Inputs (env vars):
#   GITHUB_TOKEN        — GitHub API token (for rate limits)
#   MANUAL_VERSIONS_RAW — Comma-separated versions to build (overrides auto)
#   REQUESTED_ACTION    — "auto-check" or "build" (default: auto-check)
#   MIN_VERSION         — Minimum upstream version (default: 0.17.0)
#   MAX_VERSIONS        — Max versions to return (default: 5)
#   PYPI_PACKAGE        — PyPI package name (default: vllm-cpu)
#   PYPI_REGISTRY       — PyPI registry URL (default: https://pypi.org)
#   EXCLUDE_VERSIONS    — Comma-separated versions to skip
#
# Outputs (to GITHUB_OUTPUT):
#   build_matrix   — JSON array of {version, platform} (cross-product for build job)
#   versions_json  — JSON array of {version} (deduplicated, for publish/release jobs)
#   latest_version — Highest new version
#   should_build   — true/false
# =============================================================================
set -euo pipefail

REQUESTED_ACTION="${REQUESTED_ACTION:-auto-check}"
MANUAL_VERSIONS_RAW="${MANUAL_VERSIONS_RAW:-}"
MIN_VERSION="${MIN_VERSION:-0.17.0}"
MAX_VERSIONS="${MAX_VERSIONS:-5}"
PYPI_PACKAGE="${PYPI_PACKAGE:-vllm-cpu}"
PYPI_REGISTRY="${PYPI_REGISTRY:-https://pypi.org}"
EXCLUDE_VERSIONS="${EXCLUDE_VERSIONS:-}"

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "GITHUB_OUTPUT is required" >&2
  exit 1
fi

# --- Helper: version comparison (returns 0 if $1 >= $2) ---
version_gte() {
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# --- Helper: check if version is excluded ---
is_excluded() {
  local ver="$1"
  if [[ -z "$EXCLUDE_VERSIONS" ]]; then
    return 1
  fi
  IFS=',' read -ra EXCL <<< "$EXCLUDE_VERSIONS"
  for e in "${EXCL[@]}"; do
    e="$(echo "$e" | xargs)"
    [[ "$e" == "$ver" ]] && return 0
  done
  return 1
}

# --- Manual version mode ---
if [[ -n "$MANUAL_VERSIONS_RAW" && "$REQUESTED_ACTION" == "build" ]]; then
  IFS=',' read -ra MANUAL_ARRAY <<< "$MANUAL_VERSIONS_RAW"
  VERSIONS_LIST=""
  for v in "${MANUAL_ARRAY[@]}"; do
    clean="$(echo "$v" | xargs)"
    if [[ -n "$clean" ]] && version_gte "$clean" "$MIN_VERSION" && ! is_excluded "$clean"; then
      VERSIONS_LIST="${VERSIONS_LIST:+$VERSIONS_LIST
}$clean"
    fi
  done

  if [[ -z "$VERSIONS_LIST" ]]; then
    echo "No valid versions in manual input (min: $MIN_VERSION)"
    echo "versions_json=[]" >> "$GITHUB_OUTPUT"
    echo "latest_version=" >> "$GITHUB_OUTPUT"
    echo "should_build=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  VERSIONS_SORTED="$(echo "$VERSIONS_LIST" | sort -V)"
  LATEST_VERSION="$(echo "$VERSIONS_SORTED" | tail -n1)"
  echo "Manual versions: $(echo "$VERSIONS_SORTED" | tr '\n' ', ')"
else
  # --- Auto-detect: query upstream GitHub Releases ---
  echo "Fetching releases from vllm-project/vllm..."

  GH_API_ARGS=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    GH_API_ARGS+=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  # Fetch up to 100 releases (paginated)
  UPSTREAM_VERSIONS=""
  for page in 1 2 3; do
    RESPONSE="$(curl -fsSL "${GH_API_ARGS[@]}" \
      "https://api.github.com/repos/vllm-project/vllm/releases?per_page=100&page=${page}" 2>/dev/null || echo "[]")"

    PAGE_VERSIONS="$(echo "$RESPONSE" | jq -r '
      .[] | select(.draft == false and .prerelease == false) |
      .tag_name | ltrimstr("v")
    ' 2>/dev/null || true)"

    [[ -z "$PAGE_VERSIONS" ]] && break
    UPSTREAM_VERSIONS="${UPSTREAM_VERSIONS:+$UPSTREAM_VERSIONS
}$PAGE_VERSIONS"
  done

  if [[ -z "$UPSTREAM_VERSIONS" ]]; then
    echo "No upstream releases found"
    echo "versions_json=[]" >> "$GITHUB_OUTPUT"
    echo "latest_version=" >> "$GITHUB_OUTPUT"
    echo "should_build=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  # Filter to >= MIN_VERSION, exclude pre-releases and excluded versions
  FILTERED=""
  while IFS= read -r ver; do
    [[ -z "$ver" ]] && continue
    # Skip pre-release tags
    if echo "$ver" | grep -qEi '(a|b|rc|dev|alpha|beta|pre)'; then
      continue
    fi
    if version_gte "$ver" "$MIN_VERSION" && ! is_excluded "$ver"; then
      FILTERED="${FILTERED:+$FILTERED
}$ver"
    fi
  done <<< "$UPSTREAM_VERSIONS"

  if [[ -z "$FILTERED" ]]; then
    echo "No upstream releases >= $MIN_VERSION"
    echo "versions_json=[]" >> "$GITHUB_OUTPUT"
    echo "latest_version=" >> "$GITHUB_OUTPUT"
    echo "should_build=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  # Sort and take top N
  FILTERED_SORTED="$(echo "$FILTERED" | sort -Vr | head -n "$MAX_VERSIONS" | sort -V)"

  # --- Check which versions are already on PyPI ---
  echo "Checking existing vllm-cpu versions on PyPI..."
  PYPI_URL="${PYPI_REGISTRY}/pypi/${PYPI_PACKAGE}/json"
  PYPI_VERSIONS="$(curl -fsSL "$PYPI_URL" 2>/dev/null | jq -r '.releases | keys[]' 2>/dev/null || echo "")"

  NEW_VERSIONS=""
  while IFS= read -r ver; do
    [[ -z "$ver" ]] && continue
    # Check if base version exists on PyPI (including .postN variants)
    escaped_ver="$(echo "$ver" | sed 's/\./\\./g')"
    if echo "$PYPI_VERSIONS" | grep -q "^${escaped_ver}$\|^${escaped_ver}\.post"; then
      echo "  $ver — already on PyPI, skipping"
    else
      echo "  $ver — NEW, will build"
      NEW_VERSIONS="${NEW_VERSIONS:+$NEW_VERSIONS
}$ver"
    fi
  done <<< "$FILTERED_SORTED"

  if [[ -z "$NEW_VERSIONS" ]]; then
    echo "All upstream versions already published to PyPI"
    echo "versions_json=[]" >> "$GITHUB_OUTPUT"
    echo "latest_version=" >> "$GITHUB_OUTPUT"
    echo "should_build=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  VERSIONS_SORTED="$NEW_VERSIONS"
  LATEST_VERSION="$(echo "$VERSIONS_SORTED" | tail -n1)"
  echo "New versions to build: $(echo "$VERSIONS_SORTED" | tr '\n' ', ')"
fi

# --- Build output JSON: cross-product of versions × platforms ---
# GitHub Actions matrix.include needs the full cross-product pre-computed
BUILD_MATRIX="$(echo "$VERSIONS_SORTED" | jq -Rnc --arg latest "$LATEST_VERSION" '
  [inputs | select(length > 0)] |
  [.[] as $ver | ("x86_64","aarch64") as $plat | {
    version: $ver,
    platform: $plat
  }]
')"

# Also output a simple versions list (for publish/release matrix)
VERSIONS_JSON="$(echo "$VERSIONS_SORTED" | jq -Rnc --arg latest "$LATEST_VERSION" '
  [inputs | select(length > 0)] | map({version: .})
')"

echo "build_matrix=${BUILD_MATRIX}" >> "$GITHUB_OUTPUT"
echo "versions_json=${VERSIONS_JSON}" >> "$GITHUB_OUTPUT"
echo "latest_version=${LATEST_VERSION}" >> "$GITHUB_OUTPUT"
echo "should_build=true" >> "$GITHUB_OUTPUT"

echo ""
echo "=== Build Plan ==="
echo "Versions: $(echo "$VERSIONS_SORTED" | tr '\n' ' ')"
echo "Latest: $LATEST_VERSION"
echo "Platforms: x86_64 + aarch64 (unified CPU, stable ABI cp38-abi3)"
