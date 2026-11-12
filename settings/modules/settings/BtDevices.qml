pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import qs.services

// Settings > Bluetooth > Devices: connected first, then paired, then the ones met while looking for devices.
// Enter connects or disconnects (a new one is paired and trusted first), Delete forgets a paired one.
Item {
    id: bt

    property var setting
    property bool active: false
    property int cursor: 0

    signal picked

    readonly property var list: Bt.devices
    implicitHeight: Math.max(1, list.length) * 34

    onListChanged: cursor = Math.min(cursor, Math.max(0, list.length - 1))

    function key(event) {
        const k = event.key;
        if (k === Qt.Key_Up && cursor > 0) {
            cursor--;
            return true;
        }
        if (k === Qt.Key_Down && cursor < list.length - 1) {
            cursor++;
            return true;
        }
        if (list.length > 0 && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
            Bt.toggle(list[cursor]);
            return true;
        }
        if (list.length > 0 && k === Qt.Key_Delete && list[cursor].paired) {
            list[cursor].forget();
            return true;
        }
        return false;
    }

    function state(d) {
        if (d.pairing)
            return "pairing…";
        if (d.state === 2 || d.state === 3)   // BluetoothDeviceState.Connecting / Disconnecting
            return d.connected ? "disconnecting…" : "connecting…";
        const parts = [];
        if (d.connected)
            parts.push("connected");
        else if (d.paired)
            parts.push("paired");
        else
            parts.push("nearby");
        if (d.batteryAvailable)
            parts.push(Math.round(d.battery * 100) + " %");
        return parts.join("  ·  ");
    }

    Text {
        visible: bt.list.length === 0
        x: 12
        y: 9
        text: !Bt.present ? "No Bluetooth adapter" : !Bt.enabled ? "Bluetooth is off" : "No device yet: turn on “Look for devices”"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Column {
        width: parent.width

        Repeater {
            model: bt.list

            ListLine {
                id: entry

                required property var modelData
                required property int index

                width: bt.width
                name: modelData.name || modelData.address
                detail: modelData.address
                trailing: bt.state(modelData)
                trailingColor: modelData.connected ? Theme.accent : Theme.muted
                lit: modelData.connected
                under: bt.active && bt.cursor === index
                onEntered: if (bt.active) bt.cursor = index
                onClicked: {
                    bt.picked();
                    bt.cursor = index;
                    Bt.toggle(modelData);
                }
            }
        }
    }
}
