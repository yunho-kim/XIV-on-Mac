#!/bin/bash

set -euo pipefail

sdk_version="9.0.316"
script_dir="$(cd "$(dirname "$0")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"
dependencies_dir="${XOM_DEPS_DIR:-$repository_root/.deps}"

case "$(uname -m)" in
    arm64)
        runtime_id="osx-arm64"
        archive_url="https://builds.dotnet.microsoft.com/dotnet/Sdk/$sdk_version/dotnet-sdk-$sdk_version-osx-arm64.tar.gz"
        archive_sha512="bc4645bca4d263a1fd08848a1178c2c878a57b394c540b5e97dae3a443f5dec8893d09cc194b0d0adac7e9b9d7b18341a7651411999ce12ef9083ca9936c16f3"
        ;;
    x86_64)
        runtime_id="osx-x64"
        archive_url="https://builds.dotnet.microsoft.com/dotnet/Sdk/$sdk_version/dotnet-sdk-$sdk_version-osx-x64.tar.gz"
        archive_sha512="c46c685163856f5bb728c5d58e5788f354cb06e2094d893903292ed985d11586ff51e8b97c38169b9bb82301c32a43249546e23ce9ed4259d1802ba898933c72"
        ;;
    *)
        echo "error: Unsupported macOS architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

dotnet_dir="$dependencies_dir/dotnet-$sdk_version-$runtime_id"
if [[ -x "$dotnet_dir/dotnet" ]]; then
    echo "$dotnet_dir/dotnet"
    exit 0
fi

mkdir -p "$dependencies_dir"
temporary_dir="$(mktemp -d "$dependencies_dir/dotnet-download.XXXXXX")"
trap 'rm -rf -- "$temporary_dir"' EXIT
archive_path="$temporary_dir/dotnet-sdk.tar.gz"
install_path="$temporary_dir/install"

echo "Downloading .NET SDK $sdk_version for $runtime_id..." >&2
curl --fail --location --retry 3 --output "$archive_path" "$archive_url"
actual_sha512="$(shasum -a 512 "$archive_path" | awk '{print $1}')"
if [[ "$actual_sha512" != "$archive_sha512" ]]; then
    echo "error: .NET SDK checksum verification failed." >&2
    exit 2
fi

mkdir -p "$install_path"
tar -xzf "$archive_path" -C "$install_path"
if [[ ! -x "$install_path/dotnet" ]]; then
    echo "error: The .NET SDK archive did not contain the dotnet executable." >&2
    exit 3
fi

if [[ -e "$dotnet_dir" ]]; then
    mv "$dotnet_dir" "$dotnet_dir.invalid.$(date +%s)"
fi
mv "$install_path" "$dotnet_dir"
echo "$dotnet_dir/dotnet"
