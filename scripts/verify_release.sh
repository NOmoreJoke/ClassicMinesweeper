#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
dist_dir="$project_dir/dist"
app_path="$dist_dir/Classic Mines.app"
dmg_path="$dist_dir/Classic-Mines-1.0.0-arm64.dmg"
installed_path="/Applications/Classic Mines.app"
installed_executable="$installed_path/Contents/MacOS/ClassicMines"
probe_dir="$(mktemp -d)"
probe_dylib="$probe_dir/network_probe.dylib"
probe_self_test="$probe_dir/network_probe_self_test"
probe_launcher="$probe_dir/network_probe_launcher"
probe_log="$probe_dir/network_calls.log"
mount_point=""
sandbox_pid=""
app_pid=""
cleanup() {
    [[ -n "$app_pid" ]] && kill "$app_pid" 2>/dev/null || true
    [[ -n "$sandbox_pid" ]] && kill "$sandbox_pid" 2>/dev/null || true
    [[ -n "$mount_point" ]] && hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    rm -rf "$probe_dir"
}
trap cleanup EXIT

cd "$dist_dir"
shasum -a 256 -c "${dmg_path:t}.sha256"
codesign --verify --deep --strict "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
test "$(defaults read "$app_path/Contents/Info.plist" CFBundleIdentifier)" = "com.local.classicmines"
file "$app_path/Contents/MacOS/ClassicMines" | grep -q 'arm64'

mount_output="$(hdiutil attach "$dmg_path" -readonly -nobrowse)"
mount_point="${mount_output##*$'\t'}"
test -d "$mount_point/Classic Mines.app"
test -L "$mount_point/Applications"
codesign --verify --deep --strict "$mount_point/Classic Mines.app"
for candidate_pid in $(pgrep -x ClassicMines || true); do
    candidate_command="$(ps -p "$candidate_pid" -o command= || true)"
    [[ "$candidate_command" == "$installed_executable"* ]] && kill "$candidate_pid"
done
rm -rf "$installed_path"
ditto "$mount_point/Classic Mines.app" "$installed_path"
hdiutil detach "$mount_point" >/dev/null
mount_point=""
codesign --verify --deep --strict "$installed_path"
diff -qr "$app_path" "$installed_path" >/dev/null
[[ -z "$(xattr -p com.apple.quarantine "$installed_path" 2>/dev/null || true)" ]]

if rg -n '\b(URLSession|NSURLSession|NWConnection|CFNetwork|CFSocket|socket|getaddrinfo|gethostbyname|connect|sendto)\b' "$project_dir/Sources"; then
    print -u2 -- "network API reference found in source"
    exit 1
fi
if nm -u "$installed_executable" | rg '\b(_socket|_getaddrinfo|_gethostbyname|_connect|_sendto)$'; then
    print -u2 -- "network symbol found in executable"
    exit 1
fi

clang -dynamiclib -O2 "$project_dir/scripts/network_probe.c" -o "$probe_dylib"
: > "$probe_log"
clang -O2 "$project_dir/scripts/network_probe_self_test.c" -o "$probe_self_test"
clang -O2 "$project_dir/scripts/network_probe_launcher.c" -o "$probe_launcher"
env CLASSIC_MINES_NETWORK_PROBE_LOG="$probe_log" \
    DYLD_INSERT_LIBRARIES="$probe_dylib" \
    "$probe_self_test"
grep -qx socket "$probe_log"
: > "$probe_log"
sandbox-exec -p '(version 1)(allow default)(deny network*)' \
    "$probe_launcher" "$installed_executable" "$probe_dylib" "$probe_log" &
sandbox_pid=$!
app_pid="$sandbox_pid"
for _ in {1..50}; do
    process_command="$(ps -p "$app_pid" -o command= 2>/dev/null || true)"
    [[ "$process_command" == "$installed_executable"* ]] && break
    sleep 0.1
done
kill -0 "$app_pid"
process_command="$(ps -p "$app_pid" -o command=)"
[[ "$process_command" == "$installed_executable"* ]]
probe_loaded=false
for _ in {1..50}; do
    if vmmap "$app_pid" 2>/dev/null | grep -F "$probe_dylib" >/dev/null; then
        probe_loaded=true
        break
    fi
    sleep 0.1
done
[[ "$probe_loaded" == true ]]

network_output=""
for _ in {1..60}; do
    sample="$(lsof -nP -a -p "$app_pid" -iTCP -iUDP || true)"
    [[ -n "$sample" ]] && network_output+="$sample"
    sleep 0.05
done
[[ -z "$network_output" ]]
[[ ! -s "$probe_log" ]]
launched_pid="$app_pid"
kill "$app_pid"
wait "$sandbox_pid" 2>/dev/null || true
app_pid=""
sandbox_pid=""

print -- "installed=$installed_path"
print -- "launched_pid=$launched_pid"
print -- "installed_matches_dist=true"
print -- "network_api_refs=0"
print -- "network_calls=0"
