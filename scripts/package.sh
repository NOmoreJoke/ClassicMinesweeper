#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
dist_dir="$project_dir/dist"
app_path="$dist_dir/Classic Mines.app"
dmg_path="$dist_dir/Classic-Mines-1.0.0-arm64.dmg"
icon_work="$(mktemp -d)"
stage_dir="$(mktemp -d)"
trap 'rm -rf "$icon_work" "$stage_dir"' EXIT

cd "$project_dir"
swift test -c release
binary_dir="$(swift build -c release --show-bin-path)"

rm -rf "$app_path"
rm -f "$dmg_path" "$dmg_path.sha256"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$icon_work/AppIcon.iconset"
cp "$binary_dir/ClassicMines" "$app_path/Contents/MacOS/ClassicMines"
cp "$project_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
chmod 755 "$app_path/Contents/MacOS/ClassicMines"

swift "$project_dir/scripts/generate_icon.swift" "$icon_work/AppIcon-1024.png"
for spec in '16 icon_16x16.png' '32 icon_16x16@2x.png' '32 icon_32x32.png' '64 icon_32x32@2x.png' '128 icon_128x128.png' '256 icon_128x128@2x.png' '256 icon_256x256.png' '512 icon_256x256@2x.png' '512 icon_512x512.png' '1024 icon_512x512@2x.png'; do
    pixels="${spec%% *}"
    name="${spec#* }"
    sips -z "$pixels" "$pixels" "$icon_work/AppIcon-1024.png" --out "$icon_work/AppIcon.iconset/$name" >/dev/null
done
iconutil -c icns "$icon_work/AppIcon.iconset" -o "$app_path/Contents/Resources/AppIcon.icns"

plutil -lint "$app_path/Contents/Info.plist"
codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict "$app_path"

ditto "$app_path" "$stage_dir/Classic Mines.app"
ln -s /Applications "$stage_dir/Applications"
hdiutil create -volname "Classic Mines" -srcfolder "$stage_dir" -ov -format UDZO "$dmg_path" >/dev/null
(cd "$dist_dir" && shasum -a 256 "${dmg_path:t}" > "${dmg_path:t}.sha256")

print -- "$app_path"
print -- "$dmg_path"
print -- "$dmg_path.sha256"
