/* SPDX-License-Identifier: GPL-2.0-or-later */
.pragma library

function createState() {
    return {next: 0, positions: new Map()};
}

// Only a changed x coordinate starts a new arrival. Focus, y, size and source
// row changes must not affect equal-position ordering. State is per taskbar.
function orderedKeys(state, entries) {
    const positions = new Map();
    for (const entry of entries) {
        const previous = state.positions.get(entry.key);
        positions.set(entry.key, previous && previous.x === entry.x
            ? previous : {x: entry.x, arrival: state.next++});
    }
    state.positions = positions;
    return entries.slice().sort((a, b) => {
        // Keep pinned launchers in their existing configured order.
        if (a.launcher || b.launcher)
            return a.launcher === b.launcher ? a.row - b.row : a.launcher ? -1 : 1;
        const left = positions.get(a.key);
        const right = positions.get(b.key);
        return left.x - right.x || left.arrival - right.arrival;
    }).map(entry => entry.key);
}
