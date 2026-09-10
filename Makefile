ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = fembabe_netfix
fembabe_netfix_FILES = Tweak.xm
fembabe_netfix_CFLAGS = -fobjc-arc
fembabe_netfix_FRAMEWORKS = Foundation Network

include $(THEOS_MAKE_PATH)/tweak.mk
