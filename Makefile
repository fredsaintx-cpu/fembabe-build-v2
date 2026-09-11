ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libroothide

libroothide_FILES = libroothide.c
libroothide_CFLAGS = -fvisibility=default
libroothide_LDFLAGS = -install_name /var/jb/usr/lib/libroothide.dylib
libroothide_INSTALL_PATH = /var/jb/usr/lib

include $(THEOS_MAKE_PATH)/library.mk
