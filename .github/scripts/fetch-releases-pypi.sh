#!/usr/bin/env bash
# =============================================================================
# fetch-releases-pypi.sh — Fetch vllm-cpu releases from PyPI for Docker builds
# =============================================================================
# Queries PyPI for published vllm-cpu versions (v0.17.0+) and prepares the
# versions_json payload for reusable-build-versions.yml.
#
# Inputs (env vars):
#   REQUESTED_ACTION    — "auto-check" or "build-versions" (default: auto-check)
#   MANUAL_VERSIONS_RAW — Comma-separated versions (for build-versions mode)
#   PYPI_PACKAGE        — Package name (default: vllm-cpu)
#   PYPI_REGISTRY       — PyPI URL (default: https://pypi.org)
#   MAX_VERSIONS        — Max versions to return (default: 5)
#   MIN_VERSION         — Minimum version (default: 0.17.0)
#   EXCLUDE_VERSIONS    — Comma-separated versions to skip
#
# Outputs (to GITHUB_OUTPUT):
#   versions_json  — JSON array of {version, image_tag, promote_latest}
#   latest_version — Highest stable version
#   date_tag       — Current date (DDMMYYYY)
#   should_build   — true/false
# =============================================================================
set -euo pipefail

REQUESTED_ACTION="${REQUESTED_ACTION:-auto-check}"
MANUAL_VERSIONS_RAW="${MANUAL_VERSIONS_RAW:-}"
PYPI_PACKAGE="${PYPI_PACKAGE:-vllm-cpu}"
PYPI_REGISTRY="${PYPI_REGISTRY:-https://pypi.org}"
MAX_VERSIONS="${MAX_VERSIONS:-5}"
MIN_VERSION="${MIN_VERSION:-0.17.0}"
EXCLUDE_VERSIONS="${EXCLUDE_VERSIONS:-}"

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "GITHUB_OUTPUT is required" >&2
  exit 1
fi

DATE_TAG="$(date +%d%m%Y)"
echo "date_tag=$DATE_TAG" >> "$GITHUB_OUTPUT"

# --- Helper: version comparison (returns 0 if $1 >= $2) ---
version_gte() {
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# --- Helper: strip .postN suffix to get base version ---
base_version() {
  echo "$1" | sed -E 's/\.post[0-9]+$//'
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

emit_empty() {
  echo "versions_json=[]" >> "$GITHUB_OUTPUT"
  echo "latest_version=" >> "$GITHUB_OUTPUT"
  echo "should_build=false" >> "$GITHUB_OUTPUT"
}

# --- Manual version mode (accepts both 'build' and 'build-versions' actions) ---
if [[ -n "$MANUAL_VERSIONS_RAW" && ("$REQUESTED_ACTION" == "build-versions" || "$REQUESTED_ACTION" == "build") ]]; then
  IFS=',' read -ra MANUAL_ARRAY <<< "$MANUAL_VERSIONS_RAW"
  VERSIONS_OLDEST=""
  for v in "${MANUAL_ARRAY[@]}"; do
    clean="$(echo "$v" | xargs)"
    if [[ -n "$clean" ]] && version_gte "$(base_version "$clean")" "$MIN_VERSION" && ! is_excluded "$clean"; then
      VERSIONS_OLDEST="${VERSIONS_OLDEST:+$VERSIONS_OLDEST
}$clean"
    fi
  done

  if [[ -z "$VERSIONS_OLDEST" ]]; then
    emit_empty
    exit 0
  fi

  VERSIONS_NEWEST="$(echo "$VERSIONS_OLDEST" | sort -Vr)"
  LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | head -n1)"
else
  # --- Auto-detect: query PyPI ---
  PYPI_URL="${PYPI_REGISTRY}/pypi/${PYPI_PACKAGE}/json"
  echo "Fetching versions from ${PYPI_URL}..."

  if ! curl -fsSL "$PYPI_URL" -o pypi-package.json 2>/dev/null; then
    echo "Could not fetch PyPI data for ${PYPI_PACKAGE}"
    emit_empty
    exit 0
  fi

  # Extract all stable versions >= MIN_VERSION
  # For vllm-cpu, we want the highest .postN for each base version
  ALL_VERSIONS="$(jq -r '.releases | keys[]' pypi-package.json \
    | grep -Evi '(a|b|rc|dev|alpha|beta|pre)' \
    | sort -Vr || true)"

  if [[ -z "$ALL_VERSIONS" ]]; then
    echo "No stable versions found on PyPI"
    emit_empty
    exit 0
  fi

  # Filter to >= MIN_VERSION and deduplicate to highest .postN per base version
  declare -A SEEN_BASE
  FILTERED=""
  while IFS= read -r ver; do
    [[ -z "$ver" ]] && continue
    bv="$(base_version "$ver")"
    if ! version_gte "$bv" "$MIN_VERSION"; then
      continue
    fi
    if is_excluded "$ver" || is_excluded "$bv"; then
      continue
    fi
    # Keep only the highest .postN (first seen in descending sort)
    if [[ -z "${SEEN_BASE[$bv]:-}" ]]; then
      SEEN_BASE["$bv"]=1
      FILTERED="${FILTERED:+$FILTERED
}$ver"
    fi
  done <<< "$ALL_VERSIONS"

  if [[ -z "$FILTERED" ]]; then
    echo "No versions >= $MIN_VERSION found"
    emit_empty
    exit 0
  fi

  # Take top N, sort oldest-first
  VERSIONS_NEWEST="$(echo "$FILTERED" | head -n "$MAX_VERSIONS")"
  LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | head -n1)"
fi

VERSIONS_OLDEST="$(echo "$VERSIONS_NEWEST" | sort -V)"

# --- Build output JSON ---
VERSIONS_JSON="$(echo "$VERSIONS_OLDEST" | jq -Rnc --arg date "$DATE_TAG" --arg latest "$LATEST_VERSION" '
  [inputs | select(length > 0)] | map({
    version: .,
    image_tag: (. + "-" + $date),
    promote_latest: (. == $latest)
  })
')"

echo "versions_json=$VERSIONS_JSON" >> "$GITHUB_OUTPUT"
echo "latest_version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
echo "should_build=true" >> "$GITHUB_OUTPUT"

echo ""
echo "=== Docker Build Plan ==="
echo "Versions (oldest first):"
echo "$VERSIONS_OLDEST"
echo "Latest: $LATEST_VERSION"
echo "Date tag: $DATE_TAG"
