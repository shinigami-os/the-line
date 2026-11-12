import QtQuick
import TheLine.Ui
import qs.services

// Keys drawn as caps, like the cheat sheet's: a combo ("SUPER+SHIFT+S") or caps already named (["Super", "Ctrl"]).
Row {
    id: caps

    property string combo: ""
    property var names: Binds.caps(combo)
    property color tint: Theme.text

    spacing: 4

    Repeater {
        model: caps.names

        Rectangle {
            required property string modelData

            width: capText.implicitWidth + 10
            height: 17
            color: "transparent"
            border.width: 1
            border.color: Theme.borderStrong

            Text {
                id: capText
                anchors.centerIn: parent
                text: parent.modelData
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: caps.tint
            }
        }
    }
}
