#!/bin/zsh
# Baut ClaudePet.app und startet es neu.
set -e
cd "$(dirname "$0")"
APP=ClaudePet.app
mkdir -p $APP/Contents/MacOS
swiftc -O -swift-version 5 main.swift Anim.swift -o $APP/Contents/MacOS/ClaudePet
cat > $APP/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClaudePet</string>
<key>CFBundleIdentifier</key><string>com.gabriel.claudepet</string>
<key>CFBundleName</key><string>Krümel</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
pkill -x ClaudePet || true
open $APP
