/* SPDX-License-Identifier: GPL-2.0-or-later */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');
const code = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../package/contents/ui/code/TaskIndexes.js'), 'utf8').replace(/^\.pragma library\s*$/m, ''), code);

function models(visibleRows) {
    const items = ['hidden-first', 'visible-a', 'hidden-middle', 'visible-b'];
    const source = {
        count: items.length,
        index(row) { return {row, valid: row >= 0 && row < items.length, owner: source}; },
        move(from, to) { items.splice(to, 0, items.splice(from, 1)[0]); return true; }
    };
    const displayed = {
        count: visibleRows.length,
        index(row) { return {row, valid: row >= 0 && row < visibleRows.length, owner: displayed}; },
        mapToSource(index) { return source.index(index.valid ? visibleRows[index.row] : -1); }
    };
    return {source, displayed, items};
}

test('actions map displayed rows through the active proxy, including hidden leading rows', () => {
    const {source, displayed, items} = models([1, 3]);
    assert.equal(items[code.sourceIndex(source, displayed, 0).row], 'visible-a');
    assert.equal(items[code.sourceIndex(source, displayed, 1).row], 'visible-b');
    assert.equal(code.sourceIndex(source, displayed, 0).owner, source);
});
test('source display bypasses an existing but unused filtering proxy', () => {
    const {source, items} = models([1, 3]);
    assert.equal(items[code.sourceIndex(source, source, 0).row], 'hidden-first');
    assert.equal(code.sourceIndex(source, source, 2).row, 2);
});
test('keyboard and DnD moves map both ends and preserve unrelated hidden items', () => {
    const {source, displayed, items} = models([1, 3]);
    assert.equal(code.move(source, displayed, 1, 0), true);
    assert.deepEqual(items, ['hidden-first', 'visible-b', 'visible-a', 'hidden-middle']);
});
test('empty, stale and out-of-range delegate rows cannot request moves', () => {
    for (const visible of [[], [1, 3]]) {
        const {source, displayed, items} = models(visible);
        const before = items.slice();
        assert.equal(code.sourceIndex(source, displayed, -1).valid, false);
        assert.equal(code.sourceIndex(source, displayed, displayed.count).valid, false);
        assert.equal(code.move(source, displayed, 0, displayed.count), false);
        assert.equal(code.move(source, displayed, -1, 0), false);
        assert.deepEqual(items, before);
    }
});
