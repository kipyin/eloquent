#!/bin/sh
# Write a gitignored Developer ID overlay when Xcode Cloud (or a local env) has DEVELOPMENT_TEAM.
set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
OVERLAY="$REPO_ROOT/Config/Release-Signing.xcconfig"

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
	echo "ci_pre_xcodebuild: action=${CI_XCODEBUILD_ACTION:-unset}; leaving Release signing defaults."
	exit 0
fi

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
	echo "ci_pre_xcodebuild: DEVELOPMENT_TEAM unset; Archive uses committed Release defaults."
	echo "ci_pre_xcodebuild: set DEVELOPMENT_TEAM on the Xcode Cloud Release workflow for Developer ID. See docs/release.md."
	exit 0
fi

# Value is not logged. Team ID is also embedded in signed binaries later.
mkdir -p "$(dirname "$OVERLAY")"
cat > "$OVERLAY" <<EOF
DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM}
CODE_SIGN_IDENTITY = Developer ID Application
CODE_SIGN_STYLE = Automatic
ENABLE_HARDENED_RUNTIME = YES
EOF

echo "ci_pre_xcodebuild: wrote Config/Release-Signing.xcconfig for Developer ID Archive (DEVELOPMENT_TEAM not logged)."
