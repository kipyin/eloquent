SCHEME := Eloquent
PROJECT := Eloquent.xcodeproj
CONFIG ?= Debug
DERIVED := build
DESTINATION ?= platform=macOS,arch=arm64
ARCHIVE_PATH := $(DERIVED)/Eloquent.xcarchive
EXPORT_PATH := $(DERIVED)/export
EXPORT_OPTIONS := ExportOptions-DeveloperID.plist
RELEASE_ZIP := $(DERIVED)/Eloquent.zip

# Full Xcode.app (or Xcode-beta.app) is required. Command Line Tools alone
# is not enough. If xcodebuild fails with a CLT error, point at the Xcode
# you actually have, for example:
#   export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
#   # or: sudo xcode-select -s /Applications/Xcode.app

# Local build/test/run: ad-hoc unless DEVELOPMENT_TEAM is set, then Apple
# Development (Keychain ACL survives rebuilds). Not the public Release story;
# see docs/release.md.
SIGNING_ARGS := CODE_SIGN_IDENTITY=-
ifneq ($(DEVELOPMENT_TEAM),)
SIGNING_ARGS := CODE_SIGN_IDENTITY=Apple\ Development DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM)
endif

.PHONY: build run open clean test archive release-zip

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) $(SIGNING_ARGS) build

run: build
	open "$(DERIVED)/Build/Products/$(CONFIG)/Eloquent.app"

open:
	open $(PROJECT)

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) $(SIGNING_ARGS) -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 120 test

archive:
	@if [ -z "$(DEVELOPMENT_TEAM)" ]; then \
		echo "make archive needs DEVELOPMENT_TEAM and a Developer ID Application certificate." >&2; \
		echo "Copy Config/Release-Signing.xcconfig.example to Config/Release-Signing.xcconfig, or:" >&2; \
		echo "  export DEVELOPMENT_TEAM=YOUR_TEAM_ID" >&2; \
		echo "See docs/release.md" >&2; \
		exit 1; \
	fi
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination '$(DESTINATION)' -derivedDataPath $(DERIVED) -archivePath $(ARCHIVE_PATH) CODE_SIGN_IDENTITY=Developer\ ID\ Application DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) ENABLE_HARDENED_RUNTIME=YES archive

release-zip: archive
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportOptionsPlist $(EXPORT_OPTIONS) -exportPath $(EXPORT_PATH)
	ditto -c -k --keepParent "$(EXPORT_PATH)/Eloquent.app" "$(RELEASE_ZIP)"
	@echo "Wrote $(RELEASE_ZIP)"
	@echo "Not notarized. Staple after notarytool. GitHub Release zips are notarized+stapled in ci_post_xcodebuild.sh. DMG is not produced yet. See docs/release.md"

clean:
	rm -rf $(DERIVED)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) clean
