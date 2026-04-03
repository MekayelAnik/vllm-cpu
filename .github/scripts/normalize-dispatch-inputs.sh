#!/usr/bin/env bash
set -euo pipefail

ACTION_INPUT="${ACTION_INPUT:-}"
CLIENT_ACTION="${CLIENT_ACTION:-}"
VERSIONS_INPUT="${VERSIONS_INPUT:-}"
CLIENT_VERSIONS="${CLIENT_VERSIONS:-}"
FORCE_INPUT="${FORCE_INPUT:-}"
CLIENT_FORCE="${CLIENT_FORCE:-}"
AUTO_PROMOTE_INPUT="${AUTO_PROMOTE_INPUT:-}"
CLIENT_AUTO_PROMOTE="${CLIENT_AUTO_PROMOTE:-}"
CUSTOM_LATEST_INPUT="${CUSTOM_LATEST_INPUT:-}"
CLIENT_CUSTOM_LATEST="${CLIENT_CUSTOM_LATEST:-}"

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    echo "GITHUB_OUTPUT is required" >&2
    exit 1
fi

trim() {
    local v="$*"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s' "$v"
}

normalize_bool() {
    local raw
    raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$raw" in
        1|true|yes|on) printf 'true' ;;
        *) printf 'false' ;;
    esac
}

REQUESTED_ACTION="$(trim "${ACTION_INPUT:-}")"
if [[ -z "$REQUESTED_ACTION" ]]; then
    REQUESTED_ACTION="$(trim "${CLIENT_ACTION:-}")"
fi
if [[ -z "$REQUESTED_ACTION" ]]; then
    REQUESTED_ACTION="auto-check"
fi

MANUAL_VERSIONS_RAW="$(trim "${VERSIONS_INPUT:-}")"
if [[ -z "$MANUAL_VERSIONS_RAW" ]]; then
    MANUAL_VERSIONS_RAW="$(trim "${CLIENT_VERSIONS:-}")"
fi

FORCE_BUILD_RAW="$(trim "${FORCE_INPUT:-}")"
if [[ -z "$FORCE_BUILD_RAW" ]]; then
    FORCE_BUILD_RAW="$(trim "${CLIENT_FORCE:-}")"
fi
FORCE_BUILD="$(normalize_bool "$FORCE_BUILD_RAW")"

AUTO_PROMOTE_RAW="$(trim "${AUTO_PROMOTE_INPUT:-}")"
if [[ -z "$AUTO_PROMOTE_RAW" ]]; then
    AUTO_PROMOTE_RAW="$(trim "${CLIENT_AUTO_PROMOTE:-}")"
fi
AUTO_PROMOTE="$(normalize_bool "$AUTO_PROMOTE_RAW")"

CUSTOM_LATEST="$(trim "${CUSTOM_LATEST_INPUT:-}")"
if [[ -z "$CUSTOM_LATEST" ]]; then
    CUSTOM_LATEST="$(trim "${CLIENT_CUSTOM_LATEST:-}")"
fi

echo "action=$REQUESTED_ACTION" >> "$GITHUB_OUTPUT"
echo "versions=$MANUAL_VERSIONS_RAW" >> "$GITHUB_OUTPUT"
echo "force_build=$FORCE_BUILD" >> "$GITHUB_OUTPUT"
echo "auto_promote=$AUTO_PROMOTE" >> "$GITHUB_OUTPUT"
echo "custom_latest=$CUSTOM_LATEST" >> "$GITHUB_OUTPUT"
