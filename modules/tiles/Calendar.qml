import QtQuick
import qs.services

// Month grid, weeks start on Monday. Today is an accent cell.
Column {
    id: cal

    property date date: Time.now

    readonly property var cells: {
        const y = date.getFullYear(), m = date.getMonth();
        const offset = (new Date(y, m, 1).getDay() + 6) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < offset; i++)
            out.push(0);
        for (let d = 1; d <= days; d++)
            out.push(d);
        return out;
    }

    // ISO week number.
    readonly property int week: {
        const t = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const dn = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dn);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    spacing: 8

    Item {
        width: cal.width
        height: 16

        Text {
            text: Qt.formatDate(cal.date, "MMMM yyyy")
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.Medium
            color: Theme.text
        }
        Text {
            anchors.right: parent.right
            text: "week " + cal.week
            font.family: Theme.fontMono
            font.pixelSize: 11
            color: Theme.muted
        }
    }

    Grid {
        columns: 7
        width: cal.width

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            Text {
                required property string modelData

                width: cal.width / 7
                height: 16
                text: modelData
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.fontUi
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                color: Theme.muted
            }
        }

        Repeater {
            model: cal.cells

            Rectangle {
                required property int modelData
                readonly property bool today: modelData === cal.date.getDate()

                width: cal.width / 7
                height: 26
                color: today ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? parent.modelData : ""
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: parent.today ? Font.Bold : Font.Medium
                    font.features: { "lnum": 1, "tnum": 1 }
                    color: parent.today ? Theme.accentText : Theme.text
                }
            }
        }
    }
}
