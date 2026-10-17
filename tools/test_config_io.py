#!/usr/bin/env python3
"""Exercise the real export/import service on a private D-Bus session."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

import dbus


def main():
    helper = Path(sys.argv[1]).resolve()
    bus = dbus.SessionBus()
    name = "io.github.daydve.fancytasksng.DesktopActions"
    with tempfile.TemporaryDirectory(prefix="fancytasks-config-") as temporary:
        directory = Path(temporary)
        # Python must come from its absolute runtime path, not the desktop PATH.
        environment = dict(os.environ, PATH=str(directory), PYTHONPATH="")
        with subprocess.Popen([sys.executable, str(helper)], env=environment) as process:
            try:
                deadline = time.monotonic() + 10
                while not bus.name_has_owner(name):
                    if process.poll() is not None:
                        raise RuntimeError("Desktop actions helper exited before registering")
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Desktop actions helper did not register")
                    time.sleep(0.05)
                service = dbus.Interface(bus.get_object(name, "/DesktopActions"),
                                         "io.github.daydve.fancytasksng.Config")
                path = directory / "settings with spaces, 'quotes' and ü.json"
                content = '{"app":"io.github.daydve.fancytasksng","version":1,"settings":{"titleOnly":true}}'
                assert service.ExportConfig(str(path), content) == "OK"
                assert path.read_text(encoding="utf-8") == content
                assert service.ImportConfig(str(path)) == content
                assert str(service.ExportConfig(str(directory / "missing" / "config.json"), content)).startswith("ERROR:")
                assert str(service.ImportConfig(str(directory / "missing.json"))).startswith("ERROR:")
                print("Configuration export/import round trip and file errors pass with no Python on PATH")
            finally:
                process.terminate()
                process.wait(timeout=5)


if __name__ == "__main__":
    main()
