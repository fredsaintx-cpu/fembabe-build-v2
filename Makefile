ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = fembabe_overlay
fembabe_overlay_FILES = Tweak.xm
fembabe_overlay_FRAMEWORKS = UIKit
fembabe_overlay_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
