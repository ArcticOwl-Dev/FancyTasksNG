/*
    SPDX-FileCopyrightText: 2026 FancyTasksNG contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/AppRules.js" as AppRules
import "../ui/code/singletones"

ConfigPage {
    id: applicationsPage

    readonly property var migratedApplicationRules: AppRules.migrateFilterRules(cfg_applicationAllowlist,
        cfg_applicationBlocklist, cfg_applicationFilterMode)
    readonly property string currentApplicationRules: cfg_applicationRules !== "" ? cfg_applicationRules
        : migratedApplicationRules !== null ? migratedApplicationRules
        : cfg_applicationFilterMode === 1 ? cfg_applicationAllowlist : cfg_applicationBlocklist

    Component.onCompleted: {
        if (cfg_applicationRules === "" && migratedApplicationRules !== null)
            cfg_applicationRules = migratedApplicationRules;
    }

    WindowInspector {
        id: windowInspector
        canAddRules: filterRulesEditor.parsed.valid
        canEditTitles: titleOverridesEditor.parsed.valid
        onAddRule: (appId, appName) => filterRulesEditor.addApplication(appId, appName)
        onEditTitleOverride: (appId, appName) => titleOverridesEditor.addApplication(appId, appName)
    }

    ConfigScrollView {
        anchors.fill: parent
        cfg_page: applicationsPage

        ColumnLayout {
            id: applicationsColumn
            width: Math.max(0, applicationsPage.width - applicationsPage.gridUnit * 2)
            spacing: applicationsPage.largeSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Information
                text: Wrappers.i18n("Filtering and window-title settings take effect when you apply them. Use the window inspector to choose application IDs.")
            }

            Kirigami.Heading {
                text: Wrappers.i18n("Filtering")
                level: 2
            }

            Button {
                text: Wrappers.i18n("Inspect open windows…")
                icon.name: "window"
                onClicked: windowInspector.open()
            }

            Label {
                text: Wrappers.i18n("Filter mode:")
            }
            ComboBox {
                Layout.fillWidth: true
                model: [Wrappers.i18n("Off"), Wrappers.i18n("Allowlist"), Wrappers.i18n("Blocklist")]
                currentIndex: applicationsPage.cfg_applicationFilterMode
                onActivated: index => applicationsPage.cfg_applicationFilterMode = index
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Wrappers.i18n("The same rules are used in either mode. Allowlist shows only matching applications; Blocklist hides matching applications. Off ignores the rules. Use * at the start or end of App IDs or names to match any sequence. Matching ignores case and a trailing .desktop in App IDs; window titles are not matched.")
            }

            AppRuleEditor {
                id: filterRulesEditor
                Layout.fillWidth: true
                heading: Wrappers.i18n("Application rules")
                serializedRules: applicationsPage.currentApplicationRules
                onEdited: value => applicationsPage.cfg_applicationRules = value
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: applicationsPage.cfg_applicationFilterMode === 1 && filterRulesEditor.parsed.valid && filterRulesEditor.rules.length === 0
                type: Kirigami.MessageType.Warning
                text: Wrappers.i18n("An empty allowlist matches no applications. Only exempt pinned launchers will remain.")
            }

            CheckBox {
                text: Wrappers.i18n("Filter pinned launchers too")
                checked: applicationsPage.cfg_filterPinnedLaunchers
                onToggled: applicationsPage.cfg_filterPinnedLaunchers = checked
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Wrappers.i18n("When unchecked, only pinned launchers without running windows are exempt. A running application is filtered even when it is pinned.")
            }

            AppRuleEditor {
                id: titleOverridesEditor
                Layout.fillWidth: true
                heading: Wrappers.i18n("Title overrides")
                description: Wrappers.i18n("Select Always Icon or Always Label for an app. Leave both unchecked to use the default from Appearance. Use * only at the start or end of App IDs or names to match any sequence of characters.")
                ruleKind: "titles"
                serializedRules: applicationsPage.cfg_applicationTitleOverrides
                onEdited: value => applicationsPage.cfg_applicationTitleOverrides = value
            }

        }
    }
}
