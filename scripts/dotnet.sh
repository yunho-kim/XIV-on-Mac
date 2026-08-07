#!/bin/bash

set -euo pipefail

required_sdk="9.0.316"
script_dir="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"
dependencies_dir="${XOM_DEPS_DIR:-$repository_root/.deps}"

case "$(uname -m)" in
    arm64) runtime_id="osx-arm64" ;;
    x86_64) runtime_id="osx-x64" ;;
    *)
        echo "error: Unsupported macOS architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

local_dotnet="$dependencies_dir/dotnet-$required_sdk-$runtime_id/dotnet"
if [[ -x "$local_dotnet" ]]; then
    exec "$local_dotnet" "$@"
fi

if command -v dotnet >/dev/null 2>&1 \
    && dotnet --list-sdks | grep -q "^$required_sdk "; then
    exec dotnet "$@"
fi

local_dotnet="$("$script_dir/bootstrap-dotnet.sh")"
exec "$local_dotnet" "$@"
