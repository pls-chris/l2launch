#!/usr/bin/env bash
# l2launch — start a Lineage II client on Linux without Steam
# https://github.com/pls-chris/l2launch   (MIT, Christoforos Pliatsikas)
#
# Put this file in the client folder (next to system/), name it after the
# server (l2myserver.sh) and run it:
#   ./l2myserver.sh                  play
#   ./l2myserver.sh --check          only check this PC (nothing is downloaded)
#   ./l2myserver.sh --desktop        add it to the application menu
#   ./l2myserver.sh --winecfg        Wine settings of this client's prefix
#   ./l2myserver.sh --reset-prefix   start with a new prefix (old one is kept aside)
#   ./l2myserver.sh --version
#
# Settings (saved per client, used on every start):
#   --fps 144 | --fps off            frame limit, default 60
#   --hud on|off                     fps counter in the corner (DXVK HUD)
#   --mangohud on|off                MangoHud overlay (if installed)
#   --title "My Server"              name in messages and in the menu
#   --settings                       show the saved settings
#
# The file name decides everything that belongs to one client: l2myserver.sh
# -> prefix ~/.local/share/l2myserver/, settings ~/.config/l2myserver/,
# window class steam_app_l2myserver. Several clients = several copies with
# different names. Proton and umu are shared and downloaded only once.
#
# What it does: downloads GE-Proton9-27 and umu-launcher once (pinned versions,
# checksums checked), keeps its own Wine prefix per client and starts
# system/L2.exe through umu-run, which runs Proton inside the Steam Linux
# Runtime container — same behaviour on every distro. A server's own
# launcher/updater is not used.
#
# Environment variables override the settings for one start:
#   L2_FPS=off  L2_HUD=on  L2_MANGOHUD=on  L2_CLIENT=/path/to/client
#
# Files: ~/.local/share/l2launch/ (Proton, umu — shared)
#        ~/.local/share/<name>/   (prefix, last-run.log)
#        ~/.local/share/umu/      (Steam Linux Runtime, downloaded by umu-run)
set -euo pipefail

L2LAUNCH_VERSION="1.0.0"

GE_VER="GE-Proton9-27"
GE_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_VER}/${GE_VER}.tar.gz"
GE_SHA512="86a2b2962a2509104201b3532bc829d058d666bc8220417f71bd4af660b6d05781e9f684b3982339d695a5fd4babe19e97ec42a82a78311faf99fc1257280623"
UMU_VER="1.4.4"
UMU_URL="https://github.com/Open-Wine-Components/umu-launcher/releases/download/${UMU_VER}/umu-launcher-${UMU_VER}-zipapp.tar"
UMU_SHA256="eb590691841f7fad3fc3ad8fd5db4ccb87849fe7948e62b28ece7a4ee48cc851"

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
CLIENT="${L2_CLIENT:-${L2NOSTOS_CLIENT:-$(dirname "$SELF")}}"
# Name from the script's file name: l2myserver.sh -> l2myserver.
# Only a-z 0-9 (umu needs that for the window class).
BASE="$(basename "$SELF" .sh)"
NAME="$(printf '%s' "$BASE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
[ -n "$NAME" ] || NAME="l2launch"
LABEL="$BASE"            # replaced by the saved --title below

SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
TOOLS="$SHARE/l2launch"                 # Proton + umu, shared by every copy
DATA="$SHARE/$NAME"                     # prefix + log of this client
PREFIX="$DATA/prefix"
UMU="$TOOLS/umu-$UMU_VER/umu-run"
LOG="$DATA/last-run.log"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/$NAME/launcher.conf"
# settings file of pre-1.0 versions (then called l2nostos.sh)
[ -f "$CONF" ] || [ ! -f "$(dirname "$CONF")/l2nostos.conf" ] || mv "$(dirname "$CONF")/l2nostos.conf" "$CONF"

say()  { printf '\033[1;36m[%s]\033[0m %s\n' "$LABEL" "$*"; }
warn() { printf '\033[1;33m[%s] WARNING:\033[0m %s\n' "$LABEL" "$*" >&2; }
die()  { printf '\033[1;31m[%s] ERROR:\033[0m %s\n' "$LABEL" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── settings ────────────────────────────────────────────────────────────────
conf_get() {  # key default — plain KEY=value lines, the file is never executed
    local v=""
    [ -f "$CONF" ] && v=$(sed -n "s/^$1=//p" "$CONF" | tail -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    echo "${v:-$2}"
}

conf_set() {  # key value
    mkdir -p "$(dirname "$CONF")"
    [ -f "$CONF" ] || printf '# l2launch settings for %s — change with %s --fps / --hud / --mangohud / --title\n' "$NAME" "$(basename "$SELF")" > "$CONF"
    if grep -q "^$1=" "$CONF"; then sed -i "s/^$1=.*/$1=$2/" "$CONF"; else echo "$1=$2" >> "$CONF"; fi
}

onoff() {  # normalise on/off/1/0/yes/no -> on|off, empty = invalid
    case "${1,,}" in on|1|yes|true) echo on ;; off|0|no|false) echo off ;; *) echo "" ;; esac
}

fps_value() {  # -> number, 0 = no limit, empty = invalid
    case "${1,,}" in
        off|none|0) echo 0 ;;
        *[!0-9]*|"") echo "" ;;
        *) [ "$1" -ge 15 ] && [ "$1" -le 1000 ] && echo "$1" || echo "" ;;
    esac
}

settings() {
    local fps; fps=$(conf_get FPS 60)
    say "settings ($CONF):"
    echo "  TITLE    = $LABEL"
    echo "  FPS      = $([ "$(fps_value "$fps")" = 0 ] && echo "off (no limit)" || echo "$fps")"
    echo "  HUD      = $(conf_get HUD off)"
    echo "  MANGOHUD = $(conf_get MANGOHUD off)"
}

LABEL="$(conf_get TITLE "$BASE")"

find_exe() {  # system/L2.exe, any case (some clients ship l2.exe)
    local f
    for f in "$CLIENT"/system/*; do
        case "${f##*/}" in [Ll]2.[Ee][Xx][Ee]) echo "$f"; return 0 ;; esac
    done
    return 1
}
EXE="$(find_exe || true)"

# ── helpers for the Vulkan check ────────────────────────────────────────────
exe_bits() {  # Windows exe -> 32 / 64 (PE "Machine" field), empty if unknown
    [ -f "$1" ] || return 0
    local off m
    off=$(od -An -t u4 -j 60 -N 4 "$1" 2>/dev/null | tr -d ' ')
    [ -n "$off" ] || return 0
    m=$(od -An -t x2 -j $((off + 4)) -N 2 "$1" 2>/dev/null | tr -d ' ')
    case "$m" in 014c|14c) echo 32 ;; 8664) echo 64 ;; esac
}

elf_bits() {  # Linux library -> 32 / 64 (ELF class byte)
    case "$(od -An -t u1 -j 4 -N 1 "$1" 2>/dev/null | tr -d ' ')" in 1) echo 32 ;; 2) echo 64 ;; esac
}

vulkan_has() {  # bits — is there a Vulkan driver (ICD) library of this bitness?
    local json lib d
    for json in /usr/share/vulkan/icd.d/*.json /etc/vulkan/icd.d/*.json \
                "${XDG_DATA_HOME:-$HOME/.local/share}"/vulkan/icd.d/*.json; do
        [ -f "$json" ] || continue
        lib=$(sed -n 's/.*"library_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json" | head -n 1)
        [ -n "$lib" ] || continue
        if [ "${lib#/}" != "$lib" ]; then
            [ "$(elf_bits "$lib")" = "$1" ] && return 0
        else  # bare name (NVIDIA): look in the usual library folders
            for d in /usr/lib /usr/lib32 /usr/lib64 /usr/lib/x86_64-linux-gnu /usr/lib/i386-linux-gnu; do
                [ -f "$d/$lib" ] && [ "$(elf_bits "$d/$lib")" = "$1" ] && return 0
            done
        fi
    done
    return 1
}

# ── checks ──────────────────────────────────────────────────────────────────
check() {
    local bad=0
    [ "$(uname -m)" = "x86_64" ] || { warn "needs an x86_64 PC (this is $(uname -m))"; bad=1; }

    if have python3 && python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then :; else
        warn "python3 3.10 or newer is needed (umu-run)"; bad=1
    fi
    have curl || have wget || { warn "curl or wget is needed for the first download"; bad=1; }
    for t in tar sha256sum sha512sum; do have "$t" || { warn "$t is missing"; bad=1; }; done

    # pressure-vessel (Steam runtime container) needs unprivileged user namespaces
    if have unshare && ! unshare --user --map-root-user true 2>/dev/null; then
        warn "unprivileged user namespaces are blocked — the Steam runtime container can not start."
        warn "  Ubuntu 24.04+: AppArmor blocks them (kernel.apparmor_restrict_unprivileged_userns=1)."
        warn "  If the game does not start, this is the reason."
    fi

    # Vulkan driver with the same bitness as L2.exe (DXVK runs inside the game)
    local bits; bits=$(exe_bits "$EXE")
    if [ -n "$bits" ] && ! vulkan_has "$bits"; then
        warn "no ${bits}-bit Vulkan driver found (L2.exe is ${bits}-bit). Install it:"
        if [ "$bits" = 32 ]; then
            warn "  Arch/CachyOS: lib32-vulkan-radeon (AMD), lib32-vulkan-intel (Intel), lib32-nvidia-utils (NVIDIA)"
            warn "  Debian/Ubuntu: dpkg --add-architecture i386 && apt install mesa-vulkan-drivers:i386"
            warn "  Fedora: mesa-vulkan-drivers.i686"
        else
            warn "  Arch/CachyOS: vulkan-radeon (AMD), vulkan-intel (Intel), nvidia-utils (NVIDIA)"
            warn "  Debian/Ubuntu: mesa-vulkan-drivers    Fedora: mesa-vulkan-drivers"
        fi
    fi

    [ -n "$EXE" ] || { warn "no system/L2.exe in $CLIENT — put this script in the client folder"; bad=1; }

    mkdir -p "$DATA" "$TOOLS"
    local free; free=$(df -Pm "$TOOLS" | awk 'NR==2 {print $4}')
    [ "${free:-0}" -ge 3000 ] || warn "less than 3 GB free in $TOOLS (Proton + runtime + prefix need ~2.5 GB)"

    return $bad
}

# ── downloads ───────────────────────────────────────────────────────────────
fetch() {  # url dest
    if have curl; then curl -fL --retry 3 --progress-bar -o "$2" "$1"
    else wget -q --show-progress -O "$2" "$1"; fi
}

find_proton() {
    local d
    # (~/.local/share/l2nostos = location used by pre-1.0 versions)
    for d in "$TOOLS/$GE_VER" \
             "$SHARE/l2nostos/$GE_VER" \
             "$HOME/.steam/root/compatibilitytools.d/$GE_VER" \
             "$HOME/.local/share/Steam/compatibilitytools.d/$GE_VER" \
             "$HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/$GE_VER"; do
        [ -x "$d/proton" ] && { echo "$d"; return 0; }
    done
    return 1
}

get_proton() {
    find_proton >/dev/null && return 0
    say "downloading $GE_VER (~450 MB download, 1.3 GB unpacked, only the first time)"
    local tmp; tmp=$(mktemp -d "$TOOLS/.dl.XXXXXX")
    fetch "$GE_URL" "$tmp/ge.tar.gz"
    echo "$GE_SHA512  $tmp/ge.tar.gz" | sha512sum -c --quiet - || { rm -rf "$tmp"; die "$GE_VER checksum is wrong — download damaged or changed"; }
    say "unpacking $GE_VER"
    tar -xzf "$tmp/ge.tar.gz" -C "$tmp"
    mv "$tmp/$GE_VER" "$TOOLS/$GE_VER"
    rm -rf "$tmp"
}

get_umu() {
    [ -x "$UMU" ] && return 0
    local old="$SHARE/l2nostos/umu-$UMU_VER/umu-run"   # pre-1.0 location
    if [ -x "$old" ]; then mkdir -p "$(dirname "$UMU")"; cp "$old" "$UMU"; return 0; fi
    say "downloading umu-launcher $UMU_VER"
    local tmp; tmp=$(mktemp -d "$TOOLS/.dl.XXXXXX")
    fetch "$UMU_URL" "$tmp/umu.tar"
    echo "$UMU_SHA256  $tmp/umu.tar" | sha256sum -c --quiet - || { rm -rf "$tmp"; die "umu-launcher checksum is wrong"; }
    tar -xf "$tmp/umu.tar" -C "$tmp"
    mkdir -p "$TOOLS/umu-$UMU_VER"
    mv "$tmp/umu/umu-run" "$UMU"
    chmod +x "$UMU"
    rm -rf "$tmp"
}

# ── run ─────────────────────────────────────────────────────────────────────
run_umu() {  # args for umu-run
    local proton; proton=$(find_proton) || die "Proton not found"
    export GAMEID="umu-$NAME" STORE="none"     # window class: steam_app_$NAME
    export WINEPREFIX="$PREFIX" PROTONPATH="$proton"
    export PROTON_LOG=0 WINEDEBUG="${WINEDEBUG:--all}"

    local fps hud mango
    fps=$(fps_value "${L2_FPS:-${L2NOSTOS_FPS:-$(conf_get FPS 60)}}")
    [ -n "$fps" ] || { warn "FPS setting is not valid (15-1000 or off), using 60"; fps=60; }
    hud=$(onoff "${L2_HUD:-${L2NOSTOS_HUD:-$(conf_get HUD off)}}")
    mango=$(onoff "${L2_MANGOHUD:-${L2NOSTOS_MANGOHUD:-$(conf_get MANGOHUD off)}}")
    [ "$fps" != "0" ] && export DXVK_FRAME_RATE="$fps"
    [ "$hud" = "on" ] && export DXVK_HUD="fps"
    [ "$mango" = "on" ] && export MANGOHUD=1

    mkdir -p "$PREFIX"
    cd "$CLIENT/system"
    [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/umu/steamrt3" ] || \
        say "first start: umu-run downloads the Steam Linux Runtime (~200 MB), this takes some minutes"
    say "starting (fps limit: ${DXVK_FRAME_RATE:-off}), log: $LOG"
    set +e
    python3 "$UMU" "$@" >"$LOG" 2>&1
    local rc=$?
    set -e
    if [ $rc -ne 0 ]; then
        warn "exited with code $rc — last lines of $LOG:"
        tail -n 25 "$LOG" >&2
    fi
    return $rc
}

desktop() {
    local app="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    local icon="$CLIENT/$NAME.png"
    [ -f "$icon" ] || icon="applications-games"
    mkdir -p "$app"
    cat > "$app/$NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$LABEL
Comment=Lineage II client — $LABEL
Exec="$SELF"
Path=$CLIENT
Icon=$icon
Terminal=false
Categories=Game;
EOF
    say "menu entry: $app/$NAME.desktop"
}

case "${1:-}" in
    -h|--help)    sed -n '2,/^set -euo/p' "$SELF" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    --version)    echo "l2launch $L2LAUNCH_VERSION (GE-Proton: $GE_VER, umu-launcher: $UMU_VER)"; exit 0 ;;
    --title)
        v=$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9 ._-' | cut -c1-40)
        [ -n "$v" ] || die "use --title \"My Server\" (letters, digits, space . _ -)"
        conf_set TITLE "$v"; LABEL="$v"; settings; exit 0 ;;
    --settings)   settings; exit 0 ;;
    --fps)
        v=$(fps_value "${2:-}"); [ -n "$v" ] || die "use --fps <15-1000> or --fps off"
        conf_set FPS "$([ "$v" = 0 ] && echo off || echo "$v")"; settings; exit 0 ;;
    --hud|--mangohud)
        v=$(onoff "${2:-}"); [ -n "$v" ] || die "use $1 on or $1 off"
        k=${1#--}; conf_set "${k^^}" "$v"; settings; exit 0 ;;
    --check)      check && say "all checks OK" || die "fix the warnings above first"; exit 0 ;;
    --desktop)    desktop; exit 0 ;;
    --reset-prefix)
        [ -d "$PREFIX" ] && mv "$PREFIX" "$PREFIX.old.$(date +%Y%m%d-%H%M%S)" && say "old prefix moved aside"
        exit 0 ;;
    --winecfg)    check || die "fix the warnings above first"; get_proton; get_umu; run_umu winecfg; exit $? ;;
    "")           ;;
    *)            die "unknown option $1 (see --help)" ;;
esac

check || die "fix the warnings above first (./$(basename "$SELF") --check)"
get_proton
get_umu
run_umu "$EXE"
