ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TOOL_NAME = vcam_rtmpd

vcam_rtmpd_FILES = vcam_rtmpd.m
vcam_rtmpd_CFLAGS = -fobjc-arc
vcam_rtmpd_CODESIGN_FLAGS = -Sentitlements.plist
vcam_rtmpd_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk
