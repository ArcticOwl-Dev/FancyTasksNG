/* SPDX-License-Identifier: GPL-2.0-or-later */
.pragma library

// Nix packages replace this with the interpreter containing our dependencies.
const executable = "python3";

function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function helperCommand(scriptUrl) {
    const path = decodeURIComponent(String(scriptUrl).replace(/^file:\/\//, ""));
    return shellQuote(executable) + " " + shellQuote(path);
}
