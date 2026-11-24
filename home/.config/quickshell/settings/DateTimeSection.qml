// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D A T E   &   T I M E   S E C T I O N                                  │
// │   language, system locale, timezone and clock format                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"
import "../components"

SettingsSection {
    id: root

    property string tab: "language"
    property string manualDateTime: ""

    signal openInput()

    Component.onCompleted: DateTimeService.refresh()

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // ── LANGUAGE ────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "language"
        spacing: root.spacing

        SettingGroup {
            title: Tr.t("Interface language")
            note: Tr.t("The language of the desktop shell, panels, menus and control centre.")
            hint: Tr.t("The whole shell is translated, and anything without a translation appears in English. The login screen and the files the shell writes, such as generated themes, are always in English.")

            SettingRow {
                label: Tr.t("Language")

                SegmentedControl {
                    options: Tr.languages
                    current: SettingsService.language
                    onSelected: id => SettingsService.set("language", id)
                }
            }
        }

        SettingGroup {
            title: Tr.t("System language")
            note: Tr.t("System locale for console and system messages.")
            hint: Tr.t("The system locale sets the language for command-line tools, terminal and system services. Changing it requires administrator permission.")

            SettingRow {
                label: Tr.t("Current locale")
                reading: DateTimeService.busy
                    ? Tr.t("Applying…")
                    : (DateTimeService.error !== ""
                        ? DateTimeService.error
                        : (DateTimeService.locale || "—"))
                alarm: DateTimeService.error !== ""
            }

            SettingTiles {
                label: Tr.t("System locale")

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: DateTimeService.availableLocales

                        Rectangle {
                            id: locChip

                            required property var modelData
                            readonly property bool taken:
                                DateTimeService.locale === locChip.modelData.id

                            width: locText.implicitWidth + 24
                            height: 30
                            radius: height / 2
                            color: locMouse.containsMouse
                                ? Theme.islandSurfaceHover : Theme.island
                            border.color: locChip.taken ? Theme.accent : Theme.islandBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                            Text {
                                id: locText
                                anchors.centerIn: parent
                                text: locChip.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: locChip.taken ? Theme.accent : Theme.text
                            }

                            MouseArea {
                                id: locMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DateTimeService.setLocale(locChip.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Keyboard layouts")
            note: Tr.t("Input language and layout switching shortcuts.")

            SettingRow {
                label: Tr.t("Keyboard")

                PillButton {
                    text: Tr.t("Open input settings")
                    icon: "󰌌"
                    implicitHeight: 30
                    onClicked: root.openInput()
                }
            }
        }
    }

    // ── DATE & TIME ─────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "datetime"
        spacing: root.spacing

        SettingGroup {
            title: Tr.t("Clock & Time")

            SettingTiles {
                label: Tr.t("Clock format")

                Repeater {
                    model: SettingsService.clockFormats

                    PreviewTile {
                        id: formatTile

                        required property var modelData

                        caption: Tr.t(formatTile.modelData.label)
                        selected: SettingsService.clockFormat === formatTile.modelData.id
                        onPicked: SettingsService.set("clockFormat", formatTile.modelData.id)

                        Text {
                            anchors.centerIn: parent
                            text: Tr.date(clock.date, SettingsService.clockShowsSeconds
                                ? formatTile.modelData.id.replace("mm", "mm:ss")
                                : formatTile.modelData.id)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }
                }
            }

            SettingRow {
                label: Tr.t("Show the date")
                reading: SettingsService.clockShowsDate
                    ? Tr.t("Beside the time") : Tr.t("The time alone")

                ToggleSwitch {
                    checked: SettingsService.clockShowsDate
                    onToggled: checked => SettingsService.set("clockShowsDate", checked)
                }
            }

            SettingRow {
                label: Tr.t("Show seconds")

                ToggleSwitch {
                    checked: SettingsService.clockShowsSeconds
                    onToggled: checked => SettingsService.set("clockShowsSeconds", checked)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Time zone")
            note: Tr.t("The local time zone for the clock and applications.")

            SettingRow {
                label: Tr.t("Current time zone")
                reading: DateTimeService.busy
                    ? Tr.t("Applying…")
                    : (DateTimeService.error !== ""
                        ? DateTimeService.error
                        : (DateTimeService.timezone || "—"))
                alarm: DateTimeService.error !== ""
            }

            SettingRow {
                label: Tr.t("Automatic time (NTP)")
                reading: DateTimeService.ntp
                    ? Tr.t("Enabled (automatic)") : Tr.t("Off")

                ToggleSwitch {
                    checked: DateTimeService.ntp
                    onToggled: checked => DateTimeService.setNtp(checked)
                }
            }

            SettingField {
                label: Tr.t("Set date & time")
                reading: DateTimeService.ntp
                    ? Tr.t("Turn off automatic time to set manually")
                    : Tr.t("Format: YYYY-MM-DD HH:MM:SS")
                placeholder: Qt.formatDateTime(clock.date, "yyyy-MM-dd HH:mm:ss")
                value: root.manualDateTime
                enabled: !DateTimeService.ntp && !DateTimeService.busy
                onEdited: val => root.manualDateTime = val
            }

            SettingRow {
                visible: !DateTimeService.ntp
                label: Tr.t("Apply date & time")
                reading: root.manualDateTime !== "" ? root.manualDateTime : Qt.formatDateTime(clock.date, "yyyy-MM-dd HH:mm:ss")

                PillButton {
                    text: Tr.t("Apply")
                    icon: "󰄬"
                    enabled: !DateTimeService.busy && root.manualDateTime.trim() !== ""
                    implicitHeight: 30
                    onClicked: DateTimeService.setDateTime(root.manualDateTime)
                }
            }

            SettingTiles {
                label: Tr.t("Time zone")

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: DateTimeService.timezones

                        Rectangle {
                            id: tzChip

                            required property var modelData
                            readonly property bool taken:
                                DateTimeService.timezone === tzChip.modelData.id

                            width: tzText.implicitWidth + 24
                            height: 30
                            radius: height / 2
                            color: tzMouse.containsMouse
                                ? Theme.islandSurfaceHover : Theme.island
                            border.color: tzChip.taken ? Theme.accent : Theme.islandBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                            Text {
                                id: tzText
                                anchors.centerIn: parent
                                text: tzChip.modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeLabel
                                color: tzChip.taken ? Theme.accent : Theme.text
                            }

                            MouseArea {
                                id: tzMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DateTimeService.setTimezone(tzChip.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        SettingGroup {
            title: Tr.t("Calendar & Date")

            SettingRow {
                label: Tr.t("Current date")
                reading: Tr.date(clock.date, "dddd, d MMMM yyyy")
            }

            SettingRow {
                label: Tr.t("Weekdays")
                reading: Tr.t("M T W T F S S")
            }
        }
    }
}
