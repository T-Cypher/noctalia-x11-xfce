import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services

// IPC endpoints:
//   qs -c noctalia-x11 ipc call noctalia msg "panel-toggle launcher"
// bin/noctalia-msg wraps this so the noctalia CLI syntax works: noctalia-msg panel-toggle launcher
Scope {
    IpcHandler {
        target: "noctalia"

        function msg(command: string): string {
            return Commands.run(command, null);
        }
        function help(): string {
            return Commands.commandList.join("\n");
        }
    }

    IpcHandler {
        target: "panel"

        function toggle(id: string): void {
            Panels.ipc("toggle", id, "");
        }
        function open(id: string): void {
            Panels.ipc("open", id, "");
        }
        function close(): void {
            Panels.close();
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Panels.ipc("toggle", "launcher", "");
        }
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            Panels.ipc("toggle", "control-center", "");
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            Panels.ipc("toggle", "session", "");
        }
        function lock(): void {
            Session.lock();
        }
    }
}
