SCHEME := ClipboardTTS
PROJECT := ClipboardTTS.xcodeproj
CONFIG ?= Debug
DERIVED := build

.PHONY: build run open clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -arch arm64 -derivedDataPath $(DERIVED) build

run: build
	open "$(DERIVED)/Build/Products/$(CONFIG)/ClipboardTTS.app"

open:
	open $(PROJECT)

clean:
	rm -rf $(DERIVED)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) clean
