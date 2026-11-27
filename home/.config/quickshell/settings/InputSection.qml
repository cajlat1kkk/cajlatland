// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   I N P U T   S E C T I O N                                              │
// │   keyboard and pointer settings                                          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import "../theme"
import "../services"
import "../components"

// Keyboard and pointer. Stored in the shell's settings and pushed to Hyprland
// at login and after every reload; `hypr/modules/input.lua` holds the
// defaults.
SettingsSection {
    id: root

    // The visible part; set by `SettingsPanel`.
    property string tab: ""

    Component.onCompleted: {
        CompositorService.load()
        CompositorService.loadLayouts()
        CompositorService.loadShake()
    }

    // "palette" follows the accent; the rest are fixed (`Theme.fixedColours`).
    // compositor.py does the recolouring.
    readonly property var cursorColors: [
        { id: "palette", label: Tr.t("Palette"), swatch: Theme.accent, palette: true }
    ].concat(Theme.fixedColours.map(entry =>
        ({ id: entry.id, label: Tr.t(entry.label), swatch: entry.id })))

    readonly property string switchOption:
        CompositorService.value("input:kb_options", "")

    readonly property int layoutCount:
        CompositorService.value("input:kb_layout", "us")
            .split(",").filter(entry => entry.trim() !== "").length


    // ── KEYBOARD ────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "keyboard"
        spacing: 24

        SettingGroup {
            title: Tr.t("Layouts")
            note: Tr.t("Loaded in this order; the first is active at login.")

            LayoutPicker {
                current: CompositorService.value("input:kb_layout", "us")
                onChanged: value => CompositorService.remember("input:kb_layout", value)
            }

            // Locked rather than hidden while only one layout is loaded.
            SettingRow {
                label: Tr.t("Switch between them")
                locked: root.layoutCount <= 1
                reason: Tr.t("Only one layout is loaded")

                SegmentedControl {
                    options: CompositorService.layoutSwitches.map(
                        entry => ({ id: entry.id, label: Tr.t(entry.label) }))
                    current: root.switchOption
                    onSelected: id => CompositorService.remember("input:kb_options", id)
                }
            }
        }

        SettingGroup {
            title: Tr.t("Typing")
            note: Tr.t("How fast a held key repeats, once it has started.")

            SettingSlider {
                label: Tr.t("Key repeat rate")
                value: CompositorService.value("input:repeat_rate", 25)
                from: 10
                to: 60
                unit: "/s"
                onMoved: value => CompositorService.remember("input:repeat_rate", Math.round(value))
            }
        }

        SettingGroup {
            title: Tr.t("On-screen keyboard")
            note: Tr.t("A keyboard along the bottom edge, for a touch screen or no keyboard at hand.")
            hint: Tr.t("Shown and hidden by its key in Settings → Keys. Its keys follow the first layout above.")

            SettingRow {
                label: Tr.t("On-screen keyboard")
                reading: SettingsService.osk ? Tr.t("Available") : Tr.t("Off")

                ToggleSwitch {
                    checked: SettingsService.osk
                    onToggled: checked => SettingsService.set("osk", checked)
                }
            }
        }
    }


    // ── POINTER ─────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "mouse" || root.tab === "pointer"
        spacing: 24

        SettingGroup {
            title: "Мышь"
            SettingRow {
                label: "Режим для левшей"
                reading: "Правая кнопка выполняет обычный щелчок, левая открывает контекстное меню."
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:left_handed", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:left_handed", checked)
                }
            }
            SettingRow {
                label: "Естественная прокрутка мыши"
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:natural_scroll", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:natural_scroll", checked)
                }
            }
        }
        SettingGroup {
            title: Tr.t("Pointer")
            note: Tr.t("Zero is the device's native speed; either side adjusts libinput's acceleration.")

            SettingSlider {
                label: Tr.t("Sensitivity")
                value: CompositorService.value("input:sensitivity", 0)
                from: -1
                to: 1
                stepSize: 0.05
                decimals: 2
                onMoved: value => CompositorService.remember("input:sensitivity", value.toFixed(2))
            }
        }

        SettingGroup {
            title: Tr.t("The cursor")
            note: Tr.t("One vector shape, sharp at any size — Palette follows the wallpaper.")
            hint: Tr.t("Colour and size are applied with hyprctl setcursor, so every application updates at once and Palette follows wallpaper changes. Shake to find briefly enlarges the pointer when you shake the mouse; it needs the hypr-dynamic-cursors plugin (./setup plugins).")

            // Swatches, wrapping, rather than tiles; the chosen one is ringed.
            SettingTiles {
                label: Tr.t("Cursor colour")

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.cursorColors

                        Rectangle {
                            id: colourChip

                            required property var modelData

                            readonly property bool taken:
                                SettingsService.cursorColor === colourChip.modelData.id

                            width: chipRow.implicitWidth + 24
                            height: 30
                            radius: height / 2
                            color: chipMouse.containsMouse
                                ? Theme.islandSurfaceHover : Theme.island
                            border.color: colourChip.taken ? Theme.accent : Theme.islandBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 7

                                // The Palette swatch gets a thicker ring to
                                // mark it as the live accent.
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    radius: width / 2
                                    color: colourChip.modelData.swatch
                                    border.color: colourChip.modelData.palette
                                        ? Theme.accentText : Theme.hairline
                                    border.width: colourChip.modelData.palette ? 2 : 1
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: colourChip.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: colourChip.taken ? Theme.accent : Theme.text
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsService.set(
                                    "cursorColor", colourChip.modelData.id)
                            }
                        }
                    }
                }
            }

            SettingSlider {
                label: Tr.t("Cursor size")
                value: SettingsService.cursorSize
                from: 16
                to: 48
                unit: " px"
                reading: SettingsService.cursorSize === 24
                    ? Tr.t("24 px — the default")
                    : `${SettingsService.cursorSize} px`
                onMoved: value => SettingsService.set("cursorSize", Math.round(value))
            }

            // Locked, with the reason, when hypr-dynamic-cursors is not loaded.
            SettingRow {
                label: Tr.t("Shake to find")
                locked: !CompositorService.shakeAvailable
                reason: Tr.t("Needs the cursor plugin — run ./setup plugins")

                ToggleSwitch {
                    checked: SettingsService.shakeToFind
                    onToggled: checked => SettingsService.set("shakeToFind", checked)
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.tab === "touchpad"
        spacing: 24
        SettingGroup {
            title: "Прокрутка"
            SettingRow {
                label: "Естественная прокрутка"
                reading: "Содержимое движется в ту же сторону, что и пальцы."
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:touchpad:natural_scroll", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:touchpad:natural_scroll", checked)
                }
            }
            SettingSlider {
                label: "Скорость прокрутки"
                value: CompositorService.value("input:touchpad:scroll_factor", 1)
                from: 0.1
                to: 3
                stepSize: 0.1
                decimals: 1
                onMoved: value => CompositorService.remember("input:touchpad:scroll_factor", value.toFixed(1))
            }
        }
        SettingGroup {
            title: "Касания и нажатия"
            SettingRow {
                label: "Нажатие касанием"
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:touchpad:tap-to-click", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:touchpad:tap-to-click", checked)
                }
            }
            SettingRow {
                label: "Защита от случайных касаний"
                reading: "Сенсорная панель временно не реагирует во время набора текста."
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:touchpad:disable_while_typing", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:touchpad:disable_while_typing", checked)
                }
            }
            SettingRow {
                label: "Перетаскивание касанием"
                reading: "Коснитесь дважды и двигайте палец, не отрывая его после второго касания."
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:touchpad:tap-and-drag", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:touchpad:tap-and-drag", checked)
                }
            }
            SettingRow {
                label: "Щелчок двумя пальцами"
                reading: "Нажмите на панель двумя пальцами, чтобы открыть контекстное меню."
                ToggleSwitch {
                    checked: ["true", "1"].indexOf(String(CompositorService.value("input:touchpad:clickfinger_behavior", false))) >= 0
                    onToggled: checked => CompositorService.remember("input:touchpad:clickfinger_behavior", checked)
                }
            }
        }
        Repeater {
            model: [2, 3, 4]
            SettingGroup {
                id: gestureGroup
                required property int modelData
                title: "Жесты · " + modelData + " пальца"
                note: "Действие выполняется при движении на 8 мм. Стандартные жесты сохраняют поведение системы."
                Repeater {
                    model: [{id:"up",label:"Вверх"}, {id:"down",label:"Вниз"}, {id:"left",label:"Влево"}, {id:"right",label:"Вправо"}, {id:"tap",label:"Касание"}]
                    SettingRow {
                        id: gestureRow
                        required property var modelData
                        readonly property string key: gestureGroup.modelData + "_" + modelData.id
                        label: modelData.label
                        Controls.ComboBox {
                            id: gestureChoice
                            background: Rectangle {
                                color: gestureChoice.hovered ? "#343a37" : "#242927"
                                radius: 10
                                border.width: 1
                                border.color: gestureChoice.activeFocus ? Theme.accent : "#3b433f"
                            }
                            contentItem: Text {
                                text: gestureChoice.displayText
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 10
                                rightPadding: 24
                                elide: Text.ElideRight
                            }
                            popup: Controls.Popup {
                                y: gestureChoice.height + 4
                                width: gestureChoice.width
                                padding: 6
                                background: Rectangle { color: "#202623"; radius: 12; border.color: "#424c46" }
                                contentItem: ListView {
                                    implicitHeight: contentHeight
                                    model: gestureChoice.popup.visible ? gestureChoice.delegateModel : null
                                    clip: true
                                }
                            }
                            delegate: Controls.ItemDelegate {
                                required property int index
                                required property var modelData
                                width: gestureChoice.width - 12
                                height: 38
                                text: modelData.label
                                contentItem: Text { text: modelData.label; color: Theme.text; font.pixelSize: 13; leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 8; color: parent.hovered || gestureChoice.currentIndex === parent.index ? "#34463d" : "transparent" }
                            }
                            implicitWidth: 200
                            implicitHeight: 38
                            textRole: "label"
                            valueRole: "id"
                            model: [
                                {id:"default",label:"По умолчанию"},
                                {id:"none",label:"Без действия"},
                                {id:"volumeUp",label:"Увеличить громкость"},
                                {id:"volumeDown",label:"Уменьшить громкость"},
                                {id:"play",label:"Воспроизведение / пауза"},
                                {id:"next",label:"Следующий трек"}
                            ]
                            currentIndex: model.findIndex(option => option.id === (SettingsService.touchpadGestures[gestureRow.key] || "default"))
                            onActivated: {
                                const next = Object.assign({}, SettingsService.touchpadGestures)
                                next[gestureRow.key] = currentValue
                                SettingsService.set("touchpadGestures", next)
                            }
                        }
                    }
                }
            }
        }

    }
}
