SCHEME := Eloquent
PROJECT := Eloquent.xcodeproj
CONFIG ?= Debug
DERIVED := build

.PHONY: build run open clean test

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -arch arm64 -derivedDataPath $(DERIVED) build

run: build
	open "$(DERIVED)/Build/Products/$(CONFIG)/Eloquent.app"

open:
	open $(PROJECT)

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -arch arm64 -derivedDataPath $(DERIVED) test

clean:
	rm -rf $(DERIVED)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) clean
