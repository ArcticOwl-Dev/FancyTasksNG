#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 FancyTasksNG contributors
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

if ! command -v plasmawindowed &> /dev/null; then
    log_error "plasmawindowed is required from your installed Plasma desktop."
    exit 1
fi

PROJECT_DIR="$(readlink -f "${SCRIPT_DIR}/..")"
PREVIEW_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fancytasks-preview.XXXXXX")"
trap 'rm -rf -- "${PREVIEW_DIR}"' EXIT

# Include uncommitted changes, but keep translation/default generation and
# preview settings outside the working tree and the installed widget.
cp -R "${PROJECT_DIR}/package" "${PROJECT_DIR}/tools" "${PREVIEW_DIR}/"
if [[ -n "${FANCYTASKS_NATIVE_DIR:-}" ]]; then
    cp -R "${FANCYTASKS_NATIVE_DIR}" "${PREVIEW_DIR}/package/contents/ui/native"
    chmod -R u+w "${PREVIEW_DIR}/package/contents/ui/native"
fi
# Plasma's existing About dialog reads this staged metadata. Match the Nix
# package's base-version/commit format without modifying the source metadata.
if PREVIEW_REVISION=$(git -C "${PROJECT_DIR}" rev-parse --short HEAD 2>/dev/null); then
    if [[ -n "$(git -C "${PROJECT_DIR}" status --porcelain)" ]]; then
        PREVIEW_REVISION+="-dirty"
    fi
    PREVIEW_VERSION="$(get_metadata Version "${PREVIEW_DIR}/package/metadata.json")-${PREVIEW_REVISION}"
    set_metadata_version "${PREVIEW_DIR}/package/metadata.json" "${PREVIEW_VERSION}"
fi
export XDG_CONFIG_HOME="${PREVIEW_DIR}/config"
export XDG_CACHE_HOME="${PREVIEW_DIR}/cache"
export XDG_DATA_HOME="${PREVIEW_DIR}/data"
export FANCYTASKS_PREVIEW_SHARE="${PREVIEW_DIR}/locale-prefix/share"

log_info "Opening an isolated preview with your installed plasmawindowed."
bash "${PREVIEW_DIR}/tools/testing.sh"
