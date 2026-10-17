/* SPDX-License-Identifier: GPL-2.0-or-later */
import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// A fixed-size row within a disposable host. No real panel settings or window
// actions are changed. The actual production task/model code is copied intact
// into ProbeTaskbar.qml, apart from its outer Plasma representation wrapper.
PlasmoidItem {
    id: host
    property var firstDelegate: null
    property bool failed: false
    function check(condition, message) {
        if (!condition) {
            failed = true;
            console.error("OVERLAY_CHECK_FAIL", message);
            throw new Error(message);
        }
    }
    preferredRepresentation: fullRepresentation
    fullRepresentation: Rectangle {
        color: "#343434"
        ProbeTaskbar {
            id: bar
            x: 100
            y: parent.height - 100
            width: Math.max(300, Math.min(900, parent.width - 200))
            height: 48
        }
        Timer {
            interval: 400; running: true
            onTriggered: {
                const cfg = Plasmoid.configuration;
                cfg.overridePlasmaButtonDirection = true;
                cfg.plasmaButtonDirection = 1;
                cfg.iconOnly = 1;
                cfg.titleDisplayMode = 0;
                cfg.showOnlyCurrentActivity = false;
                cfg.showOnlyCurrentDesktop = false;
                cfg.unhideOnAttention = false;
                cfg.experimentalFloatingOverlay = true;
            }
        }
        Timer {
            interval: 1800; running: true
            onTriggered: {
                host.check(bar.overlayActive && bar.probeOverlay.probeWindow.visible, "overlay mapped");
                host.check(bar.probeOverlay.probeWindow.transientParent === null, "overlay does not block panel dodge as a transient popup");
                host.check(Plasmoid.status === PlasmaCore.Types.PassiveStatus, "idle overlay does not hold panel open");
                host.firstDelegate = bar.taskList.children.find(child => child.model && child.width > 0);
                host.check(host.firstDelegate, "at least one task is available");
                bar.instantHoveredTask = host.firstDelegate;
                bar.instantHoveredFraction = 0.5;
            }
        }
        Timer {
            interval: 2600; running: true
            onTriggered: {
                const icon = host.firstDelegate.taskIcon;
                const top = icon.mapToGlobal(0, 0);
                const bottom = icon.mapToGlobal(icon.width, icon.height);
                host.check(top.y < bar.mapToGlobal(0, 0).y, "icon extends above panel bounds");
                const window = bar.probeOverlay.probeWindow;
                const origin = window.contentItem.mapToGlobal(0, 0);
                host.check(top.y >= origin.y && bottom.y <= origin.y + window.height, "icon fits overlay");
                host.check(!bar.probeOverlay.ownsKeyboardFocus(), "overlay does not take keyboard focus");
                host.check(Plasmoid.status === PlasmaCore.Types.NeedsAttentionStatus, "hover holds panel open");
                console.log("OVERLAY_CHECK_GEOMETRY_PASS");
                bar.instantHoveredTask = null;
                Plasmoid.configuration.experimentalFloatingOverlay = false;
            }
        }
        Timer {
            interval: 3200; running: true
            onTriggered: {
                host.check(!bar.overlayActive, "standard rendering restored");
                host.check(bar.taskList.children.includes(host.firstDelegate), "delegate retained on disable");
                Plasmoid.configuration.experimentalFloatingOverlay = true;
            }
        }
        Timer {
            interval: 3800; running: true
            onTriggered: {
                host.check(bar.overlayActive, "overlay enabled again");
                host.check(Plasmoid.status === PlasmaCore.Types.PassiveStatus, "panel hold released after hover");
                host.check(bar.taskList.children.includes(host.firstDelegate), "delegate retained on enable");
                console.log("OVERLAY_CHECK_TOGGLE_PASS");
                const cfg = Plasmoid.configuration;
                cfg.applicationFilterMode = 1;
                cfg.applicationAllowlist = '{"version":1,"rules":[]}';
                cfg.filterPinnedLaunchers = true;
            }
        }
        Timer {
            interval: 4500; running: true
            onTriggered: {
                host.check(bar.effectiveTasksModel.count === 0, "empty allowlist hides tasks");
                host.check(!bar.probeOverlay.probeWindow.visible, "empty surface hidden");
                console.log("OVERLAY_CHECK_FILTER_PASS");
                Plasmoid.configuration.applicationFilterMode = 0;
                Plasmoid.configuration.titleDisplayMode = 2;
            }
        }
        Timer {
            interval: 5300; running: true
            onTriggered: {
                host.check(bar.probeOverlay.probeWindow.visible, "surface restored");
                host.check(bar.taskList.children.some(child => child.model && child.conditionalLabel), "labels available");
                console.log("OVERLAY_CHECK_LABELS_PASS");
                host.visible = false;
            }
        }
        Timer {
            interval: 6000; running: true
            onTriggered: {
                host.check(!bar.probeOverlay.probeWindow.visible, "hidden anchor also hides detached overlay");
                console.log("OVERLAY_CHECK_HIDDEN_ANCHOR_PASS");
                host.visible = true;
            }
        }
        Timer {
            interval: 6500; running: true
            onTriggered: {
                host.check(bar.probeOverlay.probeWindow.visible, "overlay restored with anchor");
                host.Window.window.showMinimized();
            }
        }
        Timer {
            interval: 7000; running: true
            onTriggered: {
                host.check(!bar.probeOverlay.probeWindow.visible, "minimized host hides overlay");
                host.Window.window.showNormal();
                host.Window.window.requestActivate();
            }
        }
        Timer {
            interval: 7600; running: true
            onTriggered: {
                host.check(bar.probeOverlay.probeWindow.visible,
                    "overlay restored after host remapping");
                console.log("OVERLAY_CHECK_HOST_REMAP_PASS");
                Plasmoid.configuration.enableToolTips = true;
                host.firstDelegate = bar.taskList.children.find(child => child.model && child.width > 0);
                host.check(host.firstDelegate, "a restored task is available for tooltip checks");
                bar.instantHoveredTask = null;
                bar.isTooltipHovered = false;
                bar.currentHoveredTask = host.firstDelegate;
            }
        }
        Timer {
            interval: 7800; running: true
            onTriggered: {
                host.check(Plasmoid.status === PlasmaCore.Types.NeedsAttentionStatus,
                    "tooltip crossing gap holds panel open before popup hover");
                bar.isTooltipHovered = true;
            }
        }
        Timer {
            interval: 8500; running: true
            onTriggered: {
                host.check(bar.currentHoveredTask === host.firstDelegate,
                    "entering tooltip cancels its close grace period");
                host.check(Plasmoid.status === PlasmaCore.Types.NeedsAttentionStatus,
                    "tooltip interaction keeps panel open");
                bar.isTooltipHovered = false;
            }
        }
        Timer {
            interval: 9200; running: true
            onTriggered: {
                host.check(bar.currentHoveredTask === null, "tooltip closes after leaving");
                host.check(Plasmoid.status === PlasmaCore.Types.PassiveStatus,
                    "tooltip departure releases panel hold");
                console.log("OVERLAY_CHECK_TOOLTIP_CROSSING_PASS");
                if (!host.failed) console.log("OVERLAY_CHECK_PASS");
            }
        }
    }
}
