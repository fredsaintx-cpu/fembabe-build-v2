#!/bin/bash
set -e

mkdir -p deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries
mkdir -p deb_root/usr/libexec
mkdir -p deb_root/Library/LaunchDaemons
mkdir -p deb_root/DEBIAN

# Copy tweak
cp tweak/.theos/obj/debug/fembabe_overlay.dylib deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries/
echo '{ Filter = { Bundles = ( "com.apple.springboard" ); }; }' > deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries/fembabe_overlay.plist

# Copy daemon if built
if [ -f daemon/.theos/obj/debug/vcam_netd ]; then
    cp daemon/.theos/obj/debug/vcam_netd deb_root/usr/libexec/
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
fi

# Control file
cat > deb_root/DEBIAN/control << CTRLEOF
Package: com.fembabe.cam
Name: FemBabe Camera
Version: 1.1.62
Architecture: iphoneos-arm64
Maintainer: dev
Section: Tweaks
Depends: mobilesubstrate
Description: v62 with iOS 18 daemon
CTRLEOF

# Post-install script to load daemon
cat > deb_root/DEBIAN/postinst << 'POSTEOF'
#!/bin/bash
if [ -f /Library/LaunchDaemons/com.fembabe.vcam.netd.plist ]; then
    launchctl load /Library/LaunchDaemons/com.fembabe.vcam.netd.plist 2>/dev/null || true
fi
exit 0
POSTEOF
chmod 755 deb_root/DEBIAN/postinst

dpkg-deb -Zxz -b deb_root fembabecam_v1.1.62.deb
