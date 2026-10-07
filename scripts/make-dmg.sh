#!/bin/bash
# Usage: scripts/make-dmg.sh [--no-layout] <Cornice.app> <output.dmg>
# --no-layout never mounts an image or invokes Finder/AppleScript.

set -euo pipefail

LAYOUT=1
if [ "${1:-}" = "--no-layout" ]; then
    LAYOUT=0
    shift
fi
if [ "$#" -ne 2 ]; then
    echo "usage: make-dmg.sh [--no-layout] <Cornice.app> <output.dmg>" >&2
    exit 2
fi
APP="$1"
OUTPUT="$2"
test -d "$APP"
test "$(basename "$APP")" = "Cornice.app"

VOLUME_NAME="Cornice"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/Cornice-dmg.XXXXXX")"
STAGING="$WORK_DIR/staging"
TEMP_DMG="$WORK_DIR/temporary.dmg"
MOUNT_POINT="$WORK_DIR/mount"
ATTACH_ATTEMPTED=0
mkdir "$STAGING" "$MOUNT_POINT"

# Only this invocation can own this unique mountpoint. Never detach by volume name.
detach_image() {
    python3 - "$MOUNT_POINT" <<'PYTHON'
import subprocess
import sys

for extra in ([], ["-force"]):
    try:
        result = subprocess.run(["/usr/bin/hdiutil", "detach", sys.argv[1], *extra],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                timeout=15)
        if result.returncode == 0:
            sys.exit(0)
    except subprocess.TimeoutExpired:
        pass
sys.exit(1)
PYTHON
}

cleanup() {
    local result=$?
    trap - EXIT
    if [ "$ATTACH_ATTEMPTED" -eq 1 ] && ! detach_image; then
        # A failed attach can still leave a mounted device. Preserve the whole
        # workspace rather than recursively deleting through a possible mount.
        echo "Could not confirm detach; temporary files retained at $WORK_DIR" >&2
        exit 1
    fi
    rm -rf "$WORK_DIR"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Staging $APP"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "Creating image"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" \
    -format UDRW "$TEMP_DMG" >/dev/null

if [ "$LAYOUT" -eq 1 ]; then
    ATTACH_ATTEMPTED=1
    hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen -nobrowse \
        -mountpoint "$MOUNT_POINT" >/dev/null
    sleep 2

    # Optional CI presentation only. Resolve the exact mounted folder, so an
    # unrelated volume named Cornice is never selected by Finder.
    echo "Arranging the window"
    osascript - "$MOUNT_POINT" <<'APPLESCRIPT' 2>/dev/null || echo "  (Finder unavailable, using the default layout)"
on run arguments
    set imagePath to POSIX file (item 1 of arguments) as alias
    tell application "Finder"
        tell folder imagePath
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 150, 800, 540}
            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 128
            set position of item "Cornice.app" of container window to {150, 190}
            set position of item "Applications" of container window to {450, 190}
            close
            open
            update without registering applications
            delay 2
        end tell
    end tell
end run
APPLESCRIPT
    sync
    detach_image
    ATTACH_ATTEMPTED=0
fi

echo "Compressing"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 \
    -ov -o "$OUTPUT" >/dev/null
echo "Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
