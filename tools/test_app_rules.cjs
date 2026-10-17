/*
 * SPDX-FileCopyrightText: 2026 FancyTasksNG contributors
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Run with: node tools/test_app_rules.cjs
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');

// Evaluate the same dependency-free file that QML imports, removing only its
// QML library directive. No duplicate implementation or npm packages needed.
const source = fs.readFileSync(path.join(__dirname, '../package/contents/ui/code/AppRules.js'), 'utf8');
const rules = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*$/m, ''), rules);
const document = entries => JSON.stringify({version: 1, rules: entries});
const idRule = (value, match = 'exact') => ({field: 'appId', match, value});
const nameRule = (value, match = 'exact') => ({field: 'appName', match, value});

test('inspector suggestions prefer App ID, fall back to App Name, and reject missing identities', () => {
    assert.equal(JSON.stringify(rules.ruleForApplication(' Code.desktop ', 'Editor')), JSON.stringify(idRule('code')));
    assert.equal(JSON.stringify(rules.ruleForApplication('', ' Dolphin ')), JSON.stringify(nameRule('dolphin')));
    assert.equal(JSON.stringify(rules.ruleForApplication('.desktop', 'Editor')), JSON.stringify(nameRule('editor')));
    assert.equal(rules.ruleForApplication('', '  '), null);
});

test('filter modes, block precedence and empty allowlists', () => {
    const identity = [{appId: ' Firefox.DESKTOP ', appName: 'Browser'}];
    const accepts = (mode, allow, block) => rules.acceptsApplication(mode, identity, allow, block, false, false);
    assert.equal(accepts(0, [], [idRule('firefox')]), true);
    assert.equal(accepts(1, [idRule('firefox')], []), true);
    assert.equal(accepts(1, [idRule('firefox')], [idRule('firefox')]), false);
    assert.equal(accepts(1, [], []), false);
    assert.equal(accepts(2, [], []), true);
    assert.equal(accepts(2, [], [idRule('dolphin')]), true);
    assert.equal(accepts(2, [], [idRule('firefox')]), false);
    assert.equal(accepts(99, [], [idRule('firefox')]), true);
});

test('switching filter mode reinterprets the same rules as allowed or blocked', () => {
    const sharedRules = [idRule('firefox')];
    const identities = [{appId: 'firefox.desktop', appName: 'Firefox'}];
    assert.equal(rules.acceptsApplication(1, identities, sharedRules, [], false, false), true);
    assert.equal(rules.acceptsApplication(2, identities, [], sharedRules, false, false), false);
    const other = [{appId: 'dolphin', appName: 'Dolphin'}];
    assert.equal(rules.acceptsApplication(1, other, sharedRules, [], false, false), false);
    assert.equal(rules.acceptsApplication(2, other, [], sharedRules, false, false), true);
});

test('app-name substring rules and missing identities use the same filter policy', () => {
    assert.equal(rules.acceptsApplication(1, [{appId: '', appName: 'Visual Studio Code'}],
        [nameRule('STUDIO', 'contains')], [], false, false), true);
    assert.equal(rules.acceptsApplication(2, [{appId: '', appName: 'Dolphin'}],
        [], [nameRule('PHIN', 'contains')], false, false), false);
    for (const identities of [[], [{appId: '', appName: ''}]]) {
        assert.equal(rules.acceptsApplication(1, identities, [idRule('firefox')], [], false, false), false);
        assert.equal(rules.acceptsApplication(2, identities, [], [idRule('firefox')], false, false), true);
    }
});

test('only pure pinned launchers can bypass application rules', () => {
    const identities = [{appId: 'dolphin', appName: 'Dolphin'}];
    assert.equal(rules.acceptsApplication(1, identities, [], [idRule('dolphin')], true, false), true);
    assert.equal(rules.acceptsApplication(1, identities, [], [idRule('dolphin')], true, true), false);
    assert.equal(rules.acceptsApplication(2, identities, [], [idRule('dolphin')], false, false), false);
});

test('group children supply missing parent identity; a block on any member hides the application', () => {
    const identities = [{appId: '', appName: ''}, {appId: 'code.desktop', appName: 'Code'}, {appId: 'code', appName: 'Editor'}];
    assert.equal(rules.acceptsApplication(1, identities, [idRule('CODE')], [], false, false), true);
    assert.equal(rules.acceptsApplication(1, identities, [idRule('code')], [nameRule('editor')], false, false), false);
    assert.equal(rules.acceptsApplication(2, identities, [], [idRule('code')], false, false), false);
});

test('malformed stored rules follow empty-list semantics without rewriting them', () => {
    const saved = '{';
    const parsed = rules.parseRules(saved);
    const identities = [{appId: 'firefox', appName: 'Firefox'}];
    assert.equal(rules.acceptsApplication(1, identities, parsed.rules, [], false, false), false);
    assert.equal(rules.acceptsApplication(2, identities, [], parsed.rules, false, false), true);
    assert.equal(parsed.valid, false);
    assert.equal(saved, '{');
});

test('identity normalization trims, ignores case and strips only an ID suffix', () => {
    assert.equal(rules.normalizeIdentity('  Org.KDE.Dolphin.DESKTOP ', 'appId'), 'org.kde.dolphin');
    assert.equal(rules.normalizeIdentity('name.desktop.extra', 'appId'), 'name.desktop.extra');
    assert.equal(rules.normalizeIdentity(' Editor.desktop ', 'appName'), 'editor.desktop');
    assert.equal(rules.normalizeIdentity(null, 'appId'), '');
    assert.equal(rules.normalizeIdentity('firefox', 'windowTitle'), '');
});

test('exact and legacy contains matching use explicit identity fields, never window titles', () => {
    assert.equal(rules.matchesRule('Firefox.desktop', 'Browser', idRule(' FIREFOX ')), true);
    assert.equal(rules.matchesRule('firefox-nightly', 'Browser', idRule('firefox')), false);
    assert.equal(rules.matchesRule('firefox-nightly', 'Browser', idRule('FIREFOX', 'contains')), true);
    assert.equal(rules.matchesRule('editor', 'Visual Studio Code', nameRule('studio', 'contains')), true);
    assert.equal(rules.matchesRule('firefox', 'Browser', nameRule('firefox')), false);
    for (const invalid of [idRule(' '), idRule('.desktop'), idRule('.*', 'regex'), null])
        assert.equal(rules.matchesRule('firefox', 'Firefox', invalid), false);
    assert.equal(rules.matchesRule('', '', idRule('firefox', 'contains')), false);
    assert.equal(rules.matchesAny('firefox', 'Browser', [idRule('dolphin'), idRule('firefox')]), true);
    assert.equal(rules.matchesAny('firefox', 'Browser', []), false);
});

test('filter rules treat leading and trailing * as wildcards', () => {
    assert.equal(rules.matchesRule('org.kde.dolphin.desktop', '', idRule('org.kde.*')), true);
    assert.equal(rules.matchesRule('org.kde.dolphin', '', idRule('*dolphin')), true);
    assert.equal(rules.matchesRule('', 'Visual Studio Code', nameRule('*studio code')), true);
    assert.equal(rules.matchesRule('', 'Dolphin', nameRule('Dolphin*')), true);
    assert.equal(rules.matchesRule('orgXkdeXdolphin', '', idRule('org.kde.*')), false);
    assert.equal(rules.matchesRule('org.kde.dolphin', '', idRule('org* dolphin')), false);
    assert.equal(rules.matchesRule('firefox', '', idRule('*')), true);
});

test('empty legacy values parse safely; invalid JSON, versions and rules are rejected', () => {
    for (const value of ['', '  ', undefined, null]) {
        assert.equal(rules.parseRules(value).valid, true);
        assert.equal(rules.parseRules(value).rules.length, 0);
    }
    for (const value of ['{', 'null', '[]', '{}', '"text"', 1,
        '{"version":2,"rules":[]}', '{"version":1,"rules":{}}',
        document([idRule('valid'), idRule('')]), document([{field: 'windowTitle', match: 'exact', value: 'title'}]),
        document([{field: 'appId', match: 'exact', value: {}}])]) {
        assert.equal(rules.parseRules(value).valid, false);
        assert.equal(rules.parseRules(value).rules.length, 0);
    }
    assert.equal(rules.parseRules('', 'unknown').valid, false);
});

test('round trips normalize identities and upgrade legacy contains rules to wildcards', () => {
    const encoded = rules.serializeRules([idRule(' FIREFOX.desktop '), idRule('firefox'),
        idRule('firefox', 'contains'), nameRule('Firefox')]);
    assert.deepEqual(JSON.parse(encoded), {version: 1, rules: [idRule('firefox'),
        idRule('*firefox*'), nameRule('firefox')]});
    const legacy = rules.parseRules(document([nameRule('STUDIO', 'contains')]));
    assert.deepEqual(JSON.parse(rules.serializeRules(legacy.rules)), {version: 1, rules: [nameRule('*studio*')]});
    assert.equal(rules.matchesRule('', 'Visual Studio Code', legacy.rules[0]), true);
    assert.equal(rules.serializeRules([idRule('')]), null);
    assert.equal(rules.serializeRules({}), null);
});

test('legacy filter rules migrate from the active mode into the shared list', () => {
    const allowlist = document([idRule('Firefox'), nameRule('Dolphin')]);
    const blocklist = document([idRule('firefox'), nameRule('Kate')]);
    const migratedAllowlist = rules.migrateFilterRules(allowlist, blocklist, 1);
    const migratedBlocklist = rules.migrateFilterRules(allowlist, blocklist, 2);
    const migratedOff = rules.migrateFilterRules(allowlist, blocklist, 0);
    assert.deepEqual(JSON.parse(migratedAllowlist), {version: 1, rules: [idRule('firefox'), nameRule('dolphin')]});
    assert.deepEqual(JSON.parse(migratedBlocklist), {version: 1, rules: [idRule('firefox'), nameRule('kate')]});
    assert.deepEqual(JSON.parse(migratedOff), {version: 1, rules: [
        idRule('firefox'), nameRule('dolphin'), nameRule('kate')
    ]});
    assert.equal(rules.migrateFilterRules('{', document([]), 1), null);
    assert.equal(rules.migrateFilterRules(document([]), '{', 2), null);
});

test('title preferences prioritize IDs over names, support inherit and reject unsafe modes', () => {
    const entries = [
        {field: 'appName', value: 'Editor', mode: 'labeled'},
        {field: 'appId', value: 'org.editor.desktop', mode: 'iconOnly'}
    ];
    const parsed = rules.parseRules(document(entries), 'titles');
    assert.equal(parsed.valid, true);
    assert.equal(rules.titlePreference('ORG.EDITOR', 'Editor', parsed.rules), 'iconOnly');
    assert.equal(rules.titlePreference('', 'EDITOR', parsed.rules), 'labeled');
    assert.equal(rules.titlePreference('unrelated', 'Other', parsed.rules), 'inherit');
    entries[1].mode = 'inherit';
    assert.equal(rules.titlePreference('org.editor', 'Editor', entries), 'inherit');
    entries[1].mode = 'execute';
    assert.equal(rules.parseRules(document(entries), 'titles').valid, false);
    assert.equal(rules.serializeRules([entries[0]], 'titles'), document([
        {field: 'appName', value: 'editor', mode: 'labeled'}]));
});

test('title override patterns allow wildcard * only at the start or end', () => {
    const entries = [
        {field: 'appId', value: 'org.kde.dolphin+', mode: 'labeled'},
        {field: 'appId', value: 'org.kde.*', mode: 'iconOnly'},
        {field: 'appName', value: '*studio code', mode: 'labeled'}
    ];
    assert.equal(rules.titlePreference('org.kde.dolphin', 'Dolphin', entries), 'iconOnly');
    assert.equal(rules.titlePreference('org.kde.kate.desktop', '', entries), 'iconOnly');
    assert.equal(rules.titlePreference('', 'Visual Studio Code', entries), 'labeled');
    assert.equal(rules.titlePreference('org.kde.dolphin+', '', entries), 'labeled');
    assert.equal(rules.titlePreference('orgXkdeXdolphin', '', entries), 'inherit');
    assert.equal(rules.titlePreference('', 'visual extra studio code', [
        {field: 'appName', value: 'visual*code', mode: 'labeled'}
    ]), 'inherit');
});

test('strings that look like JavaScript remain literal data', () => {
    const text = 'globalThis.executed = true';
    assert.equal(rules.parseRules(text).valid, false);
    const parsed = rules.parseRules(document([nameRule(text)]));
    assert.equal(parsed.valid, true);
    assert.equal(rules.matchesAny('other', text, parsed.rules), true);
    assert.equal(rules.executed, undefined);
});
