/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import "native" as Native

// Loaded only on request. Missing/incompatible native support leaves the
// original row in the panel. There is always one model and one set of delegates.
Item {
    id: overlay
    required property var tasksRoot
    readonly property alias contentHost: rowHost
    property bool operational: false
    function ownsKeyboardFocus() { return region.ownsKeyboardFocus(surface); }
    readonly property int padding: Math.ceil(Math.max(tasksRoot.height, tasksRoot.config.iconSizeOverride ? tasksRoot.config.iconSizePx : 0)
        * Math.max(1, tasksRoot.config.iconScale / 100)
        * (1 + Math.max(0, tasksRoot.config.iconZoomFactor) / Math.max(1, tasksRoot.height))) + 32

    function updateMask() {
        if (!operational) return;
        const rectangles = [];
        for (const button of tasksRoot.taskList.children) {
            if (!button.model || !button.visible || button.width <= 0 || button.height <= 0) continue;
            for (const item of [button, button.taskIcon]) {
                if (!item) continue;
                const a = item.mapToItem(scene, 0, 0);
                const b = item.mapToItem(scene, item.width, item.height);
                rectangles.push(Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y)));
            }
        }
        if (!region.apply(surface, rectangles)) {
            operational = false;
            console.warn("FancyTasksNG: could not apply overlay input region; using panel rendering.");
        }
    }

    function updatePlacement() {
        if (!operational) return;
        const dodging = region.dodgeActive && !tasksRoot.overlayInteractionActive
            && !panelHeldOpen && !region.panelContainsPointer();
        const show = !dodging && region.anchorVisible(tasksRoot) && !tasksRoot.shouldShrinkToZero
            && !tasksRoot.activeFullscreenOnScreen(region.screenGeometry(tasksRoot));
        // Set the mask before mapping, so transparent pixels never get a
        // full-window input region during initial presentation.
        updateMask();
        if (show && !surface.visible) region.position(surface, tasksRoot, Qt.point(-padding, -padding));
        if (surface.visible !== show) {
            if (!show) tasksRoot.hideTooltipImmediately();
            surface.visible = show;
        }
        if (show) region.position(surface, tasksRoot, Qt.point(-padding, -padding));
    }

    readonly property bool panelHeldOpen: tasksRoot.containment
        && tasksRoot.containment.status >= PlasmaCore.Types.NeedsAttentionStatus
        && tasksRoot.containment.status !== PlasmaCore.Types.HiddenStatus
    onPanelHeldOpenChanged: placementTimer.restart()

    Native.WindowRegion { id: region }
    Connections {
        target: region
        function onFrameReady() { overlay.updateMask(); }
        // Showing/hiding a Quick window inside another window's render sync
        // can invalidate Qt's render-loop window list. Defer to the event loop;
        // panel overlap changes are delivered in the same event-loop turn.
        function onAnchorStateChanged() { placementTimer.restart(); }
    }
    PlasmaCore.Dialog {
        id: surface
        // A detached notification surface can overhang a layer-shell panel.
        // Panel subsurfaces can be clipped to the panel by the compositor.
        visualParent: null
        transientParent: null
        location: PlasmaCore.Types.BottomEdge
        type: PlasmaCore.Dialog.Notification
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: false
        onWidthChanged: placementTimer.restart()
        onHeightChanged: placementTimer.restart()
        onVisibleChanged: if (visible) placementTimer.restart()
        mainItem: Item {
            id: scene
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: overlay.tasksRoot.panelColorSet
            Kirigami.Theme.colorGroup: overlay.tasksRoot.panelColorGroup
            width: overlay.tasksRoot.width + overlay.padding * 2
            height: overlay.tasksRoot.height + overlay.padding * 2
            Item {
                id: rowHost
                x: overlay.padding
                y: overlay.padding
                width: overlay.tasksRoot.width
                height: overlay.tasksRoot.height
            }
        }
    }
    Timer {
        id: placementTimer
        interval: 0
        onTriggered: overlay.updatePlacement()
    }
    Timer {
        id: maskTimer
        interval: 0
        onTriggered: overlay.updateMask()
    }
    Connections {
        target: overlay.tasksRoot
        function onOverlayMaskUpdateRequested() { maskTimer.restart(); }
        function onWidthChanged() { placementTimer.restart(); }
        function onHeightChanged() { placementTimer.restart(); }
        function onOverlayInteractionActiveChanged() { placementTimer.restart(); }
        function onShouldShrinkToZeroChanged() { placementTimer.restart(); }
        function onVisibleChanged() { placementTimer.restart(); }
    }
    Connections {
        target: overlay.tasksRoot.tasksModel
        function onDataChanged(topLeft, bottomRight, roles) {
            if (!roles.length || roles.includes(TaskManager.AbstractTasksModel.IsActive)
                || roles.includes(TaskManager.AbstractTasksModel.IsFullScreen)
                || roles.includes(TaskManager.AbstractTasksModel.IsMinimized)
                || roles.includes(TaskManager.AbstractTasksModel.ScreenGeometry)) placementTimer.restart();
        }
        function onRowsInserted() { placementTimer.restart(); }
        function onRowsRemoved() { placementTimer.restart(); }
        function onModelReset() { placementTimer.restart(); }
    }
    Component.onCompleted: {
        operational = region.wayland && region.observeAnchor(tasksRoot) && region.apply(surface, []);
        placementTimer.restart();
    }
    Component.onDestruction: {
        operational = false;
        placementTimer.stop();
        maskTimer.stop();
        surface.visible = false;
    }
}
