#!/usr/bin/env bash

set -euo pipefail

format_modifiers() {
    local modmask="$1"
    local parts=()
    local result=""
    local part=""

    (( modmask & (1 << 6) )) && parts+=("SUPER")
    (( modmask & (1 << 0) )) && parts+=("SHIFT")
    (( modmask & (1 << 2) )) && parts+=("CTRL")
    (( modmask & (1 << 3) )) && parts+=("ALT")
    (( modmask & (1 << 1) )) && parts+=("CAPS")
    (( modmask & (1 << 4) )) && parts+=("MOD2")
    (( modmask & (1 << 5) )) && parts+=("MOD3")
    (( modmask & (1 << 7) )) && parts+=("MOD5")

    for part in "${parts[@]}"; do
        if [[ -n "$result" ]]; then
            result+=" + "
        fi
        result+="$part"
    done

    printf '%s' "$result"
}

format_key() {
    local key="$1"
    local keycode="$2"

    if [[ -n "$key" ]]; then
        printf '%s' "$key"
        return
    fi

    if [[ "$keycode" != "0" ]]; then
        printf 'keycode:%s' "$keycode"
        return
    fi

    printf 'unknown'
}

main() {
    if ! command -v jq >/dev/null 2>&1; then
        printf 'jq is required but not installed\n' >&2
        return 1
    fi

    local binds_json=""
    binds_json="$(hyprctl binds -j)"

    jq -r '
        .[]
        | select(.has_description and (.description | type == "string") and (.description | length > 0))
        | [(.modmask | tostring), (.key // ""), (.keycode | tostring), .description]
        | @tsv
    ' <<<"$binds_json" |
    while IFS=$'\t' read -r modmask key keycode description; do
        local modifiers=""
        local key_text=""

        modifiers="$(format_modifiers "$modmask")"
        key_text="$(format_key "$key" "$keycode")"

        if [[ -n "$modifiers" ]]; then
            printf '%s + %s: %s\n' "$modifiers" "$key_text" "$description"
        else
            printf '%s: %s\n' "$key_text" "$description"
        fi
    done
}

main "$@"
