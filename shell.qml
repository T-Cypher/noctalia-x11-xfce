//@ pragma UseQApplication

// Noctalia X11 - a Quickshell port of noctalia v5.3.0 for X11 window managers (XFCE / xfwm4).
// Run with:  qs -c noctalia-x11      (after installing into ~/.config/quickshell/noctalia-x11)

import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Modules.Bar
import qs.Modules.Panels
import qs.Modules.Notifications
import qs.Modules.Osd
import qs.Modules.Ipc
import qs.Modules.Dock

ShellRoot {
    id: shellRoot

    // Start services that must run from the beginning (singletons are lazy otherwise).
    Component.onCompleted: {
        var boot = [Notifications.daemonEnabled, Clipboard.enabled, Idle.caffeine, NightLight.enabled, Wallpaper.backend, ThemeControl.started, Weather.enabled, X11.available, Power.hasBattery];
        startedHook.start();
    }

    Timer {
        id: startedHook
        interval: 1500
        onTriggered: Hooks.run("started", {})
    }

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: screenScope
            required property var modelData

            Variants {
                model: Config.ready ? Config.barNames : []
                delegate: Bar {
                    screenRef: screenScope.modelData
                }
            }

            PanelHost {
                screenRef: screenScope.modelData
            }

            Toasts {
                screenRef: screenScope.modelData
            }

            OsdWindow {
                screenRef: screenScope.modelData
            }

            IdleFade {
                screenRef: screenScope.modelData
            }

            LazyLoader {
                active: Config.get("dock.enabled", false) === true
                Dock {
                    screenRef: screenScope.modelData
                }
            }
        }
    }

    OsdTriggers {}
    Ipc {}
}
