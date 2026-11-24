#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

ARCH="${1:-universal}"

APP_NAME="Walkman Studio"
APP_BUNDLE="$DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "Packaging $APP_BUNDLE (Architecture: $ARCH)..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Ask SwiftPM for the output directory for each target architecture.
build_binary() {
    local triple="$1-apple-macosx"
    local destination="$2"
    local bin_dir
    swift build -c release --triple "$triple"
    bin_dir="$(swift build -c release --triple "$triple" --show-bin-path)"
    cp "$bin_dir/WalkmanStudio" "$destination"
}

if [ "$ARCH" = "universal" ]; then
    mkdir -p "$DIR/.build/bin"
    build_binary arm64 "$DIR/.build/bin/WalkmanStudio-arm64"
    build_binary x86_64 "$DIR/.build/bin/WalkmanStudio-x86_64"
    lipo -create -output "$MACOS_DIR/WalkmanStudio" "$DIR/.build/bin/WalkmanStudio-arm64" "$DIR/.build/bin/WalkmanStudio-x86_64"
elif [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "intel" ]; then
    build_binary x86_64 "$MACOS_DIR/WalkmanStudio"
else
    build_binary arm64 "$MACOS_DIR/WalkmanStudio"
fi
chmod +x "$MACOS_DIR/WalkmanStudio"

# Bundle interface translations for packaged launches (including releases).
cp -R "$DIR/Sources/WalkmanStudio/Resources/Localization" "$RESOURCES_DIR/Localization"

# Copy App Icon & Device Assets
if [ -f "$DIR/assets/AppIcon.icns" ]; then
    cp "$DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -d "$DIR/assets/devices" ]; then
    mkdir -p "$RESOURCES_DIR/devices"
    cp -R "$DIR/assets/devices/"* "$RESOURCES_DIR/devices/"
    cp "$DIR/assets/devices/"*.png "$RESOURCES_DIR/" 2>/dev/null || true
fi
if [ -f "$DIR/assets/walkman_device_cropped.png" ]; then
    cp "$DIR/assets/walkman_device_cropped.png" "$RESOURCES_DIR/walkman_device_cropped.png"
fi
if [ -f "$DIR/assets/walkman_device.png" ]; then
    cp "$DIR/assets/walkman_device.png" "$RESOURCES_DIR/walkman_device.png"
fi
if [ -f "$DIR/assets/hires_audio_logo.png" ]; then
    cp "$DIR/assets/hires_audio_logo.png" "$RESOURCES_DIR/hires_audio_logo.png"
fi
if [ -f "$DIR/assets/hires_audio_logo.svg" ]; then
    cp "$DIR/assets/hires_audio_logo.svg" "$RESOURCES_DIR/hires_audio_logo.svg"
fi
if [ -f "$DIR/assets/walkman_logo_emblem.png" ]; then
    cp "$DIR/assets/walkman_logo_emblem.png" "$RESOURCES_DIR/walkman_logo_emblem.png"
fi

# Copy SensMe Channel Cover Artworks
if [ -d "$DIR/assets/SensMe Channel cover" ]; then
    echo "Bundling SensMe Channel covers into $RESOURCES_DIR/senseme..."
    mkdir -p "$RESOURCES_DIR/senseme"
    mkdir -p "$RESOURCES_DIR/SensMe Channel cover"
    cp -R "$DIR/assets/SensMe Channel cover/"* "$RESOURCES_DIR/senseme/" 2>/dev/null || true
    cp -R "$DIR/assets/SensMe Channel cover/"* "$RESOURCES_DIR/SensMe Channel cover/" 2>/dev/null || true
    cp "$DIR/assets/SensMe Channel cover/"*.jpg "$RESOURCES_DIR/" 2>/dev/null || true
fi

cp "$DIR/Configuration/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Ad-hoc sign app bundle for local execution
echo "Signing $APP_BUNDLE..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Successfully built $APP_BUNDLE"
