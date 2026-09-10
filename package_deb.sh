#!/bin/bash
set -e

VERSION="1.1.17"
DYLIB=".theos/obj/debug/fembabe_overlay.dylib"

rm -rf staging
mkdir -p staging/var/jb/Library/MobileSubstrate/DynamicLibraries
mkdir -p staging/DEBIAN

cp "$DYLIB" staging/var/jb/Library/MobileSubstrate/DynamicLibraries/
cp fembabe_overlay.plist staging/var/jb/Library/MobileSubstrate/DynamicLibraries/

# Add original dylibs if present
for f in staging/orig/*.dylib staging/orig/*.plist; do
    [ -f "$f" ] && cp "$f" staging/var/jb/Library/MobileSubstrate/DynamicLibraries/ 2>/dev/null || true
done

cat > staging/DEBIAN/control << CTRL
Package: com.fembabe.overlay
Name: FemBabe Overlay
Version: ${VERSION}
Architecture: iphoneos-arm64
Description: FemBabe camera overlay v17 - Direct API activation
Author: FemBabe
Section: Tweaks
CTRL

chmod 755 staging/var/jb/Library/MobileSubstrate/DynamicLibraries/*.dylib 2>/dev/null || true
mkdir -p packages
dpkg-deb -Zxz -b staging "packages/fembabecam_v${VERSION}.deb"
echo "Built: packages/fembabecam_v${VERSION}.deb"
