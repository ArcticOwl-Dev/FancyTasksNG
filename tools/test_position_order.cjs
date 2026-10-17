/* SPDX-License-Identifier: GPL-2.0-or-later */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');
const code = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../package/contents/ui/code/PositionOrder.js'), 'utf8').replace(/^\.pragma library\s*$/m, ''), code);
const window = (key, x, row = 0) => ({key, x, row, launcher: false});
const order = (state, entries) => Array.from(code.orderedKeys(state, entries));

test('equal x preserves arrivals despite foreground/source order, y or size changes', () => {
    const state = code.createState();
    assert.deepEqual(order(state, [window('a', 0), window('b', 0)]), ['a', 'b']);
    assert.deepEqual(order(state, [{...window('b', 0), active: true, y: -50, width: 800}, window('a', 0)]), ['a', 'b']);
});
test('a window moving to an occupied x comes after existing occupants', () => {
    const state = code.createState();
    order(state, [window('a', 0), window('b', 100)]);
    assert.deepEqual(order(state, [window('a', 100), window('b', 100)]), ['b', 'a']);
    assert.deepEqual(order(state, [window('a', -100), window('b', 100)]), ['a', 'b']);
    assert.deepEqual(order(state, [window('a', 100), window('b', 100)]), ['b', 'a']);
});
test('opening, closing and reopening use fresh arrivals and prune old records', () => {
    const state = code.createState();
    order(state, [window('a', 0), window('b', 0)]);
    assert.deepEqual(order(state, [window('b', 0)]), ['b']);
    assert.equal(state.positions.size, 1);
    assert.deepEqual(order(state, [window('a', 0), window('b', 0), window('c', 0)]), ['b', 'a', 'c']);
});
test('launchers retain configured order; unknown geometry follows real windows', () => {
    const state = code.createState();
    assert.deepEqual(order(state, [window('unknown', Infinity), window('b', -10),
        {...window('launcher2', 0, 1), launcher: true}, {...window('launcher1', 0, 0), launcher: true}]),
    ['launcher1', 'launcher2', 'b', 'unknown']);
});
test('each taskbar owns independent arrival state', () => {
    const first = code.createState();
    const second = code.createState();
    order(first, [window('a', 0), window('b', 0)]);
    assert.deepEqual(order(second, [window('b', 0), window('a', 0)]), ['b', 'a']);
});
