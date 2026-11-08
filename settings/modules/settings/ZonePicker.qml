pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

// Settings > System > Time zone: the zone in use and the local time there; Enter searches every zone
// ("paris", "new york", "tokyo"), Enter picks one.
Item {
    id: zones

    property var setting
    property bool active: false
    property bool searching: false
    property string query: ""
    property int pick: 0

    signal picked
    signal refocus

    readonly property var matches: {
        const q = query.trim().toLowerCase().replace(/\s+/g, "_");
        if (q === "")
            return [];
        return Sys.zones.filter(z => z.toLowerCase().includes(q)).slice(0, 7);
    }

    implicitHeight: searching ? 44 + matches.length * 32 : 40

    function start() {
        searching = true;
        query = "";
        pick = 0;
        field.text = "";
        field.focusInput();
    }

    function stop() {
        searching = false;
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
        visible: !zones.searching
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Sys.timezone.replace(/_/g, " ") + "      " + Qt.formatTime(Time.now, "HH:mm") + (zones.active ? "      ↵ change" : "")
        font.family: Theme.fontMono
        font.pixelSize: 12
        color: Theme.text

        TapHandler {
            onTapped: {
                zones.picked();
                zones.start();
            }
        }
    }

    Column {
        visible: zones.searching
        width: parent.width

        SearchField {
            id: field

            width: parent.width
            placeholder: "A city or a region (Paris, New York, Tokyo…)"
            onTextChanged: {
                zones.query = text;
                zones.pick = 0;
            }
            onMoved: (dx, dy) => {
                if (dy !== 0 && zones.matches.length > 0)
                    zones.pick = (zones.pick + dy + zones.matches.length) % zones.matches.length;
            }
            onAccepted: {
                if (zones.matches.length > 0)
                    Registry.set(zones.setting, zones.matches[zones.pick]);
                zones.stop();
            }
            onCancelled: zones.stop()
        }

        Repeater {
            model: zones.searching ? zones.matches : []

            ListLine {
                required property string modelData
                required property int index

                width: zones.width
                name: modelData.split("/").pop().replace(/_/g, " ")
                detail: modelData
                under: index === zones.pick
                onEntered: zones.pick = index
                onClicked: {
                    Registry.set(zones.setting, modelData);
                    zones.stop();
                }
            }
        }
    }
}
