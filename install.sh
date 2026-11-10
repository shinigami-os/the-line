#!/bin/sh
# Installs The Line, the Quickshell desktop shell for Hyprland.
#
#   sudo ./install.sh               install (or update) system-wide, under /usr
#   sudo ./install.sh --dev         link /usr/share/the-line to this checkout instead: what you edit here is live
#   sudo ./install.sh --greeter     also put The Line's login screen first in greetd (Kira's start-greeter.sh)
#   ./install.sh --check            only look at what is installed and what is missing
#   sudo ./install.sh --uninstall   remove it (your ~/.config/the-line stays where it is)
#   DESTDIR=/tmp/pkg ./install.sh   install into a staging directory (packaging: no root, no checks)
#
#   --force                         go on even when a required program is missing
#
# Then log out and pick "The Line" in the login screen's session list.
set -eu

src="$(cd "$(dirname "$0")" && pwd)"
dest="${DESTDIR:-}"
share="$dest/usr/share"
bin="$dest/usr/bin"
tree="$share/the-line"

mode=install
greeter=
force=
for arg in "$@"; do
    case "$arg" in
    --dev) mode=dev ;;
    --check) mode=check ;;
    --uninstall) mode=uninstall ;;
    --greeter) greeter=1 ;;
    --force) force=1 ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

if [ -t 1 ]; then
    bold=$(printf '\033[1m'); dim=$(printf '\033[2m'); red=$(printf '\033[31m'); green=$(printf '\033[32m'); plain=$(printf '\033[0m')
else
    bold=; dim=; red=; green=; plain=
fi
say() { printf '%s\n' "$*"; }
step() { printf '%s%s%s\n' "$bold" "$*" "$plain"; }
die() { printf '%s%s%s\n' "$red" "$*" "$plain" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------------------------------------ what it needs

# "program  what it is for", one per line. The names are the programs, not the packages: they differ per distribution.
required="qs           Quickshell 0.3 or later: the shell itself
Hyprland      the compositor (0.55 or later: the session's configuration is Lua)
start-hyprland  starts Hyprland for the session
dbus-run-session  the session bus
pipewire      audio
wireplumber   audio sessions
wpctl         volume keys (WirePlumber)
nmcli         Wi-Fi and networks (NetworkManager)
loginctl      lock, sleep, power
grim          screenshots, and the lock screen's first frame
wl-copy       clipboard (wl-clipboard)
cliphist      clipboard history
hypridle      idle: dim, lock, suspend
foot          the default terminal
python3       The Line's helper scripts"

recommended="brightnessctl  brightness keys, the screen backlight
playerctl     media keys
qalc          the launcher's calculator
cava          the music visualiser
qt6ct         icon themes in Qt apps
jq            the settings app's system page
slurp         screenshots of an area
matugen       an accent taken from the wallpaper
mpv           thumbnails of video wallpapers"

optional="hyprsunset   night light
hyprpicker    the colour picker
flameshot     screenshots with annotations
wf-recorder   screen recording
tesseract     text from a screenshot (OCR)
yazi          the file manager in the terminal
howdy         face sign-in
fprintd-list  fingerprint sign-in
cage          the login screen (greetd)"

version_of() { "$@" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1; }

# 0 when $1 (1.2.3) is at least $2 (1.2)
version_ge() {
    a_major=${1%%.*}; rest=${1#*.}; a_minor=${rest%%.*}
    b_major=${2%%.*}; rest=${2#*.}; b_minor=${rest%%.*}
    [ "$a_major" -gt "$b_major" ] || { [ "$a_major" -eq "$b_major" ] && [ "$a_minor" -ge "$b_minor" ]; }
}

missing_required=0

# check <label> <list>: prints what is missing; counts the required ones
check_list() {
    label=$1
    list=$2
    found=0
    total=0
    lines=
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        prog=${line%% *}
        total=$((total + 1))
        if have "$prog"; then
            found=$((found + 1))
        else
            lines="$lines
  $red-$plain $prog$dim  ${line#"$prog"}$plain"
            [ "$label" = required ] && missing_required=$((missing_required + 1))
        fi
    done <<EOF
$list
EOF
    printf '%s%-12s%s %d of %d found\n' "$bold" "$label" "$plain" "$found" "$total"
    [ -z "$lines" ] || printf '%s\n' "${lines#
}"
}

check_deps() {
    step "Checking what The Line needs"
    check_list required "$required"
    check_list recommended "$recommended"
    check_list optional "$optional"

    if have qs; then
        v=$(version_of qs --version)
        if [ -n "$v" ] && ! version_ge "$v" 0.3; then
            say "  ${red}-${plain} Quickshell $v is too old (0.3 or later)"
            missing_required=$((missing_required + 1))
        fi
    fi
    if have Hyprland; then
        v=$(version_of Hyprland --version)
        if [ -n "$v" ] && ! version_ge "$v" 0.55; then
            say "  ${red}-${plain} Hyprland $v is too old: the session's configuration is Lua (0.55 or later)"
            missing_required=$((missing_required + 1))
        fi
    fi
    if have fc-list; then
        fc-list : family | grep -qi raleway || say "  ${dim}no Raleway font: the shell falls back to a default one${plain}"
        fc-list : family | grep -qiE 'IBM Plex Mono|JetBrains Mono' || say "  ${dim}no IBM Plex Mono (or JetBrains Mono) font: figures and keys fall back to a default one${plain}"
    fi
    if ! python3 -c 'import PIL' 2>/dev/null; then
        say "  ${dim}python3 has no Pillow: The Line's cursor theme can't be drawn (the default cursors stay)${plain}"
    fi
    say "  ${dim}Qt Multimedia (the ffmpeg backend) is needed for video wallpapers, adw-gtk3 and Kvantum for other apps' colours${plain}"
}

# ------------------------------------------------------------------------------------------------ what it puts where

# the runtime tree: what the shell, the session and the settings app read
runtime="shell.qml VERSION services modules settings greeter session assets"

put() { # put <mode> <from> <to>
    install -Dm"$1" "$2" "$3"
}

install_tree() {
    step "Installing to ${tree#"$dest"}"
    mkdir -p "$share"
    if [ "$mode" = dev ]; then
        [ -L "$tree" ] || [ ! -e "$tree" ] || die "$tree is a real directory: remove it first (sudo rm -r $tree)"
        ln -sfn "$src" "$tree"
        say "  linked to $src"
    else
        # the new tree is made beside the old one, then swapped in: a running shell never sees half of it
        rm -rf "$tree.new"
        mkdir "$tree.new"
        for item in $runtime; do
            cp -a "$src/$item" "$tree.new/"
        done
        rm -rf "$tree"   # (a link to a checkout from --dev: only the link goes)
        mv "$tree.new" "$tree"
        say "  copied ($(cat "$src/VERSION" 2>/dev/null || echo '?'))"
    fi
}

install_files() {
    step "Installing the session, the settings app and the polkit policy"
    if [ "$mode" = dev ]; then
        mkdir -p "$bin"
        ln -sf "${tree#"$dest"}/session/the-line-session" "$bin/the-line-session"
    else
        put 755 "$src/session/the-line-session" "$bin/the-line-session"
    fi
    put 644 "$src/session/the-line.desktop" "$share/wayland-sessions/the-line.desktop"
    put 644 "$src/session/the-line-settings.desktop" "$share/applications/the-line-settings.desktop"
    put 644 "$src/session/org.kira.the-line.settings.policy" "$share/polkit-1/actions/org.kira.the-line.settings.policy"

    # the settings app's icon, in the size it has
    icon="$src/assets/icons/the-line-settings.png"
    size=$(python3 -c 'import struct,sys; d=open(sys.argv[1],"rb").read(24); print(struct.unpack(">I",d[16:20])[0])' "$icon" 2>/dev/null || echo 256)
    put 644 "$icon" "$share/icons/hicolor/${size}x${size}/apps/the-line-settings.png"
    if [ -z "$dest" ]; then
        have gtk-update-icon-cache && gtk-update-icon-cache -q "$share/icons/hicolor" 2>/dev/null || true
        have update-desktop-database && update-desktop-database -q "$share/applications" 2>/dev/null || true
    fi
}

install_cursor() {
    step "Drawing The Line's cursor theme"
    if python3 -c 'import PIL' 2>/dev/null; then
        python3 "$src/cursor/build.py" "$share/icons/TheLine" >/dev/null && say "  $share/icons/TheLine"
    else
        say "  skipped: python3 needs Pillow (the default cursors stay)"
    fi
}

install_greeter() {
    step "Putting The Line's login screen first in greetd"
    [ -z "$dest" ] || { say "  skipped: not into a staging directory"; return; }
    "$tree/greeter/install-greetd"
}

uninstall() {
    step "Removing The Line"
    greetd=/etc/greetd/start-greeter.sh
    if [ -z "$dest" ] && [ -e "$greetd.before-the-line" ]; then
        mv -f "$greetd.before-the-line" "$greetd"
        say "  login screen: $greetd is back as it was"
    fi
    rm -rf "$tree" "$tree.new"
    rm -f "$bin/the-line-session" "$share/wayland-sessions/the-line.desktop" "$share/applications/the-line-settings.desktop" \
        "$share/polkit-1/actions/org.kira.the-line.settings.policy"
    rm -f "$share"/icons/hicolor/*/apps/the-line-settings.png
    rm -rf "$share/icons/TheLine"
    say "  done. Your settings in ~/.config/the-line and the state in ~/.local/state/the-line were left alone."
}

# ------------------------------------------------------------------------------------------------ go

case "$mode" in
check)
    check_deps
    [ "$missing_required" -eq 0 ] && exit 0 || exit 1
    ;;
uninstall)
    [ -n "$dest" ] || [ "$(id -u)" -eq 0 ] || die "Run it as root: sudo ./install.sh --uninstall"
    uninstall
    exit 0
    ;;
esac

[ -n "$dest" ] || [ "$(id -u)" -eq 0 ] || die "Run it as root: sudo ./install.sh (or DESTDIR=<dir> ./install.sh to stage it)"

if [ -z "$dest" ]; then
    check_deps
    if [ "$missing_required" -gt 0 ] && [ -z "$force" ]; then
        die "
$missing_required required thing(s) missing: install them, then run this again (or --force to install anyway)."
    fi
    say
fi

install_tree
install_files
install_cursor
[ -z "$greeter" ] || install_greeter

say
printf '%sThe Line is installed.%s Log out and choose "The Line" in the session list of your login screen.\n' "$green" "$plain"
say "The first login tells the story of the line (it is replayed by typing \"welcome\" in the launcher)."
[ -n "$greeter" ] || say "${dim}Its own login screen: sudo ${tree#"$dest"}/greeter/install-greetd (Kira's greetd setup), or ./install.sh --greeter.${plain}"
