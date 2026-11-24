pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import qs.services

// The status panel's Wi-Fi view (right-click on Wi-Fi): the radio, the networks around, connect or disconnect with a click.
// A new secured network asks its password right under the list.
Item {
    id: wifi

    required property bool shown

    property var asking: null   // the network whose password is being typed

    signal back

    height: 330

    onShownChanged: {
        Network.watching = shown;
        if (!shown)
            asking = null;
    }

    function activate(net) {
        if (net.active) {
            Network.disconnectFrom(net);
        } else if (net.secure && !net.known) {
            asking = net;
            password.text = "";
            password.focusInput();
        } else {
            Network.connectTo(net, "");
        }
    }

    SubHeader {
        id: head
        width: parent.width
        title: "Wi-Fi"
        on: Network.wifiEnabled
        onBack: wifi.back()
        onSwitched: Network.setWifi(!Network.wifiEnabled)
    }

    Rectangle {
        y: head.height + 4
        width: parent.width
        height: 1
        color: Theme.border
    }

    Text {
        visible: Network.networks.length === 0
        x: 4
        y: head.height + 16
        text: Network.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off"
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
        model: Network.networks

        delegate: DeviceRow {
            id: entry

            required property var modelData

            width: view.width
            name: modelData.ssid
            detail: [modelData.active ? "connected" : "", modelData.known && !modelData.active ? "saved" : "",
                modelData.secure ? "secured" : "open"].filter(t => t !== "").join("  ·  ")
            lit: modelData.active
            onClicked: wifi.activate(modelData)

            Row {
                spacing: 2

                Text {
                    visible: Network.busy === entry.modelData.ssid
                    text: "connecting  "
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    color: Theme.accent
                }
                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        y: 13 - height
                        width: 3
                        height: 4 + index * 3
                        color: entry.modelData.signal > index * 25 ? (entry.modelData.active ? Theme.accent : Theme.text) : Theme.border
                    }
                }
            }
        }
    }

    Item {
        id: footer
        y: parent.height - height
        width: parent.width
        height: wifi.asking ? 52 : 20

        SearchField {
            id: password
            visible: wifi.asking !== null
            y: 6
            width: parent.width
            echoMode: TextInput.Password
            placeholder: "Password for " + (wifi.asking?.ssid ?? "") + "   (Enter connects, Esc cancels)"
            onAccepted: {
                Network.connectTo(wifi.asking, text);
                text = "";
                wifi.asking = null;
            }
            onCancelled: {
                text = "";
                wifi.asking = null;
            }
        }
        Text {
            visible: wifi.asking === null
            x: 4
            anchors.bottom: parent.bottom
            width: parent.width - 8
            elide: Text.ElideRight
            text: Network.error !== "" ? Network.error : "click to connect · ‹ or right-click goes back"
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Network.error !== "" ? Theme.error : Theme.muted
        }
    }
}
