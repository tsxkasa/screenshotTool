pragma Singleton
import QtQuick
import Quickshell.Hyprland

QtObject {
    property var toplevels: Hyprland.toplevels
    
    property var options: Hyprland.config || {}
    
    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }
    
    property var extras: QtObject {
        function refreshOptions() {
          // stub
        }
    }
}
