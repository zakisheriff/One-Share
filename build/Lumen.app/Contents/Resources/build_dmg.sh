#!/bin/bash

# Exit on error
set -e

APP_NAME="Lumen"
SCHEME="Lumen"
PROJECT="Lumen.xcodeproj"
BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR"
DMG_NAME="$APP_NAME.dmg"
APP_ICON="../AppLogo.jpeg"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Check if project exists in current dir, else check parent
if [ -d "$PROJECT" ]; then
    echo "Found project in current directory"
elif [ -d "../$PROJECT" ]; then
    echo "Found project in parent directory"
    cd ..
else
    echo "Error: Could not find $PROJECT"
    exit 1
fi

echo "Building Archive..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    ARCHS=arm64 \
    HEADER_SEARCH_PATHS="/opt/homebrew/include" \
    LIBRARY_SEARCH_PATHS="/opt/homebrew/lib" \
    SWIFT_OBJC_BRIDGING_HEADER="Lumen/Lumen-Bridging-Header.h" \
    OTHER_LDFLAGS="-L/opt/homebrew/lib -lmtp -lusb-1.0" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

echo "Exporting Archive..."
# Note: Since we are not signing, we just copy the app from the archive
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_PATH/"

# Convert JPEG icon to ICNS if it exists
if [ -f "$APP_ICON" ]; then
    echo "Converting app icon..."
    # Create temporary iconset directory
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Convert JPEG to various sizes using sips
    sips -z 16 16 "$APP_ICON" --out "$ICONSET_DIR/icon_16x16.png"
    sips -z 32 32 "$APP_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png"
    sips -z 32 32 "$APP_ICON" --out "$ICONSET_DIR/icon_32x32.png"
    sips -z 64 64 "$APP_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png"
    sips -z 128 128 "$APP_ICON" --out "$ICONSET_DIR/icon_128x128.png"
    sips -z 256 256 "$APP_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png"
    sips -z 256 256 "$APP_ICON" --out "$ICONSET_DIR/icon_256x256.png"
    sips -z 512 512 "$APP_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png"
    sips -z 512 512 "$APP_ICON" --out "$ICONSET_DIR/icon_512x512.png"
    sips -z 1024 1024 "$APP_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png"
    
    # Create ICNS file
    iconutil -c icns "$ICONSET_DIR" -o "$EXPORT_PATH/$APP_NAME.app/Contents/Resources/AppIcon.icns"
    
    # Clean up
    rm -rf "$ICONSET_DIR"
fi

echo "Creating DMG with custom icon..."
# Create a temporary directory for DMG creation
TEMP_DIR="$BUILD_DIR/dmg_temp"
mkdir -p "$TEMP_DIR"
cp -R "$EXPORT_PATH/$APP_NAME.app" "$TEMP_DIR/"

# Create icon for DMG
if [ -f "$APP_ICON" ]; then
    # Create .VolumeIcon.icns for DMG icon
    ICONSET_DIR="$BUILD_DIR/VolumeIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    sips -z 128 128 "$APP_ICON" --out "$ICONSET_DIR/icon_128x128.png"
    sips -z 256 256 "$APP_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png"
    iconutil -c icns "$ICONSET_DIR" -o "$TEMP_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$TEMP_DIR/.VolumeIcon.icns"
    rm -rf "$ICONSET_DIR"
fi

# Create the DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DIR" -ov -format UDZO "$DMG_NAME"

# Clean up
rm -rf "$TEMP_DIR"

echo "Done! DMG created at $DMG_NAME"