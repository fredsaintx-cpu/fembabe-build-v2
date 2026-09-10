#!/bin/bash
set -e

mkdir -p deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries
mkdir -p deb_root/DEBIAN

# Find the dylib (could be in debug or release)
DYLIB=$(find tweak/.theos -name "fembabe_overlay.dylib" 2>/dev/null | head -1)
if [ -z "$DYLIB" ]; then
    echo "ERROR: Cannot find dylib"
    find tweak/.theos -type f -name "*.dylib" 2>/dev/null
    exit 1
fi

cp "$DYLIB" deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries/
echo '{ Filter = { Bundles = ( "com.apple.springboard" ); }; }' > deb_root/var/jb/Library/MobileSubstrate/DynamicLibraries/fembabe_overlay.plist

cat > deb_root/DEBIAN/control << CTRLEOF
Package: com.fembabe.cam
Name: FemBabe Camera
Version: 1.1.62
Architecture: iphoneos-arm64
Maintainer: dev
Section: Tweaks
Depends: mobilesubstrate
Description: v62 iOS 18 ready
CTRLEOF

dpkg-deb -Zxz -b deb_root fembabecam_v1.1.62.deb
