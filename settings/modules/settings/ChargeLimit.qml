import QtQuick
import TheLine.Ui
import qs.services

// Settings > Power & idle > Stop charging at: 50 to 100 %, by 5. Only batteries whose driver offers it
// (charge_control_end_threshold); others say so.
Item {
    id: charge

    property var setting
    property bool active: false
    property int pending: Sys.chargeLimit

    signal picked

    implicitHeight: 34

    onActiveChanged: pending = Sys.chargeLimit

    function key(event) {
        if (!Sys.chargeSupported)
            return false;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            pending = Math.max(50, Math.min(100, pending + (event.key === Qt.Key_Left ? -5 : 5)));
            apply.restart();
            return true;
        }
        return false;
    }

    // One password prompt for a run of ←→, not one per step.
    Timer {
        id: apply
        interval: 900
        onTriggered: if (charge.pending !== Sys.chargeLimit) Sys.set("chargeLimit", charge.pending)
    }

    Text {
        visible: !Sys.chargeSupported
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "This battery doesn't let the system set a limit"
        font.family: Theme.fontMono
        font.pixelSize: 11
        color: Theme.muted
    }

    Row {
        visible: Sys.chargeSupported
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        LineSlider {
            width: 300
            anchors.verticalCenter: parent.verticalCenter
            value: (charge.pending - 50) / 50
            onMoved: v => {
                charge.picked();
                charge.pending = 50 + Math.round(v * 10) * 5;
                apply.restart();
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: charge.pending + " %" + (charge.pending === 100 ? "  (no limit)" : "")
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.text
        }
    }
}
