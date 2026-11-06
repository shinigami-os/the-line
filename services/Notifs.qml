pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Notification store and toast timing.
// Real daemon (Quickshell.Services.Notifications) comes later; `push` is the single entry point.
Singleton {
    id: root

    property var list: []           // newest first, {id, app, title, body, time, read}
    property var toast: null        // the notification shown in the clock tile, or null
    property var lastToast: null    // kept so the toast text can fade out
    property bool dnd: false
    property var _pending: null
    property int _seq: 0

    readonly property int unread: list.filter(n => !n.read).length

    function push(app, title, body) {
        const n = {
            id: ++_seq,
            app: app,
            title: title,
            body: body,
            time: Qt.formatDateTime(new Date(), "HH:mm"),
            read: UiState.openPanel === "tc"
        };
        list = [n].concat(list).slice(0, 20);
        _pending = n;
        LineState.pulse(!dnd && UiState.openPanel !== "tc");
        showDelay.restart();
    }

    function markAllRead() {
        list = list.map(n => Object.assign({}, n, { read: true }));
    }

    function clear() {
        list = [];
    }

    Connections {
        target: UiState

        function onOpenPanelChanged() {
            if (UiState.openPanel === "tc") {
                root.markAllRead();
                holdTimer.stop();
                root.toast = null;
            }
        }
    }

    // The pulse draws the tile's outline first; the tile grows into it once the dashes reach the bottom corners.
    Timer {
        id: showDelay
        interval: LineState.tileDelay
        onTriggered: {
            if (root.dnd || UiState.openPanel === "tc" || !root._pending)
                return;
            root.toast = root._pending;
            root.lastToast = root._pending;
            holdTimer.restart();
        }
    }

    Timer {
        id: holdTimer
        interval: Anim.toastHold
        onTriggered: root.toast = null
    }
}
