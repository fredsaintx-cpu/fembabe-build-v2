#!/bin/bash
set -e

mkdir -p out/var/jb/Library/MobileSubstrate/DynamicLibraries
mkdir -p out/var/jb/usr/libexec
mkdir -p out/var/jb/Library/LaunchDaemons
mkdir -p out/DEBIAN

# Copy tweak (check both locations)
if [ -f tweak/.theos/obj/fembabe_overlay.dylib ]; then
    cp tweak/.theos/obj/fembabe_overlay.dylib out/var/jb/Library/MobileSubstrate/DynamicLibraries/
elif [ -f tweak/.theos/obj/debug/fembabe_overlay.dylib ]; then
    cp tweak/.theos/obj/debug/fembabe_overlay.dylib out/var/jb/Library/MobileSubstrate/DynamicLibraries/
else
    echo "ERROR: Cannot find fembabe_overlay.dylib"
    find tweak/.theos -name "*.dylib" 2>/dev/null
    exit 1
fi

cp tweak/fembabe_overlay.plist out/var/jb/Library/MobileSubstrate/DynamicLibraries/

# Copy daemon
if [ -f daemon/.theos/obj/vcam_netd ]; then
    cp daemon/.theos/obj/vcam_netd out/var/jb/usr/libexec/
elif [ -f daemon/.theos/obj/debug/vcam_netd ]; then
    cp daemon/.theos/obj/debug/vcam_netd out/var/jb/usr/libexec/
fi
chmod 755 out/var/jb/usr/libexec/vcam_netd

# LaunchDaemon plist
cat > out/var/jb/Library/LaunchDaemons/com.fembabe.vcam.netd.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.fembabe.vcam.netd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/var/jb/usr/libexec/vcam_netd</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

# Control
cat > out/DEBIAN/control << 'CTRL'
Package: com.fembabe.vcam
Name: FemBabe VCam
Version: 1.1.69
Architecture: iphoneos-arm64
Maintainer: FemBabe
Section: Tweaks
Description: FemBabe VCam + RTMP Proxy
CTRL

# Scripts
cat > out/DEBIAN/postinst << 'POST'
#!/bin/bash
launchctl load /var/jb/Library/LaunchDaemons/com.fembabe.vcam.netd.plist 2>/dev/null || true
exit 0
POST
chmod 755 out/DEBIAN/postinst

cat > out/DEBIAN/prerm << 'PRE'
#!/bin/bash
launchctl unload /var/jb/Library/LaunchDaemons/com.fembabe.vcam.netd.plist 2>/dev/null || true
exit 0
PRE
chmod 755 out/DEBIAN/prerm

dpkg-deb -Zxz -b out fembabecam_v1.1.69.deb
echo "Built: fembabecam_v1.1.69.deb"
