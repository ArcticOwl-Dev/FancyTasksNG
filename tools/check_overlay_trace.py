#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Check the disposable overlay probe's client-side Wayland trace."""
import re
import sys
from pathlib import Path

surfaces = {}
regions = {}
subsurface_parents = {}
plasma_surfaces = {}
notification_surfaces = set()
restricted_surfaces = 0
positions = 0
for line in Path(sys.argv[1]).read_text().splitlines():
    match = re.search(r"get_surface\(new id org_kde_plasma_surface#(\d+), wl_surface#(\d+)\)", line)
    if match:
        plasma_surfaces[match[1]] = match[2]
    match = re.search(r"org_kde_plasma_surface#(\d+)\.set_role\(4\)", line)
    if match:
        notification_surfaces.add(plasma_surfaces[match[1]])
    match = re.search(r"get_subsurface\(new id wl_subsurface#\d+, wl_surface#(\d+), wl_surface#(\d+)\)", line)
    if match:
        subsurface_parents[match[1]] = match[2]
    match = re.search(r"create_region\(new id wl_region#(\d+)\)", line)
    if match:
        regions[match[1]] = []
    match = re.search(r"wl_region#(\d+)\.add\((-?\d+), (-?\d+), (\d+), (\d+)\)", line)
    if match:
        regions.setdefault(match[1], []).append(tuple(map(int, match.groups()[1:])))
    match = re.search(r"wl_surface#(\d+)\.(\w+)\((.*)\)", line)
    if match:
        surface_id, operation, args = match.groups()
        state = surfaces.setdefault(surface_id, {"buffer": False, "restricted": False, "seen": False})
        if operation == "set_input_region":
            state['restricted'] = args != 'nil'
            if state['restricted']:
                if not state['seen']:
                    restricted_surfaces += 1
                state['seen'] = True
                for x, y, width, height in regions.get(args.removeprefix('wl_region#'), []):
                    assert not (x <= 0 < x + width and y <= 0 < y + height), 'Transparent corner accepts input'
        elif operation == "attach":
            state['buffer'] = not args.startswith('nil')
        elif operation == "commit":
            assert not (state['seen'] and state['buffer'] and not state['restricted']), 'Mapped overlay committed full-window input'
            if state['seen'] and state['buffer']:
                assert surface_id not in subsurface_parents, 'Overlay inherits panel clipping as a subsurface'
                assert surface_id in notification_surfaces, 'Overlay has no upper stacking role'
        elif operation == "destroy":
            del surfaces[surface_id]
            subsurface_parents.pop(surface_id, None)
            notification_surfaces.discard(surface_id)
    match = re.search(r"wl_keyboard#\d+\.enter\(\d+, wl_surface#(\d+)", line)
    if match:
        assert not surfaces.get(match[1], {}).get('seen'), 'Overlay received keyboard focus'
    match = re.search(r"(?:org_kde_plasma_surface|wl_subsurface)#\d+\.set_position\((-?\d+), (-?\d+)\)", line)
    if match:
        positions += 1
        assert all(abs(int(value)) < 100000 for value in match.groups()), 'Runaway overlay position'

assert restricted_surfaces >= 2, 'Missing mapped overlay input-region trace'
assert positions < 64, 'Repeated overlay repositioning in a stationary fixture'
print('OVERLAY_CHECK_WAYLAND_PASS')
