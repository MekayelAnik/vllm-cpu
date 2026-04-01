#!/usr/bin/env bash
set -euo pipefail

DOCKERHUB_REPO="${DOCKERHUB_REPO:-}"
GHCR_REPO="${GHCR_REPO:-}"
TAGS="${TAGS:-}"

if [[ -z "$DOCKERHUB_REPO" || -z "$GHCR_REPO" || -z "$TAGS" ]]; then
    echo "Missing required inputs. Expected DOCKERHUB_REPO, GHCR_REPO, TAGS" >&2
    exit 1
fi

# --- Shared retry helpers ---
# shellcheck source=lib-retry.sh
source "$(dirname "$0")/lib-retry.sh"

# --- Digest cache: HEAD-only requests via crane, fallback to imagetools ---

declare -A DIGEST_CACHE
declare -A DIGEST_CACHE_RC

# Get digest with a single HEAD request (crane) or cached full inspect (fallback).
# Returns: digest string on stdout, sets return code.
cached_digest() {
    local ref="$1"

    if [[ -n "${DIGEST_CACHE_RC[$ref]+x}" ]]; then
        if [[ "${DIGEST_CACHE_RC[$ref]}" -ne 0 ]]; then
            return "${DIGEST_CACHE_RC[$ref]}"
        fi
        printf '%s' "${DIGEST_CACHE[$ref]}"
        return 0
    fi

    local digest="" rc=0 err_file
    err_file="$(mktemp)"

    set +e
    if command -v crane >/dev/null 2>&1; then
        # crane digest: single HTTP HEAD request — no manifest body downloaded
        digest="$(crane digest "$ref" 2>"$err_file")"
        rc=$?
    else
        # Fallback: full manifest inspection
        digest="$(docker buildx imagetools inspect "$ref" 2>"$err_file" | awk '/^Digest:/{print $2; exit}')"
        rc=$?
    fi
    set -e

    # Detect rate limiting
    if [[ "$rc" -ne 0 ]] && grep -qiE '429|toomanyrequests|rate.limit' "$err_file" 2>/dev/null; then
        rm -f "$err_file"
        DIGEST_CACHE_RC["$ref"]=2
        return 2
    fi
    rm -f "$err_file"

    DIGEST_CACHE_RC["$ref"]=$rc
    if [[ "$rc" -eq 0 && -n "$digest" ]]; then
        DIGEST_CACHE["$ref"]="$digest"
        printf '%s' "$digest"
    fi
    return "$rc"
}

invalidate_cache() {
    local ref="$1"
    unset 'DIGEST_CACHE['"$ref"']' 2>/dev/null || true
    unset 'DIGEST_CACHE_RC['"$ref"']' 2>/dev/null || true
}

tag_exists() {
    local ref="$1"
    cached_digest "$ref" >/dev/null 2>&1
}

# Copy image between registries using crane (server-side, only missing layers)
# or fall back to imagetools create.
registry_copy() {
    local src="$1" dst="$2" description="$3"
    local rc=0

    set +e
    if command -v crane >/dev/null 2>&1; then
        # crane copy: uses OCI mount API — target registry fetches blobs directly
        # from source registry without proxying through the CI runner.
        run_with_retry "$description" crane copy "$src" "$dst"
        rc=$?
    else
        run_with_retry "$description" docker buildx imagetools create -t "$dst" "$src" >/dev/null
        rc=$?
    fi
    set -e

    return "$rc"
}

sync_tag() {
    local tag="$1"
    local dh_ref="${DOCKERHUB_REPO}:${tag}"
    local ghcr_ref="${GHCR_REPO}:${tag}"

    local dh_exists="no"
    local ghcr_exists="no"
    local ghcr_digest="" dh_digest=""

    # HEAD-only existence + digest checks (1 request each, not full manifests)
    set +e
    ghcr_digest="$(cached_digest "$ghcr_ref" 2>/dev/null)"
    [[ $? -eq 0 && -n "$ghcr_digest" ]] && ghcr_exists="yes"

    dh_digest="$(cached_digest "$dh_ref" 2>/dev/null)"
    local dh_rc=$?
    [[ $dh_rc -eq 0 && -n "$dh_digest" ]] && dh_exists="yes"
    set -e

    if [[ "$ghcr_exists" == "no" && "$dh_exists" == "yes" ]]; then
        echo "Syncing $tag: Docker Hub -> GHCR (backfill mode)"
        local create_rc=0
        registry_copy "$dh_ref" "$ghcr_ref" "sync ${tag} dockerhub->ghcr" || create_rc=$?

        if [[ "$create_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag backfill due to rate limiting" >&2
            return 0
        fi
        [[ "$create_rc" -ne 0 ]] && return "$create_rc"
        invalidate_cache "$ghcr_ref"

    elif [[ "$ghcr_exists" == "no" && "$dh_exists" == "no" ]]; then
        echo "Tag $tag: not found in either registry - skipping"
        return 0

    elif [[ "$ghcr_exists" == "yes" && "$dh_exists" == "no" ]]; then
        echo "Syncing $tag: GHCR -> Docker Hub (new tag)"
        local create_rc=0
        registry_copy "$ghcr_ref" "$dh_ref" "sync ${tag} ghcr->dockerhub" || create_rc=$?

        if [[ "$create_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag mirror push due to Docker Hub rate limiting" >&2
            return 0
        fi
        [[ "$create_rc" -ne 0 ]] && return "$create_rc"
        invalidate_cache "$dh_ref"

    else
        # Both exist — digest comparison replaces full platform parity check.
        # Same digest = identical content (manifests, layers, platforms). No further inspection needed.
        if [[ "$ghcr_digest" == "$dh_digest" ]]; then
            echo "Tag $tag: digests match ($ghcr_digest) - skipping"
            return 0
        fi

        # Rate-limit on DH side: skip gracefully
        if [[ "$dh_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag sync check due to Docker Hub rate limiting" >&2
            return 0
        fi

        echo "Syncing $tag: digest mismatch, GHCR -> Docker Hub"
        echo "  GHCR:  $ghcr_digest"
        echo "  DH:    $dh_digest"
        local create_rc=0
        registry_copy "$ghcr_ref" "$dh_ref" "sync ${tag} mismatch ghcr->dockerhub" || create_rc=$?

        if [[ "$create_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag mismatch sync due to Docker Hub rate limiting" >&2
            return 0
        fi
        [[ "$create_rc" -ne 0 ]] && return "$create_rc"
        invalidate_cache "$dh_ref"
    fi

    echo "Synced $tag successfully"
    return 0
}

IFS=',' read -ra TAG_ARRAY <<< "$TAGS"
declare -A SEEN_TAGS

for tag in "${TAG_ARRAY[@]}"; do
    clean_tag="$(echo "$tag" | xargs)"
    [[ -z "$clean_tag" ]] && continue

    echo "Processing tag: $clean_tag"

    if [[ -n "${SEEN_TAGS[$clean_tag]:-}" ]]; then
        echo "Tag $clean_tag: duplicate - skipping"
        continue
    fi

    SEEN_TAGS[$clean_tag]=1
    sync_tag "$clean_tag"
done
