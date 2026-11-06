import QtQuick
import QtQuick.Shapes
import qs.services

// A 1.3px stroked icon from an SVG path. Square caps, no emoji, no icon font.
Item {
    id: icon

    property string path
    property color color: Theme.text
    property real strokeWidth: 1.3
    property bool filled: false

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: icon.strokeWidth
            strokeColor: icon.color
            fillColor: icon.filled ? icon.color : "transparent"
            capStyle: ShapePath.FlatCap

            PathSvg {
                path: icon.path
            }
        }
    }
}
