#!/bin/bash

set -euo pipefail

scriptDir="$(cd "$(dirname "$0")" && pwd)"
cd "$scriptDir"

nixResult="result"
sourceDir="$nixResult/nix/store"
targetDir="../wine"
overridesDir="overrides"
receipt="packaged-nix-output"
upstreamRuntimeID="XIV on Mac 5.4.2 / Wine 11.0"
upstreamArchiveURL="https://softwareupdate.xivmac.com/sites/default/files/update_data/XIV%20on%20Mac5.4.2.tar.xz"
upstreamArchiveSHA512="48a04b9dca4204b6c9345bd46d263be647be2e5df63dec86e7f810167365f83005a32f5bceed79859f28b12258ab7f03e657e40cd14651396d89188ca30211b9"
upstreamArchiveRuntimePath="XIV on Mac.app/Contents/Resources/wine"
upstreamArchiveDxmtPath="XIV on Mac.app/Contents/Resources/dxmt"
upstreamDxmtD3d11SHA256="617cf79d79d14b7d4041446aa3ec4658a257945d4bab127626eb5973f9da5b18"
upstreamDxmtDxgiSHA256="d26b51f7c662a9189377952a6ca6d427fdb108a4302c5877b1253aef0cfc8849"
upstreamReceipt="$targetDir/.xiv-on-mac-upstream-runtime"

ensure_wine_entrypoint() {
    local wineBin="$targetDir/bin"
    if [[ ! -e "$wineBin/wine" && -x "$wineBin/wine64" ]]; then
        ln -s wine64 "$wineBin/wine"
    fi
}

apply_runtime_overrides() {
    if [[ ! -d "$overridesDir" ]]; then
        echo "error: Wine runtime overrides are missing: $overridesDir"
        exit 3
    fi
    # Source-built and legacy fallback runtimes need the repository's native
    # graphics overrides. The pinned 5.4.2 runtime is handled separately below
    # so its verified DXMT pair is not replaced by older override files.
    rsync -a "$overridesDir/" "$targetDir/"
}

apply_supplemental_resources() {
    local supplementalDir="$overridesDir/share"
    if [[ ! -d "$supplementalDir" ]]; then
        echo "error: Supplemental Wine resources are missing: $supplementalDir"
        exit 3
    fi
    rsync -a "$supplementalDir/" "$targetDir/share/"
}

verify_upstream_dxmt() {
    local d3d11Path="$1/d3d11.dll"
    local dxgiPath="$1/dxgi.dll"
    [[ -f "$d3d11Path" ]] \
        && [[ "$(shasum -a 256 "$d3d11Path" | awk '{print $1}')" == "$upstreamDxmtD3d11SHA256" ]] \
        && [[ -f "$dxgiPath" ]] \
        && [[ "$(shasum -a 256 "$dxgiPath" | awk '{print $1}')" == "$upstreamDxmtDxgiSHA256" ]]
}

finalize_runtime() {
    apply_runtime_overrides
    ensure_wine_entrypoint
}

install_upstream_runtime() (
    archivePath="$(mktemp "${TMPDIR:-/tmp}/xom-upstream.XXXXXX.tar.xz")"
    stagingDir="$(mktemp -d "${TMPDIR:-/tmp}/xom-upstream.XXXXXX")"
    trap 'rm -f -- "$archivePath"; rm -rf -- "$stagingDir"' EXIT

    echo "note: Downloading the pinned XIV on Mac $upstreamRuntimeID runtime..."
    curl --fail --location --retry 3 --output "$archivePath" "$upstreamArchiveURL"
    actualSHA512="$(shasum -a 512 "$archivePath" | awk '{print $1}')"
    if [[ "$actualSHA512" != "$upstreamArchiveSHA512" ]]; then
        echo "error: Upstream XIV on Mac archive checksum verification failed."
        exit 2
    fi

    tar -xf "$archivePath" -C "$stagingDir" \
        "$upstreamArchiveRuntimePath" "$upstreamArchiveDxmtPath"
    downloadedRuntime="$stagingDir/$upstreamArchiveRuntimePath"
    downloadedDxmt="$stagingDir/$upstreamArchiveDxmtPath"
    if [[ ! -x "$downloadedRuntime/bin/wine" ]]; then
        echo "error: Upstream XIV on Mac archive did not contain its Wine runtime."
        exit 2
    fi
    if [[ "$("$downloadedRuntime/bin/wine" --version)" != "wine-11.0" ]]; then
        echo "error: Upstream XIV on Mac runtime has an unexpected Wine version."
        exit 2
    fi
    if ! verify_upstream_dxmt "$downloadedDxmt"; then
        echo "error: Upstream XIV on Mac archive has unexpected native DXMT files."
        exit 2
    fi

    rm -rf -- "$targetDir"
    mv "$downloadedRuntime" "$targetDir"
    # XIV on Mac 5.4.2 ships its native DXMT files outside the Wine directory
    # and copies them into system32 at runtime. Keep the same byte-for-byte
    # pairing while storing them with this fork's self-contained Wine bundle.
    cp "$downloadedDxmt/d3d11.dll" "$targetDir/lib/wine/x86_64-windows/d3d11.dll"
    cp "$downloadedDxmt/dxgi.dll" "$targetDir/lib/wine/x86_64-windows/dxgi.dll"
    printf '%s\n' "$upstreamRuntimeID" > "$upstreamReceipt"
    apply_supplemental_resources
    ensure_wine_entrypoint
)

ensure_upstream_runtime() {
    if [[ -f "$upstreamReceipt" ]] \
        && [[ "$(<"$upstreamReceipt")" == "$upstreamRuntimeID" ]] \
        && verify_upstream_dxmt "$targetDir/lib/wine/x86_64-windows"; then
        apply_supplemental_resources
        ensure_wine_entrypoint
        return
    fi
    install_upstream_runtime
}

if [[ "${XOM_BUILD_WINE_FROM_SOURCE:-0}" != "1" ]]; then
    ensure_upstream_runtime
    exit 0
fi

if [[ ! -d "$sourceDir" ]]; then
    echo "warning: Nix build did not succeed. No runtime to package."
    if [[ -d "$targetDir" ]]; then
        finalize_runtime
        exit 0
    fi
    echo "note: No preexisting wine package. Attempting verified archive download..."
    archivePath="$(mktemp "${TMPDIR:-/tmp}/xom-wine.XXXXXX.tar.gz")"
    trap 'rm -f -- "$archivePath"' EXIT
    archiveURL="https://github.com/marzent/winecx/releases/download/ff-wine-9.12.1/wine.tar.gz"
    archiveSHA512="41835ab42b526bd1fd6f4670fa9df4267213b83550b9438f17970558ee44a37e54dbab7cc1cf25ccf0fe54fea431d9044b7e557a9aab21206ad6bfea6fa910a0"
    curl --fail --location --retry 3 --output "$archivePath" "$archiveURL"
    actualSHA512="$(shasum -a 512 "$archivePath" | awk '{print $1}')"
    if [[ "$actualSHA512" != "$archiveSHA512" ]]; then
        echo "error: Wine runtime checksum verification failed."
        exit 2
    fi
    tar -xzf "$archivePath" -C "$(dirname "$targetDir")"
    finalize_runtime
    exit 0
fi

if [[ ! -L "$nixResult" ]]; then
  echo "error: Nix build failed."
  exit 1
fi

nixResultTarget="$(readlink "$nixResult")"

if [[ -e "$receipt" && -d "$targetDir" ]]; then
  current_content=$(<"$receipt")
  if [[ "$current_content" == "$nixResultTarget" ]]; then
    echo "note: The last built wine package matches the current one. No changes made."
    finalize_runtime
    exit 0
  fi
fi

echo "$nixResultTarget" > "$receipt"
echo "note: Updated receipt $receipt with Nix store result: $nixResultTarget"
echo "note: Packaging wine..."

subDir="$(find "$sourceDir" -type d -mindepth 1 -maxdepth 1 -print -quit)"
if [[ -z "$subDir" ]]; then
    echo "error: Nix build output did not contain a Wine runtime."
    exit 1
fi

rm -rf -- "$targetDir"
mkdir -p "$targetDir"
cp -R "$subDir/." "$targetDir/"
chmod -R u+w "$targetDir"
apply_runtime_overrides

libDir="$targetDir/lib"
mkdir -p "$libDir"
processedLibs=("libMoltenVK.dylib")

is_processed() {
    local libName=$1
    for processedLib in "${processedLibs[@]}"; do
        if [[ "$processedLib" == "$libName" ]]; then
            return 0
        fi
    done
    return 1
}

extract_rpaths() {
    local file=$1
    otool -l "$file" | awk '/cmd LC_RPATH/ { getline; getline; if($2 ~ /\/nix\/store/) print $2 }'
}

extract_dependencies() {
    local dylib=$1
    otool -l "$dylib" | awk '/cmd LC_LOAD_DYLIB/ { getline; getline; if($2 ~ /\/nix\/store/ && $2 ~ /\.dylib$/) print $2 }'
}

resolve_symlink_path() {
    local symlinkPath=$1
    local symlinkDir=$(dirname "$symlinkPath")
    local symlinkBaseName=$(basename "$(readlink "$symlinkPath")")
    echo "$(cd "$symlinkDir" && pwd -P)/$symlinkBaseName"
}

remove_nix_rpaths() {
    local file=$1
    local rpaths_to_remove=$(otool -l "$file" | awk '/cmd LC_RPATH/ { getline; getline; if($2 ~ /\/nix\/store/) print $2 }')

    for rpath in $rpaths_to_remove; do
        install_name_tool -delete_rpath "$rpath" "$file"
    done
}

process_dylib_dependecy() {
    local dylibPath=$1
    local dylibName=$(basename "$dylibPath")

    if is_processed "$dylibName"; then
        return 0
    fi
    processedLibs+=("$dylibName")

    if [[ -L "$dylibPath" ]]; then
        local targetName=$(readlink "$dylibPath")
        ln -s "$targetName" "$libDir/$dylibName"
        process_dylib_dependecy "$(resolve_symlink_path "$dylibPath")"
        return
    else
        cp "$dylibPath" "$libDir"
        chmod +w "$libDir/$dylibName"
        install_name_tool -id "@rpath/$dylibName" "$libDir/$dylibName"
    fi

    local dependencies=$(extract_dependencies "$libDir/$dylibName")
    for dep in $dependencies; do
        local depName=$(basename "$dep")
        install_name_tool -change "$dep" "@rpath/$depName" "$libDir/$dylibName"
        process_dylib_dependecy "$dep"
    done

    local dylibRpaths=$(extract_rpaths "$libDir/$dylibName")
    while read -r rpath; do
        if [[ -d "$rpath" ]]; then
            for dep in "$rpath"/*.dylib; do
                if [[ -f "$dep" ]]; then
                    local depName=$(basename "$dep")
                    install_name_tool -change "$dep" "@rpath/$depName" "$libDir/$dylibName"
                    process_dylib_dependecy "$dep"
                fi
            done
        fi
    done <<< "$dylibRpaths"
    
    remove_nix_rpaths "$libDir/$dylibName"
}

process_binary() {
    local binaryPath=$1
    local binaryName=$(basename "$binaryPath")

    install_name_tool -id "$binaryName" "$binaryPath"

    local dependencies=$(extract_dependencies "$binaryPath")
    for dep in $dependencies; do
        local depName=$(basename "$dep")
        install_name_tool -change "$dep" "@rpath/$depName" "$binaryPath"
        process_dylib_dependecy "$dep"
    done

    local binaryRpaths=$(extract_rpaths "$binaryPath")
    while read -r rpath; do
        if [[ -d "$rpath" ]]; then
            for dep in "$rpath"/*.dylib; do
                if [[ -f "$dep" ]]; then
                    local depName=$(basename "$dep")
                    install_name_tool -change "$dep" "@rpath/$depName" "$binaryPath"
                    process_dylib_dependecy "$dep"
                fi
            done
        fi
    done <<< "$binaryRpaths"
    
    remove_nix_rpaths "$binaryPath"

    install_name_tool -add_rpath "@executable_path/../lib" "$binaryPath"
    install_name_tool -add_rpath "@loader_path/../.." "$binaryPath"
}

find "$targetDir" -type f -print0 | while IFS= read -r -d '' file; do
    if [[ -d "$file" ]]; then
        continue
    fi
    if [[ "$file" == *".dylib" || "$file" == *".so" || -x "$file" ]]; then
        process_binary "$file"
    fi
done

ensure_wine_entrypoint
