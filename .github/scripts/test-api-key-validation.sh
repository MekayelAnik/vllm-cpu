#!/usr/bin/env bash
set -euo pipefail

readonly SAFE_API_KEY_REGEX='^[[:graph:]]+$'
readonly MIN_API_KEY_LEN=5
readonly MAX_API_KEY_LEN=256

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

is_valid_api_key() {
    local raw="$1"
    local normalized key_len

    normalized="$(trim "$raw")"

    if [[ -z "$normalized" ]]; then
        return 0
    fi

    key_len=${#normalized}
    if (( key_len < MIN_API_KEY_LEN || key_len > MAX_API_KEY_LEN )); then
        return 1
    fi

    [[ "$normalized" =~ $SAFE_API_KEY_REGEX ]]
}

assert_valid() {
    local name="$1"
    local value="$2"

    if is_valid_api_key "$value"; then
        echo "PASS: ${name}"
    else
        echo "FAIL: expected valid - ${name}" >&2
        exit 1
    fi
}

assert_invalid() {
    local name="$1"
    local value="$2"

    if is_valid_api_key "$value"; then
        echo "FAIL: expected invalid - ${name}" >&2
        exit 1
    else
        echo "PASS: ${name}"
    fi
}

exact_256="$(printf '%*s' 256 '' | tr ' ' 'a')"
too_long_257="$(printf '%*s' 257 '' | tr ' ' 'a')"

assert_valid "empty disables auth" ""
assert_valid "normal key" "gnx_short"
assert_valid "provided 133-char key" "gnx_0YZjrf7WfrjrYSw1aMpqJ931y6JR4H48luF5ZtJEFO8dskCRDnafZfLpbdqsJjdqm2I7pfEY71YxfxTs0QvY7uBJJyMmRLQte9hKxPuJNjeWcLUd5vRZ3ZnHuMFFbxm9"
assert_valid "allowed symbols" "gnx.with:allowed@chars+and=minus-underscore_"
assert_valid "slash allowed" "gnx/generated/token/with/slashes"
assert_valid "star allowed" "gnx*generated*token"
assert_valid "trimmed whitespace" "   gnx_trimmed_ok   "
assert_valid "exact max length" "$exact_256"

assert_invalid "too short" "abcd"
assert_invalid "contains space" "gnx_bad key"
assert_invalid "contains tab" $'gnx_bad\tkey'
assert_invalid "too long" "$too_long_257"

echo "api_key_validation_ok"