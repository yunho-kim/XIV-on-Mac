#!/bin/bash

set -euo pipefail

configuration="${1:-Debug}"
build_architecture="${2:-$(uname -m)}"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.5}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"
native_root="$repository_root/XIV on Mac/XIVLauncher.NativeAOT"
source_project="$native_root/source/src/XIVLauncher.NativeAOT/XIVLauncher.NativeAOT.csproj"

case "$build_architecture" in
    arm64) runtime_id="osx-arm64" ;;
    x86_64) runtime_id="osx-x64" ;;
    *)
        echo "error: Unsupported build architecture: $build_architecture" >&2
        exit 1
        ;;
esac

case "$configuration" in
    Release) output_configuration="release" ;;
    *) output_configuration="debug" ;;
esac

# Xcode defines TARGETNAME, which the .NET SDK otherwise treats as an output name.
unset TARGETNAME

"$script_dir/dotnet.sh" publish "$source_project" \
    --runtime "$runtime_id" \
    --configuration "$output_configuration" \
    -p:TargetPlatformMinVersion="$MACOSX_DEPLOYMENT_TARGET" \
    --no-restore

publish_dir="$native_root/source/src/XIVLauncher.NativeAOT/bin/$output_configuration/net8.0/$runtime_id/publish"
cp "$publish_dir/XIVLauncher.NativeAOT.dylib" "$native_root/XIVLauncher.NativeAOT.dylib"
cp "$publish_dir/libsteam_api64.dylib" "$native_root/libsteam_api64.dylib"

install_name_tool -id @executable_path/../Frameworks/XIVLauncher.NativeAOT.dylib \
    "$native_root/XIVLauncher.NativeAOT.dylib"
# install_name_tool invalidates the existing signature; the app build signs it later.
install_name_tool -id @executable_path/../Frameworks/libsteam_api64.dylib \
    "$native_root/libsteam_api64.dylib" 2>/dev/null
