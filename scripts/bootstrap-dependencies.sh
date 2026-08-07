#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"

case "$(uname -m)" in
    arm64) runtime_id="osx-arm64" ;;
    x86_64) runtime_id="osx-x64" ;;
    *)
        echo "error: Unsupported macOS architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

"$script_dir/bootstrap-dotnet.sh" >/dev/null
"$repository_root/XIV on Mac/wine-builder/package-runtime.sh"
"$script_dir/dotnet.sh" restore \
    "$repository_root/XIV on Mac/XIVLauncher.NativeAOT/source/src/XIVLauncher.NativeAOT/XIVLauncher.NativeAOT.csproj" \
    --runtime "$runtime_id"

echo "Dependencies are ready."
