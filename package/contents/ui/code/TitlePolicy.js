/* SPDX-License-Identifier: GPL-2.0-or-later */
.pragma library
.import "AppRules.js" as AppRules

function key(appId, appName, iconKey) {
    const id = AppRules.normalizeIdentity(appId, "appId");
    const name = AppRules.normalizeIdentity(appName, "appName");
    const identity = name ? "name:" + name : id ? "id:" + id : "";
    return identity && iconKey ? JSON.stringify([identity, iconKey]) : identity;
}

function labeled(mode, count, override) {
    if (override === "iconOnly") return false;
    if (override === "labeled") return true;
    return mode === 2 || (mode === 1 && count >= 2);
}

function labelText(title, appName, titleOnly) {
    const original = String(title || appName || "");
    const name = String(appName || "").trim();
    if (!titleOnly || !name) return original;
    const text = original.replace(/\s+$/, "");
    if (!text.toLowerCase().endsWith(name.toLowerCase())) return original;
    const prefix = text.slice(0, text.length - name.length);
    // Only remove an identified app suffix, never an arbitrary title segment.
    const separator = /\s+[-\u2013\u2014|]\s+$/;
    if (!separator.test(prefix)) return original;
    return prefix.replace(separator, "").replace(/\s+$/, "") || original;
}

function build(windows, mode, iconsOnly, overrides) {
    const counts = Object.create(null);
    const groups = Object.create(null);
    // KDE groups by App ID/launcher. Split any such group that contains
    // different app-name/icon-name pairs, even before labels are needed.
    function groupKey(window) {
        const id = AppRules.normalizeIdentity(window.appId, "appId");
        return id ? "id:" + id : window.launcherUrl ? "launcher:" + window.launcherUrl : key(window.appId, window.appName);
    }
    for (const window of windows) {
        const identity = key(window.appId, window.appName, window.iconKey);
        if (identity) counts[identity] = (counts[identity] || 0) + 1;
        const group = groupKey(window);
        if (group && identity) {
            if (!groups[group]) groups[group] = new Set();
            groups[group].add(identity);
        }
    }
    const appIds = [], launcherUrls = [];
    for (const window of windows) {
        const override = AppRules.titlePreference(window.appId, window.appName, overrides);
        // Keep distinct icons as separate tasks even when neither has two
        // windows yet. KDE's grouping exclusions operate on the whole app.
        const separateIdentities = iconsOnly && mode === 1 && override === "inherit"
            && (groups[groupKey(window)]?.size || 0) > 1;
        if (!separateIdentities && ((!iconsOnly && override !== "labeled")
            || !labeled(mode, counts[key(window.appId, window.appName, window.iconKey)] || 0, override))) continue;
        if (window.appId && !appIds.includes(window.appId)) appIds.push(window.appId);
        else if (!window.appId && window.launcherUrl && !launcherUrls.includes(window.launcherUrl)) launcherUrls.push(window.launcherUrl);
    }
    return {counts: counts, appIds: appIds.sort(), launcherUrls: launcherUrls.sort()};
}
