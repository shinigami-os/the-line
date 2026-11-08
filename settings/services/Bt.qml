pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Settings > Bluetooth, on Quickshell's BlueZ service: the adapter's power, scanning and visibility, and its devices.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property bool discoverable: adapter?.discoverable ?? false
    // Connected first, then paired, then the rest (only met while scanning).
    readonly property var devices: !adapter ? [] : adapter.devices.values.slice()
        .filter(d => d.paired || d.connected || d.name !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    function set(key, value) {
        if (!adapter)
            return;
        if (key === "enabled")
            adapter.enabled = value;
        else if (key === "discovering")
            adapter.discovering = value;
        else if (key === "discoverable")
            adapter.discoverable = value;
    }

    // Enter on a device: connect it (pairing it first if needed), or disconnect it.
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

    // A device paired from the app connects once the pairing is done.
    property var pairing: null

    Connections {
        target: root.pairing
        ignoreUnknownSignals: true

        function onPairedChanged() {
            if (root.pairing?.paired) {
                root.pairing.connect();
                root.pairing = null;
            }
        }
    }
}
