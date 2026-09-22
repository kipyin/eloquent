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
	echo "ci_pre_xcodebuild: Xcode Cloud passes CODE_SIGN_IDENTITY=- on the archive command line, so the archive is ad-hoc and Developer ID export fails with No Team Found in Archive until DEVELOPMENT_TEAM is set. See docs/release.md."
	exit 0
fi

# Value is not logged. Team ID is also embedded in signed binaries later.
# Command-line CODE_SIGN_IDENTITY=- from Xcode Cloud overrides the identity
# written here. ci_post stamps DEVELOPMENT_TEAM into that ad-hoc archive.
mkdir -p "$(dirname "$OVERLAY")"
cat > "$OVERLAY" <<EOF
// Written by ci_scripts/ci_pre_xcodebuild.sh. Gitignored.
// Xcode Cloud's archive command passes CODE_SIGN_IDENTITY=- and
// AD_HOC_CODE_SIGNING_ALLOWED=YES, which override CODE_SIGN_IDENTITY below.
// The archive stays ad-hoc until ci_post stamps DEVELOPMENT_TEAM for export.
DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM}
CODE_SIGN_IDENTITY = Developer ID Application
CODE_SIGN_STYLE = Automatic
ENABLE_HARDENED_RUNTIME = YES
EOF

echo "ci_pre_xcodebuild: wrote Config/Release-Signing.xcconfig for Developer ID Archive (DEVELOPMENT_TEAM not logged)."
echo "ci_pre_xcodebuild: Xcode Cloud passes CODE_SIGN_IDENTITY=- on the archive command line, which overrides this overlay. The archive is ad-hoc (Sign to Run Locally) until ci_post stamps the team or the Notarize post-action fills CI_DEVELOPER_ID_SIGNED_APP_PATH. See docs/release.md."
