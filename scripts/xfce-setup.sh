#!/usr/bin/env bash
# XFCE integration helper for Noctalia X11.
#
#   scripts/xfce-setup.sh --all            everything below
#   scripts/xfce-setup.sh --compositor     enable the xfwm4 compositor (needed for transparency)
#   scripts/xfce-setup.sh --notifications  stop xfce4-notifyd so Noctalia owns org.freedesktop.Notifications
#   scripts/xfce-setup.sh --shortcuts      Super+Space launcher, Super+S control center, Super+V clipboard,
#                                          Super+Escape session menu, Super+Comma wallpaper picker
#   scripts/xfce-setup.sh --media-keys     volume / media keys -> noctalia-msg (when xfce4-panel is gone)
#   scripts/xfce-setup.sh --hide-panel     quit xfce4-panel for this session (see README to make it permanent)
#   scripts/xfce-setup.sh --revert         undo shortcuts/media keys/notifyd changes made by this script
set -uo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
say()  { printf '\033[1;36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

have xfconf-query || { warn "xfconf-query not found - is this an XFCE session?"; exit 1; }
MSG="noctalia-msg"
have noctalia-msg || MSG="$HOME/.local/bin/noctalia-msg"

KS=xfce4-keyboard-shortcuts
set_cmd() { # <accelerator> <command>
    xfconf-query -c "$KS" -p "/commands/custom/$1" -n -t string -s "$2" 2>/dev/null \
        || xfconf-query -c "$KS" -p "/commands/custom/$1" -s "$2"
    say "shortcut $1 -> $2"
}
unset_cmd() { xfconf-query -c "$KS" -p "/commands/custom/$1" -r 2>/dev/null && say "removed shortcut $1"; }

shortcuts=(
    "<Super>space|$MSG panel-toggle launcher"
    "<Super>s|$MSG panel-toggle control-center"
    "<Super>v|$MSG panel-toggle clipboard"
    "<Super>Escape|$MSG panel-toggle session"
    "<Super>comma|$MSG panel-toggle wallpaper"
)
media=(
    "XF86AudioRaiseVolume|$MSG volume-up"
    "XF86AudioLowerVolume|$MSG volume-down"
    "XF86AudioMute|$MSG volume-mute"
    "XF86AudioMicMute|$MSG mic-mute"
    "XF86AudioPlay|$MSG media toggle"
    "XF86AudioNext|$MSG media next"
    "XF86AudioPrev|$MSG media previous"
)

do_compositor() {
    xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true
    say "xfwm4 compositor enabled"
}

do_notifications() {
    if systemctl --user list-unit-files xfce4-notifyd.service >/dev/null 2>&1 \
        && systemctl --user list-unit-files xfce4-notifyd.service | grep -q xfce4-notifyd; then
        systemctl --user mask --now xfce4-notifyd.service && say "masked xfce4-notifyd.service"
    fi
    mkdir -p "$HOME/.config/autostart"
    printf '[Desktop Entry]\nType=Application\nName=Xfce Notification Daemon\nHidden=true\n' \
        > "$HOME/.config/autostart/xfce4-notifyd.desktop"
    pkill -x xfce4-notifyd 2>/dev/null && say "stopped xfce4-notifyd"
    say "restart Noctalia (qs -c noctalia-x11) so it can claim the notification bus name"
}

do_shortcuts() { for s in "${shortcuts[@]}"; do set_cmd "${s%%|*}" "${s#*|}"; done; }
do_media()     { for s in "${media[@]}"; do set_cmd "${s%%|*}" "${s#*|}"; done; }

do_hide_panel() {
    if pgrep -x xfce4-panel >/dev/null; then
        xfce4-panel --quit && say "xfce4-panel quit for this session"
        warn "to keep it from coming back: Settings > Session and Startup > Current Session >"
        warn "xfce4-panel > Restart Style: Never, then 'Save Session'"
    else
        say "xfce4-panel is not running"
    fi
}

do_revert() {
    for s in "${shortcuts[@]}" "${media[@]}"; do unset_cmd "${s%%|*}"; done
    rm -f "$HOME/.config/autostart/xfce4-notifyd.desktop"
    systemctl --user unmask xfce4-notifyd.service >/dev/null 2>&1 || true
    say "reverted (log out and back in to restore xfce4-notifyd)"
}

[ $# -eq 0 ] && { sed -n '2,13p' "$0"; exit 0; }
for arg in "$@"; do
    case "$arg" in
        --all) do_compositor; do_notifications; do_shortcuts; do_media ;;
        --compositor) do_compositor ;;
        --notifications) do_notifications ;;
        --shortcuts) do_shortcuts ;;
        --media-keys) do_media ;;
        --hide-panel) do_hide_panel ;;
        --revert) do_revert ;;
        -h|--help) sed -n '2,13p' "$0" ;;
        *) warn "unknown option $arg" ;;
    esac
done
