SCHEME := Eloquent
PROJECT := Eloquent.xcodeproj
CONFIG ?= Debug
DERIVED := build
DESTINATION ?= platform=macOS,arch=arm64

# Full Xcode.app (or Xcode-beta.app) is required. Command Line Tools alone
# is not enough. If xcodebuild fails with a CLT error, point at the Xcode
# you actually have, for example:
#   export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
#   # or: sudo xcode-select -s /Applications/Xcode.app

# Optional: sign with your own Apple Development certificate so macOS
# Keychain stops re-prompting after every rebuild. Not committed per-repo;
# set it in your shell profile, e.g. export DEVELOPMENT_TEAM=ABCDEF1234
SIGNING_ARGS :=
ifneq ($(DEVELOPMENT_TEAM),)
SIGNING_ARGS := CODE_SIGN_IDENTITY=Apple\ Development DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM)
endif

.PHONY: build run open clean test

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) $(SIGNING_ARGS) build

run: build
	open "$(DERIVED)/Build/Products/$(CONFIG)/Eloquent.app"

open:
	open $(PROJECT)

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) $(SIGNING_ARGS) -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 120 test

clean:
	rm -rf $(DERIVED)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) clean
