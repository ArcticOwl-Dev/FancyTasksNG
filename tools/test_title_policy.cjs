/* SPDX-License-Identifier: GPL-2.0-or-later */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');
const read = name => fs.readFileSync(path.join(__dirname, '../package/contents/ui/code', name + '.js'), 'utf8').replace(/^\.(pragma|import).*$/mg, '');
const rules = vm.createContext({});
vm.runInContext(read('AppRules'), rules);
const titles = vm.createContext({AppRules: rules});
vm.runInContext(read('TitlePolicy'), titles);
const window = (appId = 'code', appName = appId) => ({appId, appName, launcherUrl: 'applications:' + appId + '.desktop'});
const plain = value => JSON.parse(JSON.stringify(value));

test('title-only labels strip a known program suffix with common separators', () => {
    for (const separator of [' - ', ' – ', ' — ', ' | ']) {
        assert.equal(titles.labelText('Document' + separator + 'Editor', 'Editor', true), 'Document');
    }
    assert.equal(titles.labelText('Document - Project - Visual Studio Code', 'Visual Studio Code', true), 'Document - Project');
    assert.equal(titles.labelText('Document — EDITOR  ', 'Editor', true), 'Document');
    assert.equal(titles.labelText('Document — Editor (Dev)', 'Editor (Dev)', true), 'Document');
});

test('title-only labels preserve unrecognized titles, empty results and the default presentation', () => {
    for (const title of ['Editor', 'MyEditor', 'Document - Other App', 'Editor — Document', ' - Editor']) {
        assert.equal(titles.labelText(title, 'Editor', true), title);
    }
    assert.equal(titles.labelText('Document — Editor', 'Editor', false), 'Document — Editor');
    assert.equal(titles.labelText('Document — Editor', '', true), 'Document — Editor');
    assert.equal(titles.labelText('', 'Editor', true), 'Editor');
    assert.equal(titles.labelText(null, null, true), '');
});

test('automatic counts individual windows, separates at two, and restores at one', () => {
    for (const count of [1, 2, 3, 1]) {
        const result = titles.build(Array.from({length: count}, () => window()), 1, true);
        assert.equal(result.counts['name:code'], count);
        assert.deepEqual(Array.from(result.appIds), count >= 2 ? ['code'] : []);
    }
});
test('Off leaves grouping unchanged; Always labels a single window; Classic keeps normal grouping', () => {
    assert.deepEqual(plain(titles.build([window(), window()], 0, true).appIds), []);
    assert.deepEqual(plain(titles.build([window()], 2, true).appIds), ['code']);
    assert.deepEqual(plain(titles.build([window(), window()], 1, false).appIds), []);
});
test('identities normalize for counts but generated exclusions retain the actual KDE values', () => {
    const result = titles.build([window('Code.desktop', 'Code'), window('CODE', 'CODE'), window('firefox')], 1, true);
    assert.equal(result.counts['name:code'], 2);
    assert.deepEqual(Array.from(result.appIds), ['CODE', 'Code.desktop']);
    assert.equal(result.counts['name:firefox'], 1);
});
test('missing IDs use explicit names and launcher URLs, never merge anonymous windows', () => {
    const result = titles.build([window('', 'Editor'), window('', 'editor'), window('', '')], 1, true);
    assert.equal(result.counts['name:editor'], 2);
    assert.equal(result.counts[''], undefined);
    assert.equal(result.launcherUrls.length, 1);
});

test('explicit icon-only preserves grouping and labeled overrides split even one window', () => {
    const overrides = [{field: 'appId', value: 'code', mode: 'iconOnly'}, {field: 'appName', value: 'Browser', mode: 'labeled'}];
    const result = titles.build([window(), window(), window('firefox', 'Browser')], 1, true, overrides);
    assert.deepEqual(Array.from(result.appIds), ['firefox']);
    assert.equal(titles.labeled(2, 3, 'iconOnly'), false);
    assert.equal(titles.labeled(0, 1, 'labeled'), true);
});
test('App ID override wins over name, inherit uses mode, invalid overrides are ignored', () => {
    const overrides = [{field: 'appName', value: 'code', mode: 'labeled'}, {field: 'appId', value: 'code', mode: 'iconOnly'}];
    assert.deepEqual(Array.from(titles.build([window()], 2, true, overrides).appIds), []);
    assert.equal(titles.labeled(1, 2, 'inherit'), true);
    assert.deepEqual(Array.from(titles.build([window()], 0, true, [{field: 'appId', value: 'code', mode: 'invalid'}]).appIds), []);
});
test('Classic grouping changes only for an explicit labeled override', () => {
    assert.deepEqual(Array.from(titles.build([window()], 0, false, [{field: 'appId', value: 'code', mode: 'labeled'}]).appIds), ['code']);
    assert.deepEqual(Array.from(titles.build([window(), window()], 2, false, [{field: 'appId', value: 'code', mode: 'iconOnly'}]).appIds), []);
});

test('automatic counts the same app and icon together, keeping distinct icons separate', () => {
    const red = {...window('browser'), iconKey: 'red'};
    const blue = {...window('browser'), iconKey: 'blue'};
    for (const windows of [[red, blue], [red, red, blue], [red, blue]]) {
        const result = titles.build(windows, 1, true);
        const redCount = windows.filter(item => item.iconKey === 'red').length;
        assert.equal(result.counts[titles.key('browser', 'Browser', 'red')], redCount);
        assert.equal(result.counts[titles.key('browser', 'Browser', 'blue')], 1);
        assert.equal(titles.labeled(1, redCount, 'inherit'), redCount === 2);
        assert.equal(titles.labeled(1, result.counts[titles.key('browser', 'Browser', 'blue')], 'inherit'), false);
        assert.deepEqual(Array.from(result.appIds), ['browser']);
    }
});

test('matching icons never merge different apps and overrides still take priority', () => {
    const a = {...window('browser'), iconKey: 'same'};
    const b = {...window('editor'), iconKey: 'same'};
    const result = titles.build([a, b], 1, true);
    assert.equal(result.counts[titles.key('browser', 'browser', 'same')], 1);
    assert.equal(result.counts[titles.key('editor', 'editor', 'same')], 1);
    assert.deepEqual(Array.from(result.appIds), []);
    const different = {...a, iconKey: 'different'};
    assert.deepEqual(Array.from(titles.build([a, different], 0, true).appIds), []);
    assert.deepEqual(Array.from(titles.build([a, different], 1, false).appIds), []);
    assert.deepEqual(Array.from(titles.build([a, different], 1, true,
        [{field: 'appId', value: 'browser', mode: 'iconOnly'}]).appIds), []);
    assert.deepEqual(Array.from(titles.build([a], 0, true,
        [{field: 'appId', value: 'browser', mode: 'labeled'}]).appIds), ['browser']);
});

test('app name and icon name determine counts independently of App ID', () => {
    const a = {...window('browser-work', 'Browser'), iconKey: 'work'};
    const b = {...window('browser-other-id', ' browser '), iconKey: 'work'};
    const c = {...window('browser-work', 'Browser'), iconKey: 'personal'};
    const result = titles.build([a, b, c], 1, true);
    assert.equal(titles.key(a.appId, a.appName, a.iconKey), titles.key(b.appId, b.appName, b.iconKey));
    assert.equal(result.counts[titles.key(a.appId, a.appName, a.iconKey)], 2);
    assert.equal(result.counts[titles.key(c.appId, c.appName, c.iconKey)], 1);
    assert.deepEqual(Array.from(result.appIds), ['browser-other-id', 'browser-work']);
    assert.equal(titles.key('Code.desktop', '', 'code'), titles.key('CODE', '', 'code'));
});

test('different app names sharing an App ID remain separate and unnamed icons use the app name', () => {
    const a = {...window('browser', 'Work'), iconKey: 'browser'};
    const b = {...window('browser', 'Personal'), iconKey: 'browser'};
    const result = titles.build([a, b], 1, true);
    assert.equal(result.counts[titles.key(a.appId, a.appName, a.iconKey)], 1);
    assert.equal(result.counts[titles.key(b.appId, b.appName, b.iconKey)], 1);
    assert.deepEqual(Array.from(result.appIds), ['browser']);
    assert.equal(titles.build([window('a', 'Browser'), window('b', 'Browser')], 1, true).counts['name:browser'], 2);
});
