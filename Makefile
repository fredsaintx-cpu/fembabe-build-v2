ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = fembabe_overlay

fembabe_overlay_FILES = Tweak.xm
fembabe_overlay_CFLAGS = -fobjc-arc
fembabe_overlay_FRAMEWORKS = UIKit Foundation
fembabe_overlay_EXTRA_FRAMEWORKS = 

include $(THEOS_MAKE_PATH)/library.mk
