THEOS_DEVICE_IP = 192.168.1.143
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libroothide

libroothide_FILES = libroothide.c
libroothide_CFLAGS = -fvisibility=default
libroothide_INSTALL_PATH = /var/jb/usr/lib

include $(THEOS_MAKE_PATH)/library.mk
