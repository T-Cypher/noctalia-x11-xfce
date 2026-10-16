pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons

// MPRIS players with noctalia-style "active player" selection.
Singleton {
    id: root

    readonly property var blacklist: Config.get("shell.mpris.blacklist", [])
    readonly property var players: Mpris.players.values.filter(p => p && !isBlacklisted(p))
    property int selectedIndex: 0
    property string manualPlayer: ""

    readonly property var player: {
        if (players.length === 0)
            return null;
        if (manualPlayer !== "") {
            for (var i = 0; i < players.length; i++)
                if (players[i].dbusName === manualPlayer)
                    return players[i];
        }
        for (var j = 0; j < players.length; j++)
            if (players[j].isPlaying)
                return players[j];
        return players[0];
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: player !== null && player.isPlaying
    readonly property string title: player ? (player.trackTitle || player.identity || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real length: player && player.lengthSupported ? player.length : 0
    property real position: 0

    function isBlacklisted(p) {
        var list = Array.isArray(blacklist) ? blacklist : [];
        var id = String(p.identity || "").toLowerCase();
        var bus = String(p.dbusName || "").toLowerCase();
        for (var i = 0; i < list.length; i++) {
            var b = String(list[i]).toLowerCase();
            if (b.length > 0 && (id.indexOf(b) >= 0 || bus.indexOf(b) >= 0))
                return true;
        }
        return false;
    }

    function togglePlaying() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }
    function play() {
        if (player && player.canPlay)
            player.play();
    }
    function pause() {
        if (player && player.canPause)
            player.pause();
    }
    function stop() {
        if (player)
            player.stop();
    }
    function next() {
        if (player && player.canGoNext)
            player.next();
    }
    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }
    function seek(pos) {
        if (player && player.canSeek) {
            player.position = pos;
            position = pos;
        }
    }
    function cyclePlayer(delta) {
        if (players.length < 2)
            return;
        var idx = players.indexOf(player);
        var n = (idx + delta + players.length) % players.length;
        manualPlayer = players[n].dbusName;
    }

    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.player && root.player.positionSupported)
                root.position = root.player.position;
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            root.position = root.player.position;
        }
    }
}
