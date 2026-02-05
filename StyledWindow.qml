import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property string name

    WlrLayershell.namespace: `caelestia-${name}`
    color: "transparent"
    
    Component.onCompleted: {
        // console.log("StyledWindow Created: " + name);
    }
}
