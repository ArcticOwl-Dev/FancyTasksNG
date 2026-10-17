#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -z "${FANCYTASKS_NATIVE_DIR:-}" ]]; then
    echo "Run with: nix develop --command bash tools/check_overlay.sh" >&2
    exit 1
fi
probe_dir=$(mktemp -d /tmp/fancytasks-overlay-check.XXXXXX)
trap 'rm -rf -- "$probe_dir"' EXIT
cp -R "$project_dir/package" "$probe_dir/package"
cp -R "$FANCYTASKS_NATIVE_DIR" "$probe_dir/package/contents/ui/native"
chmod -R u+w "$probe_dir/package/contents/ui/native"
python3 - "$probe_dir/package" <<'PY'
import json
import sys
from pathlib import Path
package = Path(sys.argv[1])
metadata = json.loads((package / 'metadata.json').read_text())
metadata['KPlugin']['Id'] = 'io.github.daydve.fancytasksng.overlaycheck'
metadata['KPlugin']['Name'] = 'FancyTasksNG overlay check'
(package / 'metadata.json').write_text(json.dumps(metadata))
main = (package / 'contents/ui/main.qml').read_text()
marker = 'PlasmoidItem {\n    id: tasks'
assert marker in main, 'Update overlay fixture for changed main.qml root'
main = main.replace(marker, '''Item {
    property var plasmoid: Plasmoid
    readonly property var probeOverlay: clippingOverlayLoader.item
    id: tasks''', 1).replace('    preferredRepresentation: fullRepresentation\n', '')
(package / 'contents/ui/ProbeTaskbar.qml').write_text(main)
overlay = package / 'contents/ui/ClippingOverlay.qml'
overlay.write_text(overlay.read_text().replace('    id: overlay',
    '    id: overlay\n    readonly property alias probeWindow: surface', 1))
PY
cp "$project_dir/tools/experiments/OverlayRowProbe.qml" "$probe_dir/package/contents/ui/main.qml"
export XDG_CONFIG_HOME="$probe_dir/config"
export XDG_CACHE_HOME="$probe_dir/cache"
export XDG_DATA_HOME="$probe_dir/data"
export QML_DISABLE_DISK_CACHE=true
export QT_FORCE_STDERR_LOGGING=1
export WAYLAND_DEBUG=1
status=0
timeout 12s plasmawindowed "$probe_dir/package" > "$probe_dir/check.log" 2>&1 || status=$?
if [[ "$status" != 0 && "$status" != 124 ]] || ! grep -q 'OVERLAY_CHECK_PASS' "$probe_dir/check.log" || grep -q 'OVERLAY_CHECK_FAIL' "$probe_dir/check.log"; then
    grep -E 'Error:|ReferenceError:|TypeError:|is not a type|Cannot assign' "$probe_dir/check.log" >&2 || true
    tail -n 80 "$probe_dir/check.log" >&2
    exit 1
fi
grep 'OVERLAY_CHECK_' "$probe_dir/check.log"
python3 "$project_dir/tools/check_overlay_trace.py" "$probe_dir/check.log"
