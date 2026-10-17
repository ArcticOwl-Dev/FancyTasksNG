/*
    SPDX-FileCopyrightText: 2026 FancyTasksNG contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

// Version 1 documents contain {version: 1, rules: [...]}. Filter rules use
// {field: "appId" | "appName", match: "exact", value: string}; leading and
// trailing '*' characters provide optional prefix/suffix wildcards. Legacy
// "contains" rules are upgraded to '*value*' when read.
// Title overrides use {field, value, mode: "inherit" | "iconOnly" | "labeled"}
// and always match exactly. App-name rules are explicit, not title matches.
function normalizeIdentity(value, field) {
    if (typeof value !== "string" || (field !== "appId" && field !== "appName"))
        return "";

    const text = value.trim().toLowerCase();
    return field === "appId" ? text.replace(/\.desktop$/, "") : text;
}

function normalizeRule(rule, kind) {
    if (!rule || typeof rule !== "object" || Array.isArray(rule))
        return null;

    let value = normalizeIdentity(rule.value, rule.field);
    if (!value)
        return null;

    if (kind === "titles") {
        if (["inherit", "iconOnly", "labeled"].indexOf(rule.mode) === -1)
            return null;
        return {field: rule.field, value: value, mode: rule.mode};
    }

    if (kind !== "filter" || ["exact", "contains"].indexOf(rule.match) === -1)
        return null;
    if (rule.match === "contains")
        value = (value.startsWith("*") ? "" : "*") + value + (value.endsWith("*") ? "" : "*");
    return {field: rule.field, match: "exact", value: value};
}

// Inspector suggestions are still confirmed in the rule editor before saving.
function ruleForApplication(appId, appName) {
    const id = normalizeRule({field: "appId", match: "exact", value: appId}, "filter");
    return id || normalizeRule({field: "appName", match: "exact", value: appName}, "filter");
}

// Empty legacy/missing values are an empty document. Invalid or future versions
// are reported without throwing or rewriting the saved configuration.
function parseRules(serialized, kind) {
    kind = kind || "filter";
    if (kind !== "filter" && kind !== "titles")
        return {valid: false, rules: []};
    if (serialized === undefined || serialized === null || serialized === ""
            || (typeof serialized === "string" && serialized.trim() === ""))
        return {valid: true, rules: []};
    if (typeof serialized !== "string")
        return {valid: false, rules: []};

    try {
        const document = JSON.parse(serialized);
        if (!document || document.version !== 1 || !Array.isArray(document.rules))
            return {valid: false, rules: []};

        const rules = [];
        const keys = [];
        for (let i = 0; i < document.rules.length; ++i) {
            const rule = normalizeRule(document.rules[i], kind);
            if (!rule)
                return {valid: false, rules: []};
            // A title identity has one preference: the first entry wins.
            const key = JSON.stringify([rule.field, rule.match || "exact", rule.value]);
            if (keys.indexOf(key) === -1) {
                keys.push(key);
                rules.push(rule);
            }
        }
        return {valid: true, rules: rules};
    } catch (error) {
        return {valid: false, rules: []};
    }
}

// null signals an invalid edit. Callers must keep the previous staged value.
function serializeRules(rules, kind) {
    const parsed = parseRules(JSON.stringify({version: 1, rules: rules}), kind);
    return parsed.valid ? JSON.stringify({version: 1, rules: parsed.rules}) : null;
}

function migrateFilterRules(first, second, mode) {
    const firstParsed = parseRules(first, "filter");
    const secondParsed = parseRules(second, "filter");
    if (mode === 1)
        return firstParsed.valid ? serializeRules(firstParsed.rules, "filter") : null;
    if (mode === 2)
        return secondParsed.valid ? serializeRules(secondParsed.rules, "filter") : null;
    if (!firstParsed.valid || !secondParsed.valid)
        return null;
    return serializeRules(firstParsed.rules.concat(secondParsed.rules), "filter");
}

function matchesRule(appId, appName, rule) {
    const normalized = normalizeRule(rule, "filter");
    if (!normalized)
        return false;
    const identity = normalizeIdentity(normalized.field === "appId" ? appId : appName, normalized.field);
    const hasWildcard = normalized.value.startsWith("*") || normalized.value.endsWith("*");
    return identity !== "" && (hasWildcard ? matchesIdentityPattern(identity, normalized.value)
        : normalized.match === "exact" ? identity === normalized.value : identity.indexOf(normalized.value) !== -1);
}

function matchesAny(appId, appName, rules) {
    return Array.isArray(rules) && rules.some(rule => matchesRule(appId, appName, rule));
}

// A group is one application: use its own and its children's identity fields,
// and keep every child on the same decision. A child block always wins.
function acceptsApplication(mode, identities, allowRules, blockRules, pureLauncher, filterPinnedLaunchers) {
    if (mode !== 1 && mode !== 2)
        return true;
    if (pureLauncher && !filterPinnedLaunchers)
        return true;
    if (identities.some(identity => matchesAny(identity.appId, identity.appName, blockRules)))
        return false;
    return mode === 2 || identities.some(identity => matchesAny(identity.appId, identity.appName, allowRules));
}

function matchesIdentityPattern(identity, pattern) {
    // Only a leading or trailing '*' is a wildcard; all other characters,
    // including any interior '*', are treated literally.
    const startsWithWildcard = pattern.startsWith("*");
    const endsWithWildcard = pattern.endsWith("*");
    const literal = pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const source = (startsWithWildcard ? ".*" : "") +
        literal.slice(startsWithWildcard ? 2 : 0, endsWithWildcard ? -2 : undefined) +
        (endsWithWildcard ? ".*" : "");
    return new RegExp("^" + source + "$").test(identity);
}

// App ID overrides take priority over explicit App Name fallbacks,
// regardless of their order in the document. No match means inherit.
function titlePreference(appId, appName, rules) {
    if (!Array.isArray(rules))
        return "inherit";
    const fields = ["appId", "appName"];
    for (let f = 0; f < fields.length; ++f) {
        const field = fields[f];
        const identity = normalizeIdentity(field === "appId" ? appId : appName, field);
        if (!identity)
            continue;
        for (let i = 0; i < rules.length; ++i) {
            const rule = normalizeRule(rules[i], "titles");
            if (rule && rule.field === field && matchesIdentityPattern(identity, rule.value))
                return rule.mode;
        }
    }
    return "inherit";
}
