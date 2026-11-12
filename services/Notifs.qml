pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import TheLine.Ui
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (org.freedesktop.Notifications), the store and the toast timing.
// Low urgency: the pulse only, no toast. Critical: the toast stays twice as long.
// If another daemon already owns the bus name (Sleex while testing), only `push` from IPC works.
Singleton {
    id: root

    property var list: []           // newest first, {id, app, title, body, time, read, urgency, ref}
    property var toast: null        // the notification shown in the clock tile, or null
    property var lastToast: null    // kept so the toast text can fade out
    property bool dnd: false
    // Do not disturb: the button, or the schedule (Settings > Notifications).
    readonly property bool quiet: dnd || (Config.dndScheduled && Config.within(Config.dndFrom, Config.dndTo, Time.now))
    property var _pending: null
    property int _seq: 0

    readonly property int unread: list.filter(n => !n.read).length

    // urgency: 0 low, 1 normal, 2 critical. ref: the daemon's Notification object, if it came from the bus.
    function push(app, title, body, urgency, ref) {
        const n = {
            id: ++_seq,
            app: app,
            title: title,
            body: body,
            time: Qt.formatDateTime(new Date(), "HH:mm"),
            read: UiState.openPanel === "tc",
            urgency: urgency ?? 1,
            ref: ref ?? null
        };
        list = [n].concat(list).slice(0, 20);
        remember(app);
        // muted apps go to the list silently; urgent ones get through do not disturb unless that is turned off
        const muted = (Config.notifMuted ?? []).indexOf(app) >= 0;
        const hushed = quiet && !(n.urgency === 2 && Config.dndUrgent);
        const toastable = n.urgency > 0 && !muted && !hushed && UiState.openPanel !== "tc";
        _pending = toastable ? n : null;
        LineState.pulse(toastable && toast === null);
        if (toastable)
            showDelay.restart();
    }

    // Every app that ever sent a notification, for Settings > Notifications to mute
    // (~/.local/state/the-line/notif-apps.json).
    function remember(app) {
        let known = [];
        try {
            known = JSON.parse(seen.text() || "[]");
        } catch (e) {}
        if (app === "" || known.indexOf(app) >= 0)
            return;
        seen.setText(JSON.stringify(known.concat([app]).sort()));
    }

    FileView {
        id: seen
        path: Quickshell.env("HOME") + "/.local/state/the-line/notif-apps.json"
        blockLoading: true
        printErrors: false
    }

    function markAllRead() {
        list = list.map(n => Object.assign({}, n, { read: true }));
    }

    function clear() {
        for (const n of list)
            n.ref?.dismiss();
        list = [];
    }

    // A click on a card: the notification's default action if it has one, then it goes away.
    function activate(id) {
        const n = list.find(x => x.id === id);
        if (!n)
            return;
        const action = n.ref?.actions?.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        else
            n.ref?.dismiss();
        list = list.filter(x => x.id !== id);
        UiState.close();
    }

    function forget(ref) {
        list = list.filter(x => x.ref !== ref);
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            notification.closed.connect(() => root.forget(notification));
            const urgency = notification.urgency === NotificationUrgency.Critical ? 2 : (notification.urgency === NotificationUrgency.Low ? 0 : 1);
            root.push(notification.appName || "notification", notification.summary, notification.body, urgency, notification);
        }
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
            if (UiState.openPanel === "tc" || !root._pending)
                return;
            root.toast = root._pending;
            root.lastToast = root._pending;
            holdTimer.interval = root._pending.urgency === 2 ? Anim.toastHold * 2 : Anim.toastHold;
            holdTimer.restart();
        }
    }

    Timer {
        id: holdTimer
        onTriggered: root.toast = null
    }
}
