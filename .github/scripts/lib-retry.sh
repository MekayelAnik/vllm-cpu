#!/usr/bin/env bash
# Shared retry and inspect helpers for CI/CD scripts.
# Source this file: source "$(dirname "$0")/lib-retry.sh"

run_with_retry() {
    local description="$1"
    shift
    local attempts=5
    local delay=2
    local attempt
    local err_file
    err_file="$(mktemp)"

    for attempt in $(seq 1 "$attempts"); do
        if "$@" 2>"$err_file"; then
            rm -f "$err_file"
            return 0
        fi

        if [[ "$attempt" -lt "$attempts" ]]; then
            if grep -qiE '429|toomanyrequests|rate limit' "$err_file"; then
                echo "Rate limit detected for ${description}" >&2
                rm -f "$err_file"
                return 2
            fi
            echo "Retry ${attempt}/${attempts} for ${description} failed. Sleeping ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    echo "${description} failed after ${attempts} attempts" >&2
    if [[ -s "$err_file" ]]; then
        echo "Last stderr output:" >&2
        cat "$err_file" >&2
        if grep -qiE '429|toomanyrequests|rate limit' "$err_file"; then
            rm -f "$err_file"
            return 2
        fi
    fi
    rm -f "$err_file"
    return 1
}

run_with_retry_output() {
    local description="$1"
    shift
    local attempts=5
    local delay=2
    local attempt
    local err_file
    local out
    err_file="$(mktemp)"

    for attempt in $(seq 1 "$attempts"); do
        if out="$("$@" 2>"$err_file")"; then
            rm -f "$err_file"
            printf '%s' "$out"
            return 0
        fi

        if [[ "$attempt" -lt "$attempts" ]]; then
            if grep -qiE '429|toomanyrequests|rate limit' "$err_file"; then
                echo "Rate limit detected for ${description}" >&2
                rm -f "$err_file"
                return 2
            fi
            echo "Retry ${attempt}/${attempts} for ${description} failed. Sleeping ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))
        fi
    done

    echo "${description} failed after ${attempts} attempts" >&2
    if [[ -s "$err_file" ]]; then
        echo "Last stderr output:" >&2
        cat "$err_file" >&2
        if grep -qiE '429|toomanyrequests|rate limit' "$err_file"; then
            rm -f "$err_file"
            return 2
        fi
    fi
    rm -f "$err_file"
    return 1
}
