#!/bin/bash
# Render the real Windbar UI with fixture devices, then frame it for the App Store.
#
# The harness runs inside the sandboxed host app, so it can only write to its own
# temp directory. This copies the results out and hands them to the compositor.
set -eo pipefail
cd "$(dirname "$0")/.."

RAW="$PWD/design/screenshots/raw"
mkdir -p "$RAW"

echo "==> rendering UI with fixture devices"
LOG=$(mktemp)
TEST_RUNNER_WINDBAR_SHOT_DIR=1 xcodebuild test \
  -project Windbar.xcodeproj -scheme Windbar -destination 'platform=macOS' \
  -only-testing:WindbarTests/ScreenshotHarness \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" > "$LOG" 2>&1 || { tail -30 "$LOG"; exit 1; }

grep -o '/[^ ]*windbar-screenshots/[0-9]*\.png' "$LOG" | sort -u | while read -r f; do
  [ -f "$f" ] && cp "$f" "$RAW/$(basename "$f")" && echo "    $(basename "$f")"
done
rm -f "$LOG"

COUNT=$(ls "$RAW"/*.png 2>/dev/null | wc -l | tr -d ' ')
[ "$COUNT" = "0" ] && { echo "No screenshots rendered."; exit 1; }
echo "==> $COUNT raw capture(s) in design/screenshots/raw"

echo "==> compositing store frames"
python3 design/make_screenshots.py
