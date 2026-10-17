/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import "experimental" as Experimental

PlasmoidItem {
    id: host
    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 600)
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "M6 diagnostic: one static icon, no live task row. The default surface passes all pointer input through, including over the icon. Whole-window input also captures transparent space. Neither mode satisfies the overlay input-region requirement."
            }
            CheckBox {
                text: "Show persistent prototype"
                checked: Plasmoid.configuration.experimentalFloatingOverlay
                onToggled: Plasmoid.configuration.experimentalFloatingOverlay = checked
            }
            CheckBox {
                text: "Accept whole-window input (diagnostic only)"
                checked: prototype.wholeWindowInput
                onToggled: prototype.wholeWindowInput = checked
            }
            Label { text: "Icon clicks: " + prototype.clickCount + "; maps: " + prototype.mapCount }
        }
        Rectangle {
            id: panelAnchor
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 240
            height: 32
            color: "#555555"
        }
        Experimental.OverlayPrototype {
            id: prototype
            anchor: panelAnchor
            requested: Plasmoid.configuration.experimentalFloatingOverlay
        }
        Timer {
            interval: 400
            running: true
            onTriggered: Plasmoid.configuration.experimentalFloatingOverlay = true
        }
        Timer {
            interval: 2200
            running: true
            onTriggered: {
                const window = prototype.surface;
                console.log("M6_PROBE", "visible", window.visible, "active", window.active, "maps", prototype.mapCount,
                    "setMask", typeof window["setMask"], "inputRegion", typeof window["inputRegion"], "selectiveInput", prototype.selectiveInputAvailable);
            }
        }
    }
}
