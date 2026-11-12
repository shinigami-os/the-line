import QtQuick
import TheLine.Ui
import qs.services

// Settings > System > Date and time: the clock, live. With the automatic time off, Enter opens a field with the
// current date and time to correct ("2026-11-08 16:30"), Enter sets the clock and the hardware clock.
Item {
    id: clock

    property var setting
    property bool active: false
    property bool editing: false

    signal picked
    signal refocus

    implicitHeight: 40

    function start() {
        if (Sys.ntp)
            return;
        editing = true;
        field.text = Qt.formatDateTime(Time.now, "yyyy-MM-dd HH:mm");
        field.focusInput();
    }

    function stop() {
        editing = false;
        refocus();
    }

    function key(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            start();
            return true;
        }
        return false;
    }

    Text {
        visible: !clock.editing
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(Time.now, "dddd d MMMM yyyy   HH:mm:ss")
            + (clock.active ? (Sys.ntp ? "      set automatically" : "      ↵ change") : "")
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: Theme.text

        TapHandler {
            onTapped: {
                clock.picked();
                clock.start();
            }
        }
    }

    SearchField {
        id: field

        visible: clock.editing
        width: parent.width
        placeholder: "2026-11-08 16:30"
        onAccepted: {
            if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$/.test(text.trim())) {
                Sys.set("time", text.trim());
                clock.stop();
            }
        }
        onCancelled: clock.stop()
    }
}
