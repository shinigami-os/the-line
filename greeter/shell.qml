//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The Line's login screen, run by greetd under cage (greeter/launch.sh). QS_TESTING=1 runs it inside a session to
// look at it: over the screen named by QS_SCREEN (or the first), "test" as the password, nothing launched.
ShellRoot {
    id: root

    readonly property var testScreen: Quickshell.screens.find(s => s.name === Quickshell.env("QS_SCREEN")) ?? Quickshell.screens[0]

    Loader {
        active: Login.testing
        sourceComponent: PanelWindow {
            screen: root.testScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "the-line-greeter-test"

            Greeter {
                anchors.fill: parent
            }
        }
    }

    // Under cage, one window: cage makes it fill the screen.
    Loader {
        active: !Login.testing
        sourceComponent: FloatingWindow {
            visible: true
            color: "black"
            implicitWidth: Quickshell.screens[0]?.width ?? 1920
            implicitHeight: Quickshell.screens[0]?.height ?? 1080

            Greeter {
                anchors.fill: parent
            }
        }
    }
}
