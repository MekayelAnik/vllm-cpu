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

# Auto-detect input format: range (X.Y.Z-A.B.C) vs comma-separated vs empty (auto from NPM)
IS_RANGE=false
if [[ -n "$MANUAL_VERSIONS_RAW" ]] && echo "$MANUAL_VERSIONS_RAW" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$'; then
    IS_RANGE=true
fi

if [[ -n "$MANUAL_VERSIONS_RAW" && "$IS_RANGE" == "false" && ("$REQUESTED_ACTION" == "build" || "$REQUESTED_ACTION" == "build-versions") ]]; then
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
elif [[ "$IS_RANGE" == "true" || "$REQUESTED_ACTION" == "build-range" ]]; then
    VERSION_RANGE="$MANUAL_VERSIONS_RAW"
    # Parse range: expected format "X.Y.Z-A.B.C" (start-end, inclusive)
    RANGE_START="$(echo "$VERSION_RANGE" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+\.[0-9]+\.[0-9]+)$/\1/')"
    RANGE_END="$(echo "$VERSION_RANGE" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+\.[0-9]+\.[0-9]+)$/\2/')"

    if [[ "$RANGE_START" == "$VERSION_RANGE" || "$RANGE_END" == "$VERSION_RANGE" ]]; then
        echo "Invalid version range format: '$VERSION_RANGE'. Expected format: X.Y.Z-A.B.C (e.g. 1.0.0-1.2.0)" >&2
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 1
    fi

    # Validate range direction: start must be <= end
    RANGE_LOWER="$(printf '%s\n%s' "$RANGE_START" "$RANGE_END" | sort -V | head -n1)"
    if [[ "$RANGE_LOWER" != "$RANGE_START" ]]; then
        echo "::error::Version range is reversed: $RANGE_START is greater than $RANGE_END. Use format: LOWER-HIGHER (e.g. 1.0.0-1.2.0)"
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 1
    fi

    echo "Building version range: $RANGE_START to $RANGE_END (inclusive)"

    # Fetch all available versions from NPM
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

    # Get all stable versions, filter to those within the range (inclusive)
    ALL_STABLE="$(jq -r '.versions | keys[]' npm-package.json | grep -Evi '(beta|canary)' | sort -V)"

    VERSIONS_NEWEST="$({
        while IFS= read -r ver; do
            [[ -z "$ver" ]] && continue
            LOWER="$(printf '%s\n%s' "$RANGE_START" "$ver" | sort -V | head -n1)"
            UPPER="$(printf '%s\n%s' "$ver" "$RANGE_END" | sort -V | head -n1)"
            if [[ "$LOWER" == "$RANGE_START" && "$UPPER" == "$ver" ]]; then
                echo "$ver"
            fi
        done <<< "$ALL_STABLE"
    } || true)"

    if [[ -z "$VERSIONS_NEWEST" ]]; then
        echo "No versions found in range $RANGE_START to $RANGE_END"
        echo "versions_json=[]" >> "$GITHUB_OUTPUT"
        echo "latest_version=" >> "$GITHUB_OUTPUT"
        echo "should_build=false" >> "$GITHUB_OUTPUT"
        exit 0
    fi

    RANGE_COUNT="$(echo "$VERSIONS_NEWEST" | wc -l)"
    MAX_RANGE="${MAX_RANGE_VERSIONS:-50}"
    if [[ "$RANGE_COUNT" -gt "$MAX_RANGE" ]]; then
        echo "::warning::Range contains $RANGE_COUNT versions — capping to $MAX_RANGE (set MAX_RANGE_VERSIONS to override)"
        VERSIONS_NEWEST="$(echo "$VERSIONS_NEWEST" | sort -Vr | head -n "$MAX_RANGE")"
        RANGE_COUNT="$MAX_RANGE"
    fi
    echo "Found $RANGE_COUNT versions in range $RANGE_START to $RANGE_END"

    # Latest is the highest version in the range
    LATEST_VERSION="$(echo "$VERSIONS_NEWEST" | sort -Vr | head -n1)"
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
