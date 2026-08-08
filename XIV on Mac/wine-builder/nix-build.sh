#!/bin/bash

set -euo pipefail

# Release builds use the Wine runtime shipped by the pinned, notarized XIV on
# Mac release. This keeps local Homebrew/MacPorts/Nix installations out of the
# produced app. Source builds remain available as an explicit maintainer opt-in.
if [[ "${XOM_BUILD_WINE_FROM_SOURCE:-0}" != "1" ]]; then
    echo "note: Using the pinned upstream XIV on Mac Wine runtime."
    exit 0
fi

NIX_BUILD_PATH=/nix/var/nix/profiles/default/bin/nix-build

if [[ ! -x "$NIX_BUILD_PATH" ]]; then
    echo "error: XOM_BUILD_WINE_FROM_SOURCE=1 requires Nix at $NIX_BUILD_PATH"
    exit 1
fi

"$NIX_BUILD_PATH" --max-jobs "$(sysctl -n hw.ncpu)" \
    --argstr darwinMinVersion "$MACOSX_DEPLOYMENT_TARGET"
