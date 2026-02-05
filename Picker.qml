pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property bool onClient

    property real realBorderWidth: onClient ? (Hypr.options["general:border_size"] ?? 1) : 2
    property real realRounding: onClient ? (root.fetchedRounding ?? 0) : 0
    property int fetchedRounding: 0

    Process {
        id: roundingFetcher
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.fetchedRounding = JSON.parse(data).int;
                } catch (e) {}
            }
        }
    }

    property real ssx
    property real ssy

    property real sx: 0
    property real sy: 0
    property real ex: screen.width
    property real ey: screen.height

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    property var clients: []

    Process {
        id: clientFetcher
        command: ["sh", "-c", "hyprctl -j monitors && echo '|||' && hyprctl -j clients"]

        property string outputBuffer: ""

        stdout: SplitParser {
            onRead: data => clientFetcher.outputBuffer += data
        }

        onRunningChanged: {
            if (running) {
                outputBuffer = "";
                return;
            }

            if (outputBuffer.trim() === "")
                return;

            try {
                const parts = outputBuffer.split("|||");
                if (parts.length < 2)
                    return;

                const monitors = JSON.parse(parts[0]);
                const clientsData = JSON.parse(parts[1]);

                const currentMonitor = monitors.find(m => m.name === screen.name);
                if (!currentMonitor)
                    return;

                let wsId = -1;

                if (currentMonitor.specialWorkspace && currentMonitor.specialWorkspace.name) {
                    wsId = currentMonitor.specialWorkspace.id;
                } else if (currentMonitor.activeWorkspace) {
                    wsId = currentMonitor.activeWorkspace.id;
                }

                const filtered = clientsData.filter(c => {
                    if (!c || c.hidden)
                        return false;
                    return c.workspace.id === wsId;
                }).map(c => {
                    return {
                        lastIpcObject: c
                    };
                }).sort((a, b) => {
                    const ac = a.lastIpcObject;
                    const bc = b.lastIpcObject;

                    if (ac.pinned !== bc.pinned)
                        return bc.pinned - ac.pinned;
                    if (ac.floating !== bc.floating)
                        return bc.floating - ac.floating;

                    const sa = ac.size || [0, 0];
                    const sb = bc.size || [0, 0];
                    const areaA = sa[0] * sa[1];
                    const areaB = sb[0] * sb[1];
                    return areaA - areaB;
                });

                root.clients = filtered;

                if (filtered.length > 0) {
                    const c = filtered[0];
                    if (c && c.lastIpcObject && c.lastIpcObject.at && c.lastIpcObject.size) {
                        const cx = c.lastIpcObject.at[0] - screen.x;
                        const cy = c.lastIpcObject.at[1] - screen.y;
                        onClient = true;
                        sx = cx;
                        sy = cy;
                        ex = cx + c.lastIpcObject.size[0];
                        ey = cy + c.lastIpcObject.size[1];
                    }
                } else {
                    sx = screen.width / 2;
                    sy = screen.height / 2;
                    ex = screen.width / 2;
                    ey = screen.height / 2;
                }
            } catch (e) {}
        }
    }

    function checkClientRects(x: real, y: real): void {
        onClient = false;

        let found = false;

        for (const client of clients) {
            if (!client || !client.lastIpcObject)
                continue;

            const ipc = client.lastIpcObject;
            if (!ipc.at || !ipc.size)
                continue;

            let {
                at: [cx, cy],
                size: [cw, ch]
            } = ipc;
            cx -= screen.x;
            cy -= screen.y;
            if (cx <= x && cy <= y && cx + cw >= x && cy + ch >= y) {
                onClient = true;
                found = true;
                sx = cx;
                sy = cy;
                ex = cx + cw;
                ey = cy + ch;
                break;
            }
        }

        if (!found) {
            sx = x;
            sy = y;
            ex = x;
            ey = y;
        }
    }

    Timer {
        id: captureTimer
        interval: 33
        repeat: false
        property string command: ""
        onTriggered: {
            Quickshell.execDetached(["sh", "-c", command]);
            closeAnim.start();
        }
    }

    function save(): void {
        const absX = Math.floor(screen.x + rsx);
        const absY = Math.floor(screen.y + rsy);
        const width = Math.floor(sw);
        const height = Math.floor(sh);

        const geom = (width < 2 || height < 2) ? `${screen.x},${screen.y} ${screen.width}x${screen.height}` : `${absX},${absY} ${width}x${height}`;

        const tmpfile = `/tmp/screenshot-${Date.now()}.png`;

        overlay.visible = false;
        border.visible = false;
        root.loader.closing = true;

        let finalCmd = "";
        if (root.loader.clipboardOnly) {
            finalCmd = `grim -g "${geom}" - | wl-copy --type image/png && notify-send -a "Screenshot" "Screenshot taken" "Screnshot copied to clipboard"`;
        } else {
            finalCmd = `grim -g "${geom}" "${tmpfile}" && swappy -f "${tmpfile}"`;
        }

        captureTimer.command = finalCmd;
        captureTimer.start();
    }

    onClientsChanged: checkClientRects(mouseX, mouseY)

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.CrossCursor

    Component.onCompleted: {
        try {
            Hypr.extras.refreshOptions();
        } catch (e) {}

        clientFetcher.running = true;

        if (loader.freeze)
            clients = clients;

        opacity = 1;
    }

    onPressed: event => {
        ssx = event.x;
        ssy = event.y;
    }

    onReleased: {
        if (closeAnim.running)
            return;

        if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            save();
        }
    }

    onPositionChanged: event => {
        const x = event.x;
        const y = event.y;

        if (pressed) {
            onClient = false;
            sx = ssx;
            sy = ssy;
            ex = x;
            ey = y;
        } else {
            checkClientRects(x, y);
        }
    }

    focus: true
    Keys.onEscapePressed: closeAnim.start()

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.large
            }
            ExAnim {
                target: root
                properties: "rsx,rsy"
                to: 0
            }
            ExAnim {
                target: root
                property: "sw"
                to: root.screen.width
            }
            ExAnim {
                target: root
                property: "sh"
                to: root.screen.height
            }
        }
        PropertyAction {
            target: root.loader
            property: "active"
            value: false
        }
    }

    Loader {
        id: screencopy

        anchors.fill: parent

        active: root.loader.freeze
        asynchronous: true

        sourceComponent: ScreencopyView {
            captureSource: root.screen

            onHasContentChanged: {
                if (hasContent && !root.loader.freeze) {
                    overlay.visible = border.visible = true;
                    root.save();
                }
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: MultiEffect {
            maskSource: selectionWrapper
            maskEnabled: true
            maskInverted: true
            maskSpreadAtMin: 1
            maskThresholdMin: 0.5
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            color: "white"
            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        id: border

        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        visible: root.sw > 1 && root.sh > 1

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.large
        }
    }

    Behavior on rsx {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on rsy {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on sw {
        enabled: !root.pressed

        ExAnim {}
    }

    Behavior on sh {
        enabled: !root.pressed

        ExAnim {}
    }

    component ExAnim: Anim {
        duration: Appearance.anim.durations.expressiveDefaultSpatial
        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
    }
}
