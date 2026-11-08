pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

// Settings > Network > Networks around: scanned while the section is open. The connected one is lit; signal is
// drawn as four short bars, the way the status tile does. Enter connects (a new secured network asks its password
// right there) or disconnects the connected one; Delete forgets a saved one.
Item {
    id: wifi

    property var setting
    property bool active: false
    property int cursor: 0
    property var asking: null   // the network whose password is being typed

    signal picked
    signal refocus

    readonly property var list: Net.networks
    implicitHeight: (list.length === 0 ? 34 : list.length * 34) + (asking ? 48 : 0) + (Net.error !== "" ? 24 : 0)

    function activate(net) {
        if (!net)
            return;
        if (net.active) {
            Net.disconnect(net);
        } else if (net.secure && !net.known) {
            asking = net;
            password.text = "";
            password.focusInput();
        } else {
            Net.connect(net, "");
        }
    }

    function key(event) {
        const k = event.key;
        const n = list.length;
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < n - 1) {
            cursor++;
            return true;
        }
        if (n > 0 && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
            activate(list[cursor]);
            return true;
        }
        if (n > 0 && (k === Qt.Key_Delete) && list[cursor].known) {
            Net.forget(list[cursor]);
            return true;
        }
        return false;
    }

    onListChanged: cursor = Math.min(cursor, Math.max(0, list.length - 1))

    Text {
        visible: wifi.list.length === 0
        x: 12
        y: 9
        text: Net.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Column {
        width: parent.width

        Repeater {
            model: wifi.list

            ListLine {
                id: entry

                required property var modelData
                required property int index

                width: wifi.width
                name: entry.modelData.ssid
                detail: [entry.modelData.active ? "connected" : "", entry.modelData.known && !entry.modelData.active ? "saved" : "",
                    entry.modelData.secure ? "secured" : "open"].filter(t => t !== "").join("  ·  ")
                lit: entry.modelData.active
                under: wifi.active && wifi.cursor === entry.index
                onEntered: if (wifi.active) wifi.cursor = entry.index
                onClicked: {
                    wifi.picked();
                    wifi.cursor = entry.index;
                    wifi.activate(entry.modelData);
                }

                // Signal: four bars, lit up to the strength; "connecting" while it does.
                Row {
                    spacing: 2

                    Text {
                        visible: Net.busy === entry.modelData.ssid
                        text: "connecting  "
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        color: Theme.accent
                    }
                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            y: 13 - height   // bottoms aligned: the tallest bar is 13
                            width: 3
                            height: 4 + index * 3
                            color: entry.modelData.signal > index * 25 ? (entry.modelData.active ? Theme.accent : Theme.text) : Theme.border
                        }
                    }
                }
            }
            }

        // The password of a new secured network, under the list.
        Item {
            visible: wifi.asking !== null
            width: parent.width
            height: visible ? 48 : 0

            SearchField {
                id: password

                y: 6
                width: parent.width
                echoMode: TextInput.Password
                placeholder: "Password for " + (wifi.asking?.ssid ?? "") + "   (Enter connects, Esc cancels)"
                onAccepted: {
                    Net.connect(wifi.asking, text);
                    text = "";
                    wifi.asking = null;
                    wifi.refocus();
                }
                onCancelled: {
                    text = "";
                    wifi.asking = null;
                    wifi.refocus();
                }
            }
        }
    }

    Text {
        visible: Net.error !== ""
        x: 12
        y: wifi.implicitHeight - 20
        text: Net.error
        font.family: Theme.fontMono
        font.pixelSize: 10
        color: Theme.error
    }
}
