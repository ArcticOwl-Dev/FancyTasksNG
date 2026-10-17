#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
probe_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v plasmawindowed >/dev/null
command -v python3 >/dev/null
probe_dir=$(mktemp -d /tmp/fancytasks-overlay.XXXXXX)
trap 'rm -rf -- "$probe_dir"' EXIT
cp -R "$probe_root/package" "$probe_dir/package"
cp "$probe_root/tools/experiments/OverlayProbeHost.qml" "$probe_dir/package/contents/ui/main.qml"
python3 - "$probe_dir/package/metadata.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
metadata = json.loads(path.read_text())
metadata['KPlugin']['Id'] = 'io.github.daydve.fancytasksng.overlayprobe'
metadata['KPlugin']['Name'] = 'FancyTasksNG overlay diagnostic'
path.write_text(json.dumps(metadata))
PY
export XDG_CONFIG_HOME="$probe_dir/config"
export XDG_DATA_HOME="$probe_dir/data"
export XDG_CACHE_HOME="$probe_dir/cache"
export QML_DISABLE_DISK_CACHE=true
plasmawindowed "$probe_dir/package"
