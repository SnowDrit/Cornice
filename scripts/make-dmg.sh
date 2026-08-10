#!/bin/bash
#
# Builds the disk image people actually download.
#
# A zip drops a bare .app wherever the browser put it, usually Downloads, and it runs
# from there until the day someone tidies up. A disk image opens as a window with the
# app on one side and a shortcut to Applications on the other, so where it goes is
# obvious without reading anything.
#
# Usage: scripts/make-dmg.sh <path to Cornice.app> <output.dmg>

set -euo pipefail

APP="${1:?usage: make-dmg.sh <Cornice.app> <output.dmg>}"
OUTPUT="${2:?usage: make-dmg.sh <Cornice.app> <output.dmg>}"

VOLUME_NAME="Cornice"
STAGING="$(mktemp -d)"
TEMP_DMG="$(mktemp -u).dmg"

cleanup() {
    rm -rf "$STAGING"
    rm -f "$TEMP_DMG"
}
trap cleanup EXIT

echo "Staging $APP"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Sized so both icons sit comfortably with room between them. Read-write for now,
# because the Finder layout below has to be written into the image before it is sealed.
echo "Creating image"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW \
    "$TEMP_DMG" >/dev/null

MOUNT_POINT="/Volumes/$VOLUME_NAME"
hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen >/dev/null
sleep 2

# Icon placement is best effort. It needs Finder, which is not always available or
# willing on a build runner, and a plain image with both icons in it still works
# perfectly well. So a failure here is worth a note and nothing more.
echo "Arranging the window"
osascript <<APPLESCRIPT 2>/dev/null || echo "  (Finder unavailable, using the default layout)"
tell application "Finder"
    tell disk "$VOLUME_NAME"
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
APPLESCRIPT

sync
hdiutil detach "$MOUNT_POINT" >/dev/null || hdiutil detach "$MOUNT_POINT" -force >/dev/null
sleep 1

echo "Compressing"
rm -f "$OUTPUT"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT" >/dev/null

echo "Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
