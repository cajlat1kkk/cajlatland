// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A T E   T I M E   S E R V I C E                                      │
// │   system locale, timezone and NTP · read and change                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/locale_time.py")

    property string locale: ""
    property var availableLocales: []
    property string timezone: ""
    property bool ntp: true
    property var timezones: []
    property string error: ""
    property bool busy: false
    property bool ready: false

    readonly property Process reader: Process {
        command: ["python3", root.script, "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    readonly property Process writer: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                root.ingest(text)
            }
        }
    }

    function ingest(text: string): void {
        if (!text || text.trim() === "")
            return
        try {
            const data = JSON.parse(text)
            root.locale = data.locale ?? ""
            root.availableLocales = data.availableLocales ?? []
            root.timezone = data.timezone ?? ""
            root.ntp = Boolean(data.ntp)
            root.timezones = data.timezones ?? []
            root.error = data.error ?? ""
            root.ready = true
        } catch (err) {
            console.warn("Cannot parse locale_time state:", err)
        }
    }

    function refresh(): void {
        root.reader.running = true
    }

    function setLocale(id: string): void {
        if (root.busy || id === root.locale)
            return
        root.busy = true
        root.error = ""
        root.writer.command = ["python3", root.script, "set-locale", id]
        root.writer.running = true
    }

    function setTimezone(id: string): void {
        if (root.busy || id === root.timezone)
            return
        root.busy = true
        root.error = ""
        root.writer.command = ["python3", root.script, "set-timezone", id]
        root.writer.running = true
    }

    function setNtp(enabled: bool): void {
        if (root.busy)
            return
        root.busy = true
        root.error = ""
        root.writer.command = ["python3", root.script, "set-ntp", enabled ? "true" : "false"]
        root.writer.running = true
    }

    function setDateTime(stamp: string): void {
        const trimmed = stamp.trim()
        if (root.busy || trimmed === "")
            return
        root.busy = true
        root.error = ""
        root.writer.command = ["python3", root.script, "set-time", trimmed]
        root.writer.running = true
    }
}
