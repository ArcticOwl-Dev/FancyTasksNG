/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick

Item {
    id: target
    required property Item button
    required property Item icon
    property bool expanded: false
    property rect iconBounds: Qt.rect(0, 0, 0, 0)
    function refresh() { iconBounds = icon.mapToItem(button, 0, 0, icon.width, icon.height); }
    x: expanded ? Math.min(0, iconBounds.x) : 0
    y: expanded ? Math.min(0, iconBounds.y) : 0
    width: (expanded ? Math.max(button.width, iconBounds.x + iconBounds.width) : button.width) - x
    height: (expanded ? Math.max(button.height, iconBounds.y + iconBounds.height) : button.height) - y
    containmentMask: QtObject {
        function contains(point: point): bool {
            const p = target.button.mapFromItem(target, point.x, point.y);
            if (p.x >= 0 && p.y >= 0 && p.x < target.button.width && p.y < target.button.height) return true;
            if (!target.expanded) return false;
            const local = target.icon.mapFromItem(target.button, p.x, p.y);
            return local.x >= 0 && local.y >= 0 && local.x < target.icon.width && local.y < target.icon.height;
        }
    }
    Component.onCompleted: refresh()
}
