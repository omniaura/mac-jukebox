#!/bin/bash
# Emit Info.plist for Jukebox.app. VERSION comes from the environment.
VERSION=${VERSION:-"0.0.0"}
cat << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Jukebox</string>
    <key>CFBundleIdentifier</key>
    <string>com.omniaura.mac-jukebox</string>
    <key>CFBundleName</key>
    <string>Jukebox</string>
    <key>CFBundleDisplayName</key>
    <string>Jukebox</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>Jukebox plays music files from external drives.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Omni Aura. MIT License.</string>
</dict>
</plist>
PLIST
