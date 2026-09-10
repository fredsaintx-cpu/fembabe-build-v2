ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = fembabe_overlay

fembabe_overlay_FILES = Tweak.xm
fembabe_overlay_CFLAGS = -fobjc-arc
fembabe_overlay_LDFLAGS = -Wl,-not_for_dyld_shared_cache
fembabe_overlay_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/library.mk
