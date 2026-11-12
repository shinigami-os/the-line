import QtQuick
import qs.services

// Month calendar. Weeks start on Monday, ISO week numbers on the left, six rows so the height never changes.
// Arrows or the scroll wheel change the month (a short directional slide); the month name returns to today.
// Clicking today flips the clock face.
Column {
    id: cal

    // rebuilt when the day changes, not at every tick of the clock
    readonly property date today: { Time.today; return new Date(); }
    property int monthOffset: 0

    readonly property date first: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property bool showingToday: monthOffset === 0

    // 42 days from the Monday on or before the 1st.
    readonly property var days: {
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
        return out;
    }

    readonly property real cellW: width / 8

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dn = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dn);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function shift(delta) {
        slide.from = delta > 0 ? 10 : -10;
        monthOffset += delta;
        slideAnim.restart();
    }

    spacing: 8

    // Header: month name (back to today), arrows.
    Item {
        width: cal.width
        height: 16

        Text {
            id: monthLabel
            text: Qt.formatDate(cal.first, "MMMM yyyy")
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.Medium
            color: !cal.showingToday && monthHover.hovered ? Theme.accent : Theme.text

            HoverHandler {
                id: monthHover
                cursorShape: cal.showingToday ? Qt.ArrowCursor : Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: if (!cal.showingToday) cal.shift(-cal.monthOffset)
            }
        }
        Text {
            visible: !cal.showingToday
            anchors.left: monthLabel.right
            anchors.leftMargin: 8
            anchors.verticalCenter: monthLabel.verticalCenter
            text: "today"
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: todayHover.hovered ? Theme.accent : Theme.muted

            HoverHandler {
                id: todayHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: cal.shift(-cal.monthOffset)
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: [-1, 1]

                Rectangle {
                    id: arrow

                    required property int modelData

                    width: 18
                    height: 16
                    color: arrowHover.hovered ? Theme.surface2 : "transparent"
                    border.width: 1
                    border.color: arrowHover.hovered ? Theme.borderStrong : Theme.border

                    Behavior on color {
                        ColorAnimation { duration: Anim.hover }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: arrow.modelData < 0 ? "‹" : "›"
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        color: arrowHover.hovered ? Theme.accent : Theme.muted
                    }
                    HoverHandler {
                        id: arrowHover
                    }
                    TapHandler {
                        onTapped: cal.shift(arrow.modelData)
                    }
                }
            }
        }
    }

    Item {
        width: cal.width
        height: 16 + 6 * 26
        clip: true

        WheelHandler {
            onWheel: event => cal.shift(event.angleDelta.y > 0 ? -1 : 1)
        }

        Item {
            id: grid
            width: parent.width
            height: parent.height

            transform: Translate {
                id: slide
                property real from: 0
            }

            ParallelAnimation {
                id: slideAnim
                NumberAnimation { target: slide; property: "x"; from: slide.from; to: 0; duration: Anim.base; easing.type: Anim.easing }
                NumberAnimation { target: grid; property: "opacity"; from: 0.2; to: 1; duration: Anim.base }
            }

            // Weekday names, after an empty corner over the week numbers.
            Row {
                x: cal.cellW

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]

                    Text {
                        required property string modelData
                        required property int index

                        width: cal.cellW
                        height: 16
                        text: modelData
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Theme.fontUi
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.letterSpacing: 0.6
                        color: index >= 5 ? Theme.borderStrong : Theme.muted
                    }
                }
            }

            Repeater {
                model: 6

                // Easter egg: a click on a week number turns the column into each week's day of the year, today's
                // week showing today's in binary (Eggs.dayOfYear). Again to go back.
                Text {
                    id: weekNo

                    required property int index
                    readonly property var week: cal.days.slice(index * 7, index * 7 + 7)
                    readonly property var todayIn: week.find(d => cal.sameDay(d, cal.today)) ?? null

                    y: 16 + index * 26
                    width: cal.cellW
                    height: 26
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: !Eggs.dayOfYear ? cal.isoWeek(week[0])
                        : todayIn ? cal.dayOfYear(todayIn).toString(2) : cal.dayOfYear(week[0])
                    font.family: Theme.fontMono
                    font.pixelSize: Eggs.dayOfYear && todayIn ? 7 : 10
                    color: Eggs.dayOfYear && todayIn ? Theme.accent : Theme.borderStrong

                    TapHandler {
                        onTapped: Eggs.dayOfYear = !Eggs.dayOfYear
                    }
                }
            }

            Repeater {
                model: cal.days

                Rectangle {
                    id: day

                    required property var modelData
                    required property int index
                    readonly property bool inMonth: modelData.getMonth() === cal.first.getMonth()
                    readonly property bool isToday: cal.sameDay(modelData, cal.today)
                    readonly property bool weekend: index % 7 >= 5

                    x: cal.cellW * (1 + index % 7)
                    y: 16 + Math.floor(index / 7) * 26
                    width: cal.cellW
                    height: 26
                    color: isToday ? Theme.accent : (dayHover.hovered && inMonth ? Theme.surface2 : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Anim.hover }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: day.isToday ? Font.Bold : Font.Medium
                        font.features: { "lnum": 1, "tnum": 1 }
                        color: day.isToday ? Theme.accentText : (!day.inMonth ? Theme.border : (day.weekend ? Theme.muted : Theme.text))
                    }

                    HoverHandler {
                        id: dayHover
                        cursorShape: day.isToday ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    TapHandler {
                        onTapped: if (day.isToday) ClockFace.toggle()
                    }
                }
            }
        }
    }
}
