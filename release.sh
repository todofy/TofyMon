#!/bin/bash
set -e

# Make sure we are in the script's directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🚀 Building TofyUI in Release mode..."

# Navigate to ui directory
cd ui

# Try to use the Xcode toolchain if command line tools has issues
if xcrun --find swift >/dev/null 2>&1; then
    echo "💡 Using Xcode Toolchain..."
    xcrun swift build -c release
else
    echo "💡 Using Default Toolchain..."
    swift build -c release
fi

echo "📦 Creating TofyUI.app bundle..."
cd ..

# Create directories
APP_DIR="TofyUI.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary and resources
cp "ui/.build/release/TofyUI" "$MACOS_DIR/TofyUI"
chmod +x "$MACOS_DIR/TofyUI"

if [ -f "_assets/AppIcon.icns" ]; then
    echo "🎨 Copying App Icon..."
    cp "_assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TofyUI</string>
    <key>CFBundleIdentifier</key>
    <string>com.tofy.TofyUI</string>
    <key>CFBundleName</key>
    <string>TofyUI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
</dict>
</plist>
EOF

echo "✅ Success! TofyUI.app has been created in the root of the repository."
echo "👉 You can now move TofyUI.app to your /Applications folder or run it directly!"
