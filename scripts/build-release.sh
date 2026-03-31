#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$PROJECT_ROOT/CueLink"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="CueLink"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"

echo "==> Building release binary..."
cd "$PKG_DIR"
swift build -c release

# Locate the built binary
BINARY="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

echo "==> Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "$PKG_DIR/CueLink/Info.plist" "$APP_BUNDLE/Contents/"

# Add NSPrincipalClass to Info.plist for proper app behavior
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.dylanlambert.CueLink" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${APP_NAME}" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleName string ${APP_NAME}" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

# Copy SPM resource bundle — must be at .app root for Bundle.main to find it
RESOURCE_BUNDLE="$(swift build -c release --show-bin-path)/CueLink_CueLink.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/"
    echo "  Copied resource bundle"
fi

# Compile asset catalog if present
XCASSETS="$PKG_DIR/CueLink/Assets.xcassets"
if [ -d "$XCASSETS" ]; then
    echo "==> Compiling asset catalog..."
    xcrun actool "$XCASSETS" \
        --compile "$APP_BUNDLE/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$BUILD_DIR/AssetCatalog-Info.plist" \
        2>/dev/null || echo "  Warning: actool failed, skipping asset catalog"
fi

# Generate icns from AppIcon if we have an iconset or source PNG
ICON_SOURCE="$PKG_DIR/CueLink/Resources/appicon_1024.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "==> Generating app icon (icns)..."
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null 2>&1
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null 2>&1
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null 2>&1
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1

    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist"
    rm -rf "$ICONSET_DIR"
    echo "  Generated AppIcon.icns"
fi

# Copy Sparkle.framework
SPARKLE_FW="$(swift build -c release --show-bin-path)/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    echo "==> Bundling Sparkle.framework..."
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    cp -R "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/"
    # Add rpath so the binary can find Sparkle in Frameworks
    install_name_tool -add_rpath @loader_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
fi

# Clean resource forks
xattr -cr "$APP_BUNDLE" 2>/dev/null
find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null

# Ad-hoc code sign
echo "==> Code signing (ad-hoc)..."
codesign --force --deep -s - "$APP_BUNDLE"

# Create DMG
echo "==> Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

DMG_OUTPUT="$BUILD_DIR/$DMG_NAME"
rm -f "$DMG_OUTPUT"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

rm -rf "$DMG_STAGING"

echo ""
echo "==> Build complete!"
echo "    App: $APP_BUNDLE"
echo "    DMG: $DMG_OUTPUT"
