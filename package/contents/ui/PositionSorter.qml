/* SPDX-License-Identifier: GPL-2.0-or-later */

import QtQuick
import org.kde.taskmanager as TaskManager
import "code/PositionOrder.js" as PositionOrder

QtObject {
    id: sorter
    required property TaskManager.TasksModel model
    property bool enabled: false
    property var state: PositionOrder.createState()
    property bool applying: false
    property var pendingOrder: []

    function snapshot() {
        const entries = [];
        for (let row = 0; row < model.count; ++row) {
            const index = model.index(row, 0);
            const data = role => model.data(index, role);
            const launcher = data(TaskManager.AbstractTasksModel.IsLauncher) === true;
            const app = String(data(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || data(TaskManager.AbstractTasksModel.AppId) || "");
            const ids = data(TaskManager.AbstractTasksModel.WinIdList);
            const grouped = model.groupMode !== TaskManager.TasksModel.GroupDisabled
                && data(TaskManager.AbstractTasksModel.IsGroupable) === true;
            const key = launcher ? "launcher:" + app : grouped && app ? "group:" + app
                : ids && ids.length ? "window:" + String(ids[0]) : "startup:" + app;
            let geometry = data(TaskManager.AbstractTasksModel.Geometry);
            let x = geometry && geometry.width > 0 ? geometry.x : Infinity;
            // Group geometry can depend on the active member. Read each child.
            if (data(TaskManager.AbstractTasksModel.IsGroupParent)) {
                x = Infinity;
                for (let child = 0; child < model.rowCount(index); ++child) {
                    geometry = model.data(model.index(child, 0, index), TaskManager.AbstractTasksModel.Geometry);
                    if (geometry && geometry.width > 0)
                        x = Math.min(x, geometry.x);
                }
            }
            const previous = entries[entries.length - 1];
            // KDE moves flattened groups as a block; keep that same unit.
            if (previous && previous.key === key && !launcher) {
                previous.x = Math.min(previous.x, x);
                previous.size++;
            } else {
                entries.push({key: key, x: x, row: row, size: 1, launcher: launcher});
            }
        }
        return entries;
    }

    function schedule() {
        if (!enabled || applying)
            return;
        pendingOrder = PositionOrder.orderedKeys(state, snapshot());
        reorderTimer.restart();
    }

    function reorder() {
        if (!enabled)
            return;
        applying = true;
        let target = 0;
        for (const key of pendingOrder) {
            const entry = snapshot().find(item => item.key === key);
            if (!entry)
                continue;
            if (entry.row !== target)
                model.move(entry.row, target);
            target += entry.size;
        }
        applying = false;
    }

    onEnabledChanged: {
        state = PositionOrder.createState();
        schedule();
    }
    property Timer reorderTimer: Timer {
        interval: 0
        onTriggered: sorter.reorder()
    }
    property Connections changes: Connections {
        target: sorter.model
        function onDataChanged() { sorter.schedule(); }
        function onRowsInserted() { sorter.schedule(); }
        function onRowsRemoved() { sorter.schedule(); }
        function onModelReset() { sorter.schedule(); }
        function onLayoutChanged() { sorter.schedule(); }
    }
}
