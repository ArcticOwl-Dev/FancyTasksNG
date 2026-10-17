/*
    SPDX-FileCopyrightText: 2026 FancyTasksNG contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/AppRules.js" as AppRules
import "../ui/code/singletones"

Item {
    id: editor

    required property string heading
    property string description: ""
    required property string serializedRules
    property string ruleKind: "filter"
    readonly property var parsed: AppRules.parseRules(serializedRules, ruleKind)
    readonly property var rules: parsed.rules
    readonly property real titleTableWidth: Math.min(width, Kirigami.Units.gridUnit * 50)
    readonly property real titleModeColumnWidth: Math.min(Kirigami.Units.gridUnit * 7, titleTableWidth * 0.23)
    readonly property real titleActionsColumnWidth: Math.min(Kirigami.Units.gridUnit * 12, titleTableWidth * 0.27)
    readonly property real titleIdentityColumnWidth: (titleTableWidth - 2 * titleModeColumnWidth - titleActionsColumnWidth) / 2
    readonly property real filterIdentityColumnWidth: (titleTableWidth - titleActionsColumnWidth) / 2
    signal edited(string value)

    implicitWidth: contentLayout.implicitWidth
    implicitHeight: contentLayout.implicitHeight

    ColumnLayout {
        id: contentLayout
        width: parent.width

        Label {
            text: editor.heading
            font.bold: true
        }

        Label {
            Layout.fillWidth: true
            visible: text.length > 0
            text: editor.description
            wrapMode: Text.WordWrap
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !editor.parsed.valid
            type: Kirigami.MessageType.Warning
            text: Wrappers.i18n("These saved rules cannot be read by this version. They will be preserved unless you clear them.")
        }

        Button {
            visible: !editor.parsed.valid
            text: Wrappers.i18n("Clear unreadable rules")
            onClicked: editor.commitRules(AppRules.serializeRules([], editor.ruleKind))
        }

        Label {
            visible: editor.parsed.valid && editor.rules.length === 0
            text: Wrappers.i18n("No rules")
        }

        RowLayout {
            Layout.preferredWidth: editor.titleTableWidth
            Layout.maximumWidth: editor.titleTableWidth
            visible: editor.ruleKind === "titles" && editor.rules.length > 0
            spacing: 0

            Label {
                Layout.preferredWidth: editor.titleIdentityColumnWidth
                Layout.minimumWidth: editor.titleIdentityColumnWidth
                Layout.maximumWidth: editor.titleIdentityColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: Wrappers.i18n("App ID")
                font.bold: true
            }
            Label {
                Layout.preferredWidth: editor.titleIdentityColumnWidth
                Layout.minimumWidth: editor.titleIdentityColumnWidth
                Layout.maximumWidth: editor.titleIdentityColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: Wrappers.i18n("App Name")
                font.bold: true
            }
            Label {
                Layout.preferredWidth: editor.titleModeColumnWidth
                Layout.minimumWidth: editor.titleModeColumnWidth
                Layout.maximumWidth: editor.titleModeColumnWidth
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Wrappers.i18n("Always Icon")
                font.bold: true
            }
            Label {
                Layout.preferredWidth: editor.titleModeColumnWidth
                Layout.minimumWidth: editor.titleModeColumnWidth
                Layout.maximumWidth: editor.titleModeColumnWidth
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Wrappers.i18n("Always Label")
                font.bold: true
            }
            Label {
                Layout.preferredWidth: editor.titleActionsColumnWidth
                Layout.minimumWidth: editor.titleActionsColumnWidth
                Layout.maximumWidth: editor.titleActionsColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: Wrappers.i18n("Actions")
                font.bold: true
            }
        }

        Repeater {
            model: editor.ruleKind === "titles" ? editor.rules : []

            RowLayout {
                id: titleRuleRow
                required property var modelData
                required property int index
                Layout.preferredWidth: editor.titleTableWidth
                Layout.maximumWidth: editor.titleTableWidth
                spacing: 0

                Label {
                    Layout.preferredWidth: editor.titleIdentityColumnWidth
                    Layout.minimumWidth: editor.titleIdentityColumnWidth
                    Layout.maximumWidth: editor.titleIdentityColumnWidth
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    text: titleRuleRow.modelData.field === "appId" ? titleRuleRow.modelData.value : "—"
                }
                Label {
                    Layout.preferredWidth: editor.titleIdentityColumnWidth
                    Layout.minimumWidth: editor.titleIdentityColumnWidth
                    Layout.maximumWidth: editor.titleIdentityColumnWidth
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    text: titleRuleRow.modelData.field === "appName" ? titleRuleRow.modelData.value : "—"
                }
                Item {
                    Layout.preferredWidth: editor.titleModeColumnWidth
                    Layout.minimumWidth: editor.titleModeColumnWidth
                    Layout.maximumWidth: editor.titleModeColumnWidth
                    implicitHeight: iconOnlyCheckBox.implicitHeight

                    CheckBox {
                        id: iconOnlyCheckBox
                        anchors.centerIn: parent
                        checked: titleRuleRow.modelData.mode === "iconOnly"
                        Accessible.name: Wrappers.i18n("Always Icon")
                        onClicked: editor.setTitleMode(titleRuleRow.index, checked ? "iconOnly" : "inherit")
                    }
                }
                Item {
                    Layout.preferredWidth: editor.titleModeColumnWidth
                    Layout.minimumWidth: editor.titleModeColumnWidth
                    Layout.maximumWidth: editor.titleModeColumnWidth
                    implicitHeight: labeledCheckBox.implicitHeight

                    CheckBox {
                        id: labeledCheckBox
                        anchors.centerIn: parent
                        checked: titleRuleRow.modelData.mode === "labeled"
                        Accessible.name: Wrappers.i18n("Always Label")
                        onClicked: editor.setTitleMode(titleRuleRow.index, checked ? "labeled" : "inherit")
                    }
                }
                Item {
                    Layout.preferredWidth: editor.titleActionsColumnWidth
                    Layout.minimumWidth: editor.titleActionsColumnWidth
                    Layout.maximumWidth: editor.titleActionsColumnWidth
                    implicitHeight: titleActionsRow.implicitHeight

                    RowLayout {
                        id: titleActionsRow
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Button {
                            text: Wrappers.i18n("Edit")
                            icon.name: "document-edit"
                            onClicked: editor.openRule(titleRuleRow.index)
                        }
                        Button {
                            text: Wrappers.i18n("Remove")
                            icon.name: "list-remove"
                            onClicked: {
                                const next = editor.rules.slice();
                                next.splice(titleRuleRow.index, 1);
                                editor.commitRules(AppRules.serializeRules(next, editor.ruleKind));
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.preferredWidth: editor.titleTableWidth
            Layout.maximumWidth: editor.titleTableWidth
            visible: editor.ruleKind === "filter" && editor.rules.length > 0
            spacing: 0

            Label {
                Layout.preferredWidth: editor.titleIdentityColumnWidth
                Layout.minimumWidth: editor.titleIdentityColumnWidth
                Layout.maximumWidth: editor.titleIdentityColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: Wrappers.i18n("App ID")
                font.bold: true
            }
            Label {
                Layout.preferredWidth: editor.titleIdentityColumnWidth
                Layout.minimumWidth: editor.titleIdentityColumnWidth
                Layout.maximumWidth: editor.titleIdentityColumnWidth
                horizontalAlignment: Text.AlignHCenter
                text: Wrappers.i18n("App Name")
                font.bold: true
            }
            Item {
                Layout.preferredWidth: editor.titleActionsColumnWidth
                Layout.minimumWidth: editor.titleActionsColumnWidth
                Layout.maximumWidth: editor.titleActionsColumnWidth
            }
        }

        Repeater {
            model: editor.ruleKind === "filter" ? editor.rules : []

            RowLayout {
                id: ruleRow
                required property var modelData
                required property int index
                Layout.preferredWidth: editor.titleTableWidth
                Layout.maximumWidth: editor.titleTableWidth
                spacing: 0

                Label {
                    Layout.preferredWidth: editor.filterIdentityColumnWidth
                    Layout.minimumWidth: editor.filterIdentityColumnWidth
                    Layout.maximumWidth: editor.filterIdentityColumnWidth
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    text: ruleRow.modelData.field === "appId" ? ruleRow.modelData.value : "—"
                }

                Label {
                    Layout.preferredWidth: editor.filterIdentityColumnWidth
                    Layout.minimumWidth: editor.filterIdentityColumnWidth
                    Layout.maximumWidth: editor.filterIdentityColumnWidth
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    text: ruleRow.modelData.field === "appName" ? ruleRow.modelData.value : "—"
                }

                Item {
                    Layout.preferredWidth: editor.titleActionsColumnWidth
                    Layout.minimumWidth: editor.titleActionsColumnWidth
                    Layout.maximumWidth: editor.titleActionsColumnWidth
                    implicitHeight: filterActionsRow.implicitHeight

                    RowLayout {
                        id: filterActionsRow
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing

                        Button {
                            text: Wrappers.i18n("Edit")
                            icon.name: "document-edit"
                            onClicked: editor.openRule(ruleRow.index)
                        }

                        Button {
                            text: Wrappers.i18n("Remove")
                            icon.name: "list-remove"
                            onClicked: {
                                const next = editor.rules.slice();
                                next.splice(ruleRow.index, 1);
                                editor.commitRules(AppRules.serializeRules(next, editor.ruleKind));
                            }
                        }
                    }
                }
            }
        }

        Button {
            text: Wrappers.i18n("Add…")
            icon.name: "list-add"
            enabled: editor.parsed.valid
            onClicked: editor.openRule(-1)
        }
    }

    function addApplication(appId, appName) {
        const suggestion = AppRules.ruleForApplication(appId, appName);
        if (!suggestion)
            return;
        if (!parsed.valid)
            return;
        const index = rules.findIndex(rule => rule.field === suggestion.field && rule.value === suggestion.value
            && (ruleKind === "titles" || rule.match === suggestion.match));
        openRule(index, suggestion);
    }

    function commitRules(value) {
        edited(value);
    }

    function titleModeName(mode) {
        return mode === "iconOnly" ? Wrappers.i18n("Always icon only") : Wrappers.i18n("Always labeled");
    }

    function setTitleMode(index, mode) {
        if (!parsed.valid || index < 0 || index >= rules.length)
            return;
        const next = rules.slice();
        next[index] = Object.assign({}, next[index], {mode: mode});
        const encoded = AppRules.serializeRules(next, ruleKind);
        if (encoded !== null)
            edited(encoded);
    }

    function openRule(index, suggestion) {
        ruleDialog.editingIndex = index;
        const rule = index >= 0 ? editor.rules[index] : suggestion;
        fieldCombo.currentIndex = rule && rule.field === "appName" ? 1 : 0;
        titleModeCombo.currentIndex = rule && rule.mode === "labeled" ? 1 : 0;
        valueField.text = rule ? rule.value : "";
        ruleDialog.open();
        valueField.forceActiveFocus();
    }

    Dialog {
        id: ruleDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent ? parent.width - Kirigami.Units.gridUnit * 2 : implicitWidth, Kirigami.Units.gridUnit * 28)
        modal: true
        focus: true
        title: editingIndex < 0 ? Wrappers.i18n("Add rule to %1", editor.heading) : Wrappers.i18n("Edit rule in %1", editor.heading)

        property int editingIndex: -1
        readonly property var candidate: AppRules.normalizeRule({
            field: fieldCombo.currentIndex === 0 ? "appId" : "appName",
            match: "exact",
            mode: ["iconOnly", "labeled"][titleModeCombo.currentIndex],
            value: valueField.text
        }, editor.ruleKind)
        readonly property bool duplicate: candidate !== null && editor.rules.some((rule, index) => index !== editingIndex && rule.field === candidate.field && rule.match === candidate.match && rule.value === candidate.value)
        readonly property bool canSave: candidate !== null && !duplicate && editor.parsed.valid

        contentItem: ColumnLayout {
            Label {
                text: Wrappers.i18n("Match application by:")
            }
            ComboBox {
                id: fieldCombo
                Layout.fillWidth: true
                model: [Wrappers.i18n("App ID (recommended)"), Wrappers.i18n("App Name")]
            }
            ComboBox {
                id: titleModeCombo
                Layout.fillWidth: true
                visible: editor.ruleKind === "titles"
                model: [editor.titleModeName("iconOnly"), editor.titleModeName("labeled")]
            }
            Label {
                text: Wrappers.i18n("Value:")
            }
            TextField {
                id: valueField
                Layout.fillWidth: true
                placeholderText: fieldCombo.currentIndex === 0 ? Wrappers.i18n("For example: org.kde.dolphin") : Wrappers.i18n("For example: Dolphin")
                onAccepted: if (ruleDialog.canSave)
                    ruleDialog.accept()
            }
            Label {
                Layout.fillWidth: true
                visible: ruleDialog.duplicate
                wrapMode: Text.WordWrap
                text: Wrappers.i18n("This rule already exists.")
            }
        }

        footer: DialogButtonBox {
            Button {
                text: Wrappers.i18n("Save")
                enabled: ruleDialog.canSave
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
            Button {
                text: Wrappers.i18n("Cancel")
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            onAccepted: ruleDialog.accept()
            onRejected: ruleDialog.reject()
        }

        onAccepted: {
            if (!canSave)
                return;
            const next = editor.rules.slice();
            if (editingIndex < 0)
                next.push(candidate);
            else
                next[editingIndex] = candidate;
            const encoded = AppRules.serializeRules(next, editor.ruleKind);
            if (encoded !== null)
                editor.commitRules(encoded);
        }
    }
}
