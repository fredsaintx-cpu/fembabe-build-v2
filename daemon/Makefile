ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = vcam_netd
vcam_netd_FILES = vcam_netd.m
vcam_netd_CFLAGS = -fobjc-arc
vcam_netd_FRAMEWORKS = Foundation
vcam_netd_CODESIGN_FLAGS = -Sentitlements.plist
vcam_netd_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk
