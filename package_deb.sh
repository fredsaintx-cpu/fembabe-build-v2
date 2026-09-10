#!/bin/bash
set -e
VERSION="1.1.8-ios18"
DYLIB=".theos/obj/debug/fembabe_overlay.dylib"
mkdir -p packages staging/var/jb/Library/MobileSubstrate/DynamicLibraries
cp "$DYLIB" staging/var/jb/Library/MobileSubstrate/DynamicLibraries/fembabe_overlay.dylib
cp fembabe_overlay.plist staging/var/jb/Library/MobileSubstrate/DynamicLibraries/
mkdir -p staging/DEBIAN
cp control staging/DEBIAN/control
dpkg-deb -Zxz --root-owner-group -b staging "packages/fembabecam_${VERSION}_ios18.deb"
ls -la packages/
