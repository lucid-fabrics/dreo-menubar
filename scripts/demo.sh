#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Regenerating Xcode project..."
xcodegen generate

echo "Building DreoBar (Debug)..."
if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild -project DreoBar.xcodeproj -scheme DreoBar -configuration Debug \
        -derivedDataPath .build build | xcbeautify
else
    xcodebuild -project DreoBar.xcodeproj -scheme DreoBar -configuration Debug \
        -derivedDataPath .build build | tail -20
fi

APP_PATH=".build/Build/Products/Debug/DreoBar.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Build did not produce $APP_PATH" >&2
    exit 1
fi

pkill -f "DreoBar.app" 2>/dev/null || true
open "$APP_PATH"
echo "Launched $APP_PATH"
