#!/bin/bash
set -e

VERSION="1.1.70"
PKG_DIR="/tmp/fembabe_pkg"

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/var/jb/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "$PKG_DIR/var/jb/usr/libexec"
mkdir -p "$PKG_DIR/var/jb/Library/LaunchDaemons"
mkdir -p "$PKG_DIR/DEBIAN"

# Copy tweak
cp tweak/.theos/obj/debug/fembabe_overlay.dylib "$PKG_DIR/var/jb/Library/MobileSubstrate/DynamicLibraries/"
cp tweak/fembabe_overlay.plist "$PKG_DIR/var/jb/Library/MobileSubstrate/DynamicLibraries/"

# Copy daemon
cp daemon/.theos/obj/debug/vcam_rtmpd "$PKG_DIR/var/jb/usr/libexec/"
chmod 755 "$PKG_DIR/var/jb/usr/libexec/vcam_rtmpd"

# Create LaunchDaemon plist
cat > "$PKG_DIR/var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fembabe.vcam.rtmpd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/var/jb/usr/libexec/vcam_rtmpd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
PLIST

# Control file
cat > "$PKG_DIR/DEBIAN/control" << CTRL
Package: com.fembabe.vcam
Name: FemBabe VCam
Description: FemBabe Virtual Camera with iOS 18 RTMP Proxy
Maintainer: FemBabe
Author: FemBabe
Section: Tweaks
Architecture: iphoneos-arm64
Version: $VERSION
Installed-Size: 512
Conflicts: com.x.obsvcamera
Replaces: com.x.obsvcamera
CTRL

# postinst
cat > "$PKG_DIR/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
/var/jb/usr/bin/launchctl unload /var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist 2>/dev/null || true
launchctl unload /var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist 2>/dev/null || true
/var/jb/usr/bin/launchctl load /var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist 2>/dev/null || true
launchctl load /var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist 2>/dev/null || true
exit 0
POSTINST
chmod 755 "$PKG_DIR/DEBIAN/postinst"

# prerm
cat > "$PKG_DIR/DEBIAN/prerm" << 'PRERM'
#!/bin/bash
/var/jb/usr/bin/launchctl unload /var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist 2>/dev/null || true
launchctl unload /var/jb/Library/LaunchDaemons/com.fembabe.vcam.rtmpd.plist 2>/dev/null || true
exit 0
PRERM
chmod 755 "$PKG_DIR/DEBIAN/prerm"

# Build deb
dpkg-deb -Zxz --root-owner-group -b "$PKG_DIR" "fembabecam_v${VERSION}.deb"
echo "Built fembabecam_v${VERSION}.deb"
