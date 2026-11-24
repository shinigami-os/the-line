pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import TheLine.Ui
import qs.services

// The status panel's Bluetooth view (right-click on Bluetooth): the adapter, its devices (connected first, then paired,
// then the ones met while looking), connect or disconnect with a click. It looks for new devices while it is shown.
Item {
    id: bt

    required property bool shown

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: !adapter ? [] : adapter.devices.values.slice()
        .filter(d => d.paired || d.connected || d.name !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    // A device paired from here connects once the pairing is done.
    property var pairing: null

    signal back

    height: 330

    onShownChanged: {
        if (adapter && (!shown || enabled))
            adapter.discovering = shown;
    }
    onEnabledChanged: if (shown && adapter && enabled) adapter.discovering = true

    function toggle(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            device.trusted = true;
            pairing = device;
            device.pair();
        }
    }

    function stateOf(d) {
        if (d.pairing)
            return "pairing…";
        if (d.state === 2 || d.state === 3)   // BluetoothDeviceState.Connecting / Disconnecting
            return d.connected ? "disconnecting…" : "connecting…";
        const parts = [d.connected ? "connected" : (d.paired ? "paired" : "nearby")];
        if (d.batteryAvailable)
            parts.push(Math.round(d.battery * 100) + " %");
        return parts.join("  ·  ");
    }

    Connections {
        target: bt.pairing
        ignoreUnknownSignals: true

        function onPairedChanged() {
            if (bt.pairing?.paired) {
                bt.pairing.connect();
                bt.pairing = null;
            }
        }
    }

    SubHeader {
        id: head
        width: parent.width
        title: "Bluetooth"
        available: bt.adapter !== null
        on: bt.enabled
        onBack: bt.back()
        onSwitched: bt.adapter.enabled = !bt.adapter.enabled
    }

    Rectangle {
        y: head.height + 4
        width: parent.width
        height: 1
        color: Theme.border
    }

    Text {
        visible: bt.devices.length === 0
        x: 4
        y: head.height + 16
        text: !bt.adapter ? "No Bluetooth adapter" : !bt.enabled ? "Bluetooth is off" : "Looking for devices…"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    ListView {
        id: view
        y: head.height + 6
        width: parent.width
        height: footer.y - y - 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: bt.devices

        delegate: DeviceRow {
            id: entry

            required property var modelData

            width: view.width
            name: modelData.name || modelData.address
            detail: modelData.address
            status: bt.stateOf(modelData)
            statusColor: modelData.connected ? Theme.accent : Theme.muted
            lit: modelData.connected
            onClicked: bt.toggle(modelData)
        }
    }

    Text {
        id: footer
        x: 4
        y: parent.height - height
        width: parent.width - 8
        elide: Text.ElideRight
        text: "click to connect · ‹ or right-click goes back"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }
}
