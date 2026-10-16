import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets
import ".."

// caffeine | nightlight | power_profile | theme_mode
BarWidget {
    id: root

    readonly property var state_: {
        switch (widgetType) {
        case "caffeine":
            return {
                glyph: Idle.caffeine ? "caffeine-on" : "caffeine-off",
                on: Idle.caffeine,
                tip: I18n.tr("control-center.shortcuts.caffeine", "Caffeine") + ": " + (Idle.caffeine ? "on" : "off")
            };
        case "nightlight":
            return {
                glyph: NightLight.forced ? "nightlight-forced" : (NightLight.enabled ? "nightlight-on" : "nightlight-off"),
                on: NightLight.active,
                tip: I18n.tr("control-center.shortcuts.nightlight", "Night Light") + ": " + (NightLight.forced ? "forced" : NightLight.enabled ? (NightLight.active ? "active" : "scheduled") : "off")
            };
        case "power_profile":
            return {
                glyph: Power.profileGlyph(Power.profileName),
                on: Power.profileName === "performance",
                tip: Power.profilesAvailable ? Power.profileLabel(Power.profileName) : "power-profiles-daemon unavailable"
            };
        case "theme_mode":
            return {
                glyph: "theme-mode",
                on: !Theme.isDark,
                tip: I18n.tr("settings.widgets.types.theme-mode", "Theme mode") + ": " + Theme.mode
            };
        }
        return {
            glyph: "help",
            on: false,
            tip: ""
        };
    }

    hideWidget: widgetType === "power_profile" && !Power.profilesAvailable
    tooltipText: state_.tip

    NIcon {
        icon: root.settings.glyph || root.state_.glyph
        size: root.glyphSize
        color: root.state_.on ? Theme.primary : root.iconColor(Theme.fgSurface)
    }
}
