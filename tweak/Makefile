ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = fembabe_overlay
fembabe_overlay_FILES = Tweak.xm
fembabe_overlay_CFLAGS = -fobjc-arc
fembabe_overlay_FRAMEWORKS = UIKit AudioToolbox CoreMedia CoreVideo

include $(THEOS_MAKE_PATH)/tweak.mk
