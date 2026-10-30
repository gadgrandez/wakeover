#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

APP=build/WakeOver.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp -R Resources "$APP/Contents/Resources"

swiftc -O -target "$(uname -m)-apple-macos14.0" -o "$APP/Contents/MacOS/WakeOver" Sources/*.swift
strip -x "$APP/Contents/MacOS/WakeOver"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
	<key>CFBundleExecutable</key><string>WakeOver</string>
	<key>CFBundleIdentifier</key><string>com.gadgrandez.WakeOver</string>
	<key>CFBundleName</key><string>WakeOver</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built: $APP"
