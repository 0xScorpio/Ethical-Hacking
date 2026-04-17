#!/bin/bash
# credz - Per-target credential storage tool
# Storage: ~/.credz/<target>/{userz,hashez,passwordz}
# 0xScorpio

CREDZ_DIR="$HOME/.credz"
TYPES=(user pass hash)
declare -A FNAMES=([user]="userz" [pass]="passwordz" [hash]="hashez")
declare -A LABELS=([user]="User" [pass]="Password" [hash]="Hash")

usage() {
    cat <<EOF
Usage: credz <target> user|pass|hash <arg1> [arg2] [...]
       credz <target> copy  [user|pass|hash]
       credz <target> clear [user|pass|hash]
       credz <target> print [user|pass|hash]
       credz show [target] [user|pass|hash]

Actions:
  user    Append usernames for a target
  pass    Append passwords for a target
  hash    Append hashes for a target
  copy    Copy credential files to current directory
  clear   Clear stored credentials
  print   Print stored credentials
  show    Tree view of ~/.credz (optionally filtered by target/type)
EOF
    exit 1
}

fpath()         { echo "$CREDZ_DIR/$1/${FNAMES[$2]}"; }
resolve_types() { [[ -n "$1" && -v "FNAMES[$1]" ]] && echo "$1" || echo "${TYPES[@]}"; }
init_target()   { mkdir -p "$CREDZ_DIR/$1"; for t in "${TYPES[@]}"; do touch "$CREDZ_DIR/$1/${FNAMES[$t]}"; done; }

# Iterate over resolved types and run a callback: each_type <target> [type] <callback>
each_type() {
    local target="$1" filter="$2" cb="$3"
    for t in $(resolve_types "$filter"); do $cb "$target" "$t"; done
}

_append() {
    local f; f=$(fpath "$1" "$2")
    echo "$VALUE" >> "$f"
    echo "[+] ${LABELS[$2]} added: $VALUE ($1)"
}

_copy() {
    cp "$(fpath "$1" "$2")" "./${FNAMES[$2]}"
    echo "[+] Copied ${FNAMES[$2]} -> ./${FNAMES[$2]} ($1)"
}

_clear() {
    > "$(fpath "$1" "$2")"
    echo "[*] Cleared ${FNAMES[$2]} ($1)"
}

_print() {
    echo "=== $1 / ${LABELS[$2]}s (${FNAMES[$2]}) ==="
    cat "$(fpath "$1" "$2")" 2>/dev/null
    echo
}

show_tree() {
    local path="$1"
    if command -v tree &>/dev/null; then
        tree "$path" --noreport
    else
        find "$path" -type f | sort | while read -r f; do
            echo "${f#$CREDZ_DIR/} ($(wc -l < "$f") entries)"
        done
    fi
}

do_show() {
    local target="$1" type="$2"
    [[ ! -d "$CREDZ_DIR" ]] && { echo "[-] No credz data yet"; exit 1; }

    if [[ -z "$target" ]]; then
        show_tree "$CREDZ_DIR"; return
    fi

    local dir="$CREDZ_DIR/$target"
    [[ ! -d "$dir" ]] && { echo "[-] No data for target: $target"; exit 1; }

    if [[ -n "$type" && -v "FNAMES[$type]" ]]; then
        _print "$target" "$type"
    else
        show_tree "$dir"
    fi
}

# --- Entry point ---

[[ $# -lt 1 ]] && usage

if [[ "$1" == "show" ]]; then do_show "$2" "$3"; exit 0; fi

TARGET="$1" ACTION="$2"
[[ -z "$ACTION" ]] && { echo "[-] Missing action. See: credz"; exit 1; }
init_target "$TARGET"

case "$ACTION" in
    user|pass|hash)
        shift 2
        [[ $# -lt 1 ]] && { echo "[-] Provide at least one ${LABELS[$ACTION],,}"; exit 1; }
        for VALUE in "$@"; do _append "$TARGET" "$ACTION"; done
        ;;
    copy)  each_type "$TARGET" "$3" _copy  ;;
    clear) each_type "$TARGET" "$3" _clear ;;
    print) each_type "$TARGET" "$3" _print ;;
    *)     usage ;;
esac
