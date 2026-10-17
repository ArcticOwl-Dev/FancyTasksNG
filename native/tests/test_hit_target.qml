/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import "../../package/contents/ui" as UI

Item {
    id: scene
    width: 300
    height: 200
    property alias hovered: hover.hovered
    property int clicks: 0
    Item {
        id: button
        x: 100; y: 100; width: 48; height: 48
        Rectangle {
            id: icon
            x: -10; y: -20; width: 68; height: 68
            color: "blue"
        }
        UI.ZoomHitTarget {
            button: button; icon: icon; expanded: true
            HoverHandler { id: hover }
            TapHandler { onTapped: scene.clicks++ }
        }
    }
}
