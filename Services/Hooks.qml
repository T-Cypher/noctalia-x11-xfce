pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// [hooks] - run user commands on shell events with NOCTALIA_* environment variables.
Singleton {
    id: root

    function run(event, env) {
        var h = Config.get("hooks." + event, null);
        if (h === null || h === undefined)
            return;
        var cmds = Array.isArray(h) ? h : [h];
        var prefix = "";
        if (env) {
            for (var k in env)
                prefix += "export " + k + "='" + String(env[k]).replace(/'/g, "'\\''") + "'; ";
        }
        for (var i = 0; i < cmds.length; i++) {
            var c = String(cmds[i] || "").trim();
            if (c.length > 0)
                Quickshell.execDetached(["sh", "-c", prefix + c]);
        }
    }
}
