import QtQuick
import qs.modules.common
import qs.services

// A setting typed by hand (the computer's name): its value, and Enter opens a field with it, Enter saves, Esc
// cancels. `setting.validate` (a regex source) keeps an impossible value from being sent.
Item {
    id: edit

    property var setting
    property bool active: false
    property bool editing: false

    signal picked
    signal refocus

    implicitHeight: 40

    function start() {
        editing = true;
        field.text = String(Registry.value(setting));
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
        visible: !edit.editing
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Registry.valueText(edit.setting) + (edit.active ? "      ↵ change" : "")
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: Theme.text

        TapHandler {
            onTapped: {
                edit.picked();
                edit.start();
            }
        }
    }

    SearchField {
        id: field

        visible: edit.editing
        width: parent.width
        placeholder: edit.setting?.placeholder ?? ""
        onAccepted: {
            const v = text.trim();
            if (edit.setting.validate && !new RegExp(edit.setting.validate).test(v))
                return;
            Registry.set(edit.setting, v);
            edit.stop();
        }
        onCancelled: edit.stop()
    }
}
