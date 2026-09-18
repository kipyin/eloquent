SCHEME := Eloquent
PROJECT := Eloquent.xcodeproj
CONFIG ?= Debug
DERIVED := build

# Optional: sign with your own Apple Development certificate so macOS
# Keychain stops re-prompting after every rebuild. Not committed per-repo;
# set it in your shell profile, e.g. export DEVELOPMENT_TEAM=ABCDEF1234
SIGNING_ARGS :=
ifneq ($(DEVELOPMENT_TEAM),)
SIGNING_ARGS := CODE_SIGN_IDENTITY=Apple\ Development DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM)
endif

.PHONY: build run open clean test

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -arch arm64 -derivedDataPath $(DERIVED) $(SIGNING_ARGS) build

run: build
	open "$(DERIVED)/Build/Products/$(CONFIG)/Eloquent.app"

open:
	open $(PROJECT)

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -arch arm64 -derivedDataPath $(DERIVED) $(SIGNING_ARGS) test

clean:
	rm -rf $(DERIVED)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) clean
