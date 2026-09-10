#!/bin/bash
set -e

mkdir -p deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries
mkdir -p deb_root/usr/libexec
mkdir -p deb_root/Library/LaunchDaemons
mkdir -p deb_root/DEBIAN

# Find and copy tweak dylib
DYLIB=$(find tweak/.theos -name "fembabe_overlay.dylib" 2>/dev/null | head -1)
cp "$DYLIB" deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries/
echo '{ Filter = { Bundles = ( "com.apple.springboard" ); }; }' > deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries/fembabe_overlay.plist

# Find and copy daemon
DAEMON=$(find daemon/.theos -name "vcam_netd" -type f 2>/dev/null | head -1)
if [ -n "$DAEMON" ]; then
    cp "$DAEMON" deb_root/usr/libexec/
    chmod 755 deb_root/usr/libexec/vcam_netd
    
    # LaunchDaemon plist
    cat > deb_root/Library/LaunchDaemons/com.fembabe.vcam.netd.plist << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fembabe.vcam.netd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/libexec/vcam_netd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>root</string>
</dict>
</plist>
PLISTEOF
    echo "Daemon included"
else
    echo "WARNING: Daemon not found, tweak-only package"
fi

# Control file
cat > deb_root/DEBIAN/control << CTRLEOF
Package: com.fembabe.cam
Name: FemBabe Camera
Version: 1.1.63
Architecture: iphoneos-arm64
Maintainer: dev
Section: Tweaks
Depends: mobilesubstrate
Description: v63 FULL iOS 18 fix with daemon
CTRLEOF

# Post-install to load daemon
cat > deb_root/DEBIAN/postinst << 'POSTEOF'
#!/bin/bash
if [ -f /Library/LaunchDaemons/com.fembabe.vcam.netd.plist ]; then
    launchctl load /Library/LaunchDaemons/com.fembabe.vcam.netd.plist 2>/dev/null || true
fi
exit 0
POSTEOF
chmod 755 deb_root/DEBIAN/postinst

# Pre-remove to unload daemon
cat > deb_root/DEBIAN/prerm << 'PRERMEOF'
#!/bin/bash
launchctl unload /Library/LaunchDaemons/com.fembabe.vcam.netd.plist 2>/dev/null || true
exit 0
PRERMEOF
chmod 755 deb_root/DEBIAN/prerm

dpkg-deb -Zxz -b deb_root fembabecam_v1.1.63.deb
echo "Package built!"
