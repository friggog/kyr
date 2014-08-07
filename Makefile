ARCHS = armv7s armv7 arm64
TARGET = iPhone:7.1
ADDITIONAL_CFLAGS = -fobjc-arc

include theos/makefiles/common.mk

TWEAK_NAME = kyr
kyr_FILES = Tweak.xm FDWaveformView.m
kyr_FRAMEWORKS = UIKit AVFoundation MediaPLayer CoreGraphics QuartzCore CoreMedia

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
