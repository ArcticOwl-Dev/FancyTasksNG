/* SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// M6 diagnostic only. The normal renderer never instantiates this component.
// Whole-window transparency is safe for the desktop but also disables the icon.
// Whole-window input demonstrates why a selective compositor input region is
// required before the task row can be moved into a persistent surface.
QtObject {
    id: probe
    required property Item anchor
    property bool requested: false
    property bool wholeWindowInput: false
    property int clickCount: 0
    property int mapCount: 0
    readonly property alias surface: surface
    readonly property bool selectiveInputAvailable: false

    property PlasmaCore.Dialog window: PlasmaCore.Dialog {
        id: surface
        visualParent: probe.anchor
        location: PlasmaCore.Types.BottomEdge
        type: PlasmaCore.Dialog.Tooltip
        backgroundHints: PlasmaCore.Types.NoBackground
        hideOnWindowDeactivate: false
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
            | (probe.wholeWindowInput ? 0 : Qt.WindowTransparentForInput)
        visible: probe.requested && probe.anchor.visible
        onVisibleChanged: if (visible) probe.mapCount++

        mainItem: Item {
            width: 240
            height: 96
            Kirigami.Icon {
                id: testIcon
                width: 64
                height: 64
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                source: "preferences-system"
                MouseArea {
                    anchors.fill: parent
                    onClicked: probe.clickCount++
                }
            }
        }
    }
}
