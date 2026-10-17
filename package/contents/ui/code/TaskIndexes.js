/* SPDX-License-Identifier: GPL-2.0-or-later */
.pragma library

// Delegate rows belong to the model actually displayed, which may be the source
// or its filtering proxy. Requests and moves always belong to TasksModel.
function sourceIndex(source, displayed, row) {
    if (!displayed || row < 0 || row >= displayed.count)
        return source.index(-1, 0);
    const index = displayed.index(row, 0);
    return displayed === source ? index : displayed.mapToSource(index);
}

function move(source, displayed, fromRow, toRow) {
    const from = sourceIndex(source, displayed, fromRow);
    const to = sourceIndex(source, displayed, toRow);
    return from.valid && to.valid && from.row !== to.row
        ? source.move(from.row, to.row) : false;
}
