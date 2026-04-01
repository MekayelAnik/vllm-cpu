#!/usr/bin/env bash
set -euo pipefail

REQUESTED_ACTION="${REQUESTED_ACTION:-auto-check}"
MANUAL_VERSIONS_RAW="${MANUAL_VERSIONS_RAW:-}"
NPM_PACKAGE="${NPM_PACKAGE:-@brave/brave-search-mcp-server}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"
MAX_VERSIONS="${MAX_VERSIONS:-10}"
EXCLUDE_VERSIONS="${EXCLUDE_VERSIONS:-}"

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "GITHUB_OUTPUT is required" >&2
    exit 1
fi

DATE_TAG="$(date +%d%m%Y)"
echo "date_tag=$DATE_TAG" >> "$GITHUB_OUTPUT"

if [[ -n "$MANUAL_VERSIONS_RAW" && "$REQUESTED_ACTION" == "build-versions" ]]; then
    VERSIONS_NEWEST="$({
        echo "$MANUAL_VERSIONS_RAW" \
            | tr ',' '\n' \
            | sed 's/^ *//; s/ *$//' \
            | sed '/^$/d' \
            | grep -Evi '(beta|canary)' \
            | head -n "$MAX_VERSIONS"
    } || true)"

    if [[ -z "$VERSIONS_NEWEST" ]]; then
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | head -n1)"
else
    # Use cached NPM metadata if available and recent (< 1 hour old)
    NPM_CACHE_FILE="${RUNNER_TEMP:-/tmp}/npm-package-cache.json"
    CACHE_MAX_AGE=3600

    if [[ -f "$NPM_CACHE_FILE" ]]; then
        CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$NPM_CACHE_FILE" 2>/dev/null || echo 0) ))
        if [[ "$CACHE_AGE" -lt "$CACHE_MAX_AGE" ]]; then
            echo "Using cached NPM metadata (${CACHE_AGE}s old)"
            cp "$NPM_CACHE_FILE" npm-package.json
        else
            curl -fsSL "${NPM_REGISTRY}/${NPM_PACKAGE}" -o npm-package.json
            cp npm-package.json "$NPM_CACHE_FILE"
        fi
    else
        curl -fsSL "${NPM_REGISTRY}/${NPM_PACKAGE}" -o npm-package.json
        cp npm-package.json "$NPM_CACHE_FILE"
    fi

    VERSIONS_NEWEST="$({
        jq -r '.versions | keys[]' npm-package.json \
            | grep -Evi '(beta|canary)' \
            | sort -Vr \
            | head -n "$MAX_VERSIONS"
    } || true)"

    if [[ -z "$VERSIONS_NEWEST" ]]; then
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    DIST_TAG_LATEST="$(jq -r '."dist-tags".latest // ""' npm-package.json)"
    if [[ -n "$DIST_TAG_LATEST" ]] && echo "$VERSIONS_NEWEST" | grep -qx "$DIST_TAG_LATEST"; then
        LATEST_VERSION="$DIST_TAG_LATEST"
    else
        LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | head -n1)"
    fi
fi

# Filter out excluded versions (comma-separated list in EXCLUDE_VERSIONS)
if [[ -n "$EXCLUDE_VERSIONS" ]]; then
    EXCLUDE_PATTERN="$(echo "$EXCLUDE_VERSIONS" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | sed '/^$/d' | paste -sd '|')"
    BEFORE_COUNT="$(echo "$VERSIONS_NEWEST" | wc -l)"
    VERSIONS_NEWEST="$(echo "$VERSIONS_NEWEST" | grep -Evx "$EXCLUDE_PATTERN" || true)"
    AFTER_COUNT="$(echo "${VERSIONS_NEWEST:-}" | grep -c . || echo 0)"
    if [[ "$BEFORE_COUNT" -ne "$AFTER_COUNT" ]]; then
        echo "Excluded versions (matched $((BEFORE_COUNT - AFTER_COUNT))): $EXCLUDE_VERSIONS"
    fi

    if [[ -z "$VERSIONS_NEWEST" ]]; then
        echo "All versions excluded — nothing to build"
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    # Recalculate latest if the current one was excluded
    if ! echo "$VERSIONS_NEWEST" | grep -qx "$LATEST_VERSION"; then
        OLD_LATEST="$LATEST_VERSION"
        LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | sort -Vr | head -n1)"
        echo "Latest version $OLD_LATEST was excluded — falling back to $LATEST_VERSION"
    fi
fi

VERSIONS_OLDEST="$(echo "$VERSIONS_NEWEST" | sort -V)"
VERSIONS_JSON="$(echo "$VERSIONS_OLDEST" | jq -R -s -c --arg date "$DATE_TAG" --arg latest "$LATEST_VERSION" '
  split("\n")
  | map(select(length > 0))
  | map({
      version: .,
      image_tag: (. + "-" + $date),
      promote_latest: (. == $latest)
    })
')"

echo "versions_json=$VERSIONS_JSON" >> "$GITHUB_OUTPUT"
echo "latest_version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"
echo "should_build=true" >> "$GITHUB_OUTPUT"

echo "Stable versions selected for build (oldest first):"
echo "$VERSIONS_OLDEST"
echo "Latest stable: $LATEST_VERSION"
