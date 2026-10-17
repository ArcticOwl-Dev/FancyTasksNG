/*
    SPDX-FileCopyrightText: 2026 FancyTasksNG contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

import "../ui/code/singletones"

Dialog {
    id: inspector
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Kirigami.Units.gridUnit * 2 : 800, 900)
    height: Math.min(parent ? parent.height - Kirigami.Units.gridUnit * 2 : 600, 700)
    modal: true
    focus: true
    title: Wrappers.i18n("Open windows")
    standardButtons: Dialog.Close

    property bool canAddRules: true
    property bool canEditTitles: true
    property var windows: []
    readonly property var matchingWindows: windows.filter(window => {
        const query = searchField.text.trim().toLowerCase();
        return !query || [window.appName, window.appId, window.title, window.ids].some(value => value.toLowerCase().includes(query));
    })
    readonly property var selectedWindow: windowList.currentIndex >= 0 && windowList.currentIndex < matchingWindows.length
        ? matchingWindows[windowList.currentIndex] : null
    readonly property bool hasIdentity: selectedWindow !== null && !!(selectedWindow.appId.trim() || selectedWindow.appName.trim())
    signal addRule(string appId, string appName)
    signal editTitleOverride(string appId, string appName)

    // Independent of the panel's grouping, launcher list and display filters.
    TaskManager.TasksModel {
        id: sourceModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        launcherList: []
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterMinimized: false
        filterNotMinimized: false
        filterNotMaximized: false
        filterHidden: false
        // Populate asynchronously when the page is first opened.
        onCountChanged: if (inspector.visible) refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 100
        onTriggered: inspector.refresh()
    }

    function refresh() {
        const next = [];
        for (let row = 0; row < sourceModel.count; ++row) {
            const index = sourceModel.index(row, 0);
            if (sourceModel.data(index, TaskManager.AbstractTasksModel.IsWindow) !== true)
                continue;
            const ids = sourceModel.data(index, TaskManager.AbstractTasksModel.WinIdList);
            next.push({
                appName: String(sourceModel.data(index, TaskManager.AbstractTasksModel.AppName) || ""),
                appId: String(sourceModel.data(index, TaskManager.AbstractTasksModel.AppId) || ""),
                title: String(sourceModel.data(index, Qt.DisplayRole) || ""),
                icon: sourceModel.data(index, Qt.DecorationRole),
                ids: ids && ids.length ? Array.from(ids, value => String(value)).join(", ") : ""
            });
        }
        windowList.currentIndex = -1;
        windows = next;
    }

    function displayed(value) {
        return value || Wrappers.i18n("Unavailable");
    }

    onOpened: {
        searchField.clear();
        refresh();
        searchField.forceActiveFocus();
    }
    onClosed: refreshTimer.stop()
    onMatchingWindowsChanged: windowList.currentIndex = -1

    contentItem: ColumnLayout {
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Wrappers.i18n("Search application, ID or window title…")
            }
            Button {
                text: Wrappers.i18n("Refresh")
                icon.name: "view-refresh"
                onClicked: inspector.refresh()
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: Wrappers.i18n("Select a window to copy its details or prepare a rule. Refresh to update window titles. Rules are saved only when you apply the settings.")
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ListView {
                id: windowList
                model: inspector.matchingWindows
                currentIndex: -1
                spacing: Kirigami.Units.smallSpacing
                delegate: ItemDelegate {
                    id: windowRow
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    highlighted: ListView.isCurrentItem
                    onClicked: windowList.currentIndex = index
                    contentItem: RowLayout {
                        Kirigami.Icon {
                            source: windowRow.modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                wrapMode: Text.WrapAnywhere
                                font.bold: true
                                text: inspector.displayed(windowRow.modelData.appName)
                            }
                            Label {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                wrapMode: Text.WrapAnywhere
                                text: Wrappers.i18n("App ID: %1", inspector.displayed(windowRow.modelData.appId))
                            }
                            Label {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                wrapMode: Text.WrapAnywhere
                                text: Wrappers.i18n("Title: %1", inspector.displayed(windowRow.modelData.title))
                            }
                        }
                    }
                }
            }
        }

        Label {
            visible: inspector.matchingWindows.length === 0
            text: inspector.windows.length ? Wrappers.i18n("No matching windows") : Wrappers.i18n("No windows reported by KDE TaskManager")
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
            TextArea {
                id: details
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WrapAnywhere
                text: inspector.selectedWindow ? Wrappers.i18n("App Name: %1\nApp ID: %2\nTitle: %3\nWindow IDs: %4",
                    inspector.displayed(inspector.selectedWindow.appName), inspector.displayed(inspector.selectedWindow.appId),
                    inspector.displayed(inspector.selectedWindow.title), inspector.displayed(inspector.selectedWindow.ids)) : ""
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Button {
                text: Wrappers.i18n("Copy details")
                icon.name: "edit-copy"
                enabled: inspector.selectedWindow !== null
                onClicked: {
                    details.selectAll();
                    details.copy();
                    details.deselect();
                }
            }
            Button {
                text: Wrappers.i18n("Add to rules…")
                enabled: inspector.hasIdentity && inspector.canAddRules
                onClicked: {
                    const window = inspector.selectedWindow;
                    inspector.close();
                    inspector.addRule(window.appId, window.appName);
                }
            }
            Button {
                text: Wrappers.i18n("Set title behavior…")
                enabled: inspector.hasIdentity && inspector.canEditTitles
                onClicked: {
                    const window = inspector.selectedWindow;
                    inspector.close();
                    inspector.editTitleOverride(window.appId, window.appName);
                }
            }
        }
    }
}
