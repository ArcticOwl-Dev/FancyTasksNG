// SPDX-License-Identifier: GPL-2.0-or-later
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {execFileSync} = require('node:child_process');
const {test} = require('node:test');

const runtime = vm.createContext({});
vm.runInContext(fs.readFileSync('package/contents/ui/code/PythonRuntime.js', 'utf8')
    .replace(/^\.pragma library\s*$/m, ''), runtime);

test('helper paths survive URL decoding and shell quoting', () => {
    const path = "/tmp/a space/ü 'quoted' $(exit 9); helper.py";
    const command = runtime.helperCommand('file://' + encodeURI(path));
    // Substitute a shell function for Python and inspect its actual argument.
    const result = execFileSync('sh', ['-c', 'python3() { printf "%s" "$1"; }; ' + command],
        {encoding: 'utf8'});
    assert.equal(result, path);
});
