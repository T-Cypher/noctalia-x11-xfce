#!/usr/bin/env bash
# Noctalia X11 installer (Quickshell config for XFCE / xfwm4 and other EWMH window managers).
#
#   ./install.sh                 copy into ~/.config/quickshell/noctalia-x11, install noctalia-msg,
#                                create a starter config and an autostart entry
#   ./install.sh --link          symlink instead of copying (handy while hacking on it)
#   ./install.sh --no-autostart  skip ~/.config/autostart/noctalia-x11.desktop
#   ./install.sh --uninstall     remove everything installed by this script (keeps your config)
#
# Afterwards run scripts/xfce-setup.sh for the optional XFCE integration (compositor,
# notification daemon, keyboard shortcuts, media keys).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$XDG_CONFIG_HOME/quickshell/noctalia-x11"
BIN_DIR="$HOME/.local/bin"
AUTOSTART="$XDG_CONFIG_HOME/autostart/noctalia-x11.desktop"
USER_CONFIG_DIR="$XDG_CONFIG_HOME/noctalia-x11"

mode=copy
autostart=1
for arg in "$@"; do
    case "$arg" in
        --link) mode=link ;;
        --no-autostart) autostart=0 ;;
        --uninstall) mode=uninstall ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

say()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if [ "$mode" = uninstall ]; then
    rm -rf "$DEST" && say "removed $DEST"
    rm -f "$BIN_DIR/noctalia-msg" && say "removed $BIN_DIR/noctalia-msg"
    rm -f "$AUTOSTART" && say "removed $AUTOSTART"
    say "kept your configuration in $USER_CONFIG_DIR and state in ~/.local/state/noctalia-x11"
    exit 0
fi

# ------------------------------------------------------------------ dependency report
say "checking dependencies"
missing_required=0
if have qs || have quickshell; then
    ver="$( (qs --version || quickshell --version) 2>/dev/null | head -n1 || true)"
    say "found $ver"
else
    warn "Quickshell is not installed (need >= 0.2.0, Qt >= 6.7). See README.md#installing-quickshell"
    missing_required=1
fi
have python3 || { warn "python3 is required for the X11 bridge (scripts/x11-bridge.py)"; missing_required=1; }
python3 - <<'EOF' 2>/dev/null || warn "libX11 could not be loaded from python3 (ctypes) - the X11 bridge will not work"
import ctypes, ctypes.util
ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
EOF

optional=(
    "nmcli:network widget and Wi-Fi panel (NetworkManager)"
    "brightnessctl:backlight brightness"
    "xfconf-query:XFCE wallpaper / theme integration"
    "xdotool:auto-paste for clipboard & emoji pickers"
    "wpctl:PipeWire (volume widgets need a running PipeWire)"
    "redshift:night light (or gammastep / sct / xrandr)"
    "xfce4-screenshooter:screenshot widget (or flameshot / maim / scrot)"
    "xflock4:screen locking (or light-locker / xscreensaver / i3lock)"
)
for entry in "${optional[@]}"; do
    cmd="${entry%%:*}"; why="${entry#*:}"
    have "$cmd" || warn "optional: '$cmd' not found - $why"
done
[ $missing_required -eq 0 ] || warn "continuing anyway; install the missing requirements before starting the shell"

# ------------------------------------------------------------------ install files
mkdir -p "$(dirname "$DEST")"
if [ -L "$DEST" ] || [ -e "$DEST" ]; then
    rm -rf "$DEST"
fi
if [ "$mode" = link ]; then
    ln -s "$SRC" "$DEST"
    say "linked $DEST -> $SRC"
else
    mkdir -p "$DEST"
    (cd "$SRC" && tar --exclude=.git --exclude=.qmlls.ini -cf - .) | (cd "$DEST" && tar -xf -)
    say "installed into $DEST"
fi
chmod +x "$DEST/scripts/"*.py "$DEST/scripts/"*.sh "$DEST/bin/noctalia-msg" 2>/dev/null || true

mkdir -p "$BIN_DIR"
install -m 755 "$SRC/bin/noctalia-msg" "$BIN_DIR/noctalia-msg"
say "installed $BIN_DIR/noctalia-msg"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not in your PATH" ;; esac

# ------------------------------------------------------------------ starter config
if [ ! -e "$USER_CONFIG_DIR/config.toml" ]; then
    if [ -e "$XDG_CONFIG_HOME/noctalia/config.toml" ]; then
        say "found an existing noctalia config ($XDG_CONFIG_HOME/noctalia/config.toml); it will be used (read-only)"
        say "create $USER_CONFIG_DIR/config.toml to give the X11 port its own settings"
    else
        mkdir -p "$USER_CONFIG_DIR"
        cp "$SRC/config.example.toml" "$USER_CONFIG_DIR/config.toml"
        say "created $USER_CONFIG_DIR/config.toml"
    fi
fi

# ------------------------------------------------------------------ autostart
if [ $autostart -eq 1 ]; then
    mkdir -p "$(dirname "$AUTOSTART")"
    cp "$SRC/noctalia-x11.desktop" "$AUTOSTART"
    say "autostart entry: $AUTOSTART"
fi

cat <<EOF

Done. Start it now with:

    qs -c noctalia-x11

Optional XFCE integration (compositor, notifications, shortcuts, media keys):

    $DEST/scripts/xfce-setup.sh --help

Control it from keybindings or scripts with:

    noctalia-msg panel-toggle launcher
EOF
