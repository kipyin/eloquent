#!/bin/sh
# Ad-hoc Xcode Cloud archives cannot Developer ID-export (No Team Found).
# ci_post must codesign the archived app instead of calling exportArchive.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
SIGN="$SCRIPT_DIR/sign_developer_id.py"
TEAM=TESTTEAM01

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_log_hides() {
	log=$1
	secret=$2
	if grep -F -q -- "$secret" "$log"; then
		fail "log contains a team id or secret"
	fi
}

make_app() {
	mkdir -p "$1/Contents/MacOS"
	printf '#!/bin/sh\n' > "$1/Contents/MacOS/Eloquent"
}

install_fakes() {
	bin=$1
	state=$2
	mkdir -p "$bin"
	cat > "$bin/codesign" <<EOF
#!/bin/sh
if [ -n "\${CODESIGN_LOG:-}" ]; then
	printf '%s\n' "\$*" >> "\$CODESIGN_LOG"
fi
if [ "\$1" = "--force" ]; then
	if [ "\${CODESIGN_FORCE_EXIT:-0}" != "0" ]; then
		echo "codesign failed for TESTTEAM01" >&2
		exit "\$CODESIGN_FORCE_EXIT"
	fi
	echo signed > "$state"
	exit 0
fi
if [ "\$1" = "-dv" ]; then
	if [ -f "$state" ] && grep -q signed "$state"; then
		echo "Authority=Developer ID Application: Example (TESTTEAM01)" >&2
		echo "TeamIdentifier=TESTTEAM01" >&2
	else
		echo "Signature=adhoc" >&2
		echo "TeamIdentifier=not set" >&2
	fi
	exit 0
fi
if [ "\$1" = "-d" ]; then
	printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><false/></dict></plist>'
	exit 0
fi
exit 0
EOF
	cat > "$bin/security" <<'EOF'
#!/bin/sh
if [ "$1" = "find-identity" ]; then
	case "${SECURITY_IDENTITIES:-developer-id}" in
	none)
		printf '%s\n' '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Apple Development: Example (TESTTEAM01)"'
		;;
	name-only)
		printf '%s\n' '  1) BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB "Developer ID Application: Example Person"'
		;;
	other-team)
		printf '%s\n' '  1) CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC "Developer ID Application: Example Person (OTHERTEAM1)"'
		;;
	ambiguous)
		printf '%s\n' '  1) DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD "Developer ID Application: One (OTHERTEAM1)"'
		printf '%s\n' '  2) EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE "Developer ID Application: Two (OTHERTEAM2)"'
		;;
	prefer-match)
		printf '%s\n' '  1) FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF "Developer ID Application: Other (OTHERTEAM1)"'
		printf '%s\n' '  2) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example (TESTTEAM01)"'
		;;
	valid-section)
		printf '%s\n' '  Matching identities'
		printf '%s\n' '  1) DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD "Developer ID Application: Expired (TESTTEAM01)"'
		printf '%s\n' '     1 identities found'
		printf '%s\n' '  Valid identities only'
		printf '%s\n' '  1) BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB "Developer ID Application: Example Person"'
		printf '%s\n' '     1 valid identities found'
		;;
	secret)
		printf '%s\n' '-----BEGIN PRIVATE KEY-----'
		printf '%s\n' 'not-a-real-key'
		;;
	*)
		printf '%s\n' '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example (TESTTEAM01)"'
		;;
	esac
	exit 0
fi
exit 1
EOF
	chmod +x "$bin/codesign" "$bin/security"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT HUP TERM

# Happy path: copy the ad-hoc app and codesign Developer ID with entitlements.
SRC="$TMP/src/Eloquent.app"
DEST="$TMP/dest/Eloquent.app"
make_app "$SRC"
install_fakes "$TMP/bin" "$TMP/sign-state"
log="$TMP/sign.log"
CODESIGN_LOG="$TMP/codesign.log"
export CODESIGN_LOG
PATH="$TMP/bin:/usr/bin:/bin" DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$DEST" >"$TMP/sign.out" 2>"$log"
assert_log_hides "$log" "$TEAM"
test -d "$DEST/Contents/MacOS" || fail "signed app was not copied"
grep -q -- "--force" "$CODESIGN_LOG" || fail "codesign was not forced"
grep -q -- "--sign Developer ID Application: Example (TESTTEAM01)" "$CODESIGN_LOG" || fail "did not sign with Developer ID"
grep -q -- "--options runtime" "$CODESIGN_LOG" || fail "hardened runtime flag missing"
grep -q -- "--timestamp" "$CODESIGN_LOG" || fail "timestamp missing"
grep -q -- "--entitlements" "$CODESIGN_LOG" || fail "entitlements were not passed"
grep -q "signed the app with Developer ID Application" "$log" || fail "missing sign confirmation"
if grep -q "does not contain DEVELOPMENT_TEAM" "$log"; then
	fail "exact team match should not use the single-identity fallback"
fi
echo "ok: codesign developer id"

# Cloud displays one Developer ID as the person name, with no team id in the string.
log="$TMP/name-only.log"
: > "$TMP/sign-state"
CODESIGN_LOG="$TMP/name-only-codesign.log"
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=name-only DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/name-only/Eloquent.app" >"$TMP/name-only.out" 2>"$log" \
	|| fail "name-only Developer ID identity should be used"
assert_log_hides "$log" "$TEAM"
grep -q "does not contain DEVELOPMENT_TEAM" "$log" || fail "name-only fallback was not reported"
grep -q -- "--sign Developer ID Application: Example Person" "$CODESIGN_LOG" || fail "did not sign the name-only identity"
echo "ok: name-only identity"

# One Developer ID whose parenthetical team is not DEVELOPMENT_TEAM.
OTHER_TEAM=OTHERTEAM1
log="$TMP/other-team.log"
: > "$TMP/sign-state"
CODESIGN_LOG="$TMP/other-team-codesign.log"
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=other-team DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/other-team/Eloquent.app" >"$TMP/other-team.out" 2>"$log" \
	|| fail "single Developer ID identity should be used when the displayed team differs"
assert_log_hides "$log" "$TEAM"
assert_log_hides "$log" "$OTHER_TEAM"
grep -q -- "--sign Developer ID Application: Example Person (OTHERTEAM1)" "$CODESIGN_LOG" || fail "did not sign the only Developer ID identity"
echo "ok: single identity with a different team display"

# Ignore identities listed only above "Valid identities only".
log="$TMP/valid.log"
: > "$TMP/sign-state"
CODESIGN_LOG="$TMP/valid-codesign.log"
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=valid-section DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/valid/Eloquent.app" >"$TMP/valid.out" 2>"$log" \
	|| fail "valid-section Developer ID identity should be used"
assert_log_hides "$log" "$TEAM"
grep -q -- "--sign Developer ID Application: Example Person" "$CODESIGN_LOG" || fail "signed an identity from outside Valid identities only"
if grep -q "Expired" "$CODESIGN_LOG"; then
	fail "signed the expired identity"
fi
echo "ok: valid identities only"

# Several Developer ID identities and none contain DEVELOPMENT_TEAM: do not guess.
log="$TMP/ambiguous.log"
CODESIGN_LOG="$TMP/ambiguous-codesign.log"
: > "$CODESIGN_LOG"
set +e
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=ambiguous DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/ambiguous/Eloquent.app" >"$TMP/ambiguous.out" 2>"$log"
code=$?
set -e
[ "$code" -eq 3 ] || fail "expected exit 3 for ambiguous identities, got $code"
assert_log_hides "$log" "$TEAM"
assert_log_hides "$log" "$OTHER_TEAM"
assert_log_hides "$log" "OTHERTEAM2"
grep -q "no Developer ID Application identity" "$log" || fail "ambiguous identities were not reported"
grep -q "security find-identity -v -p codesigning" "$log" || fail "ambiguous failure omitted the identity listing"
grep -q '(\[team\])' "$log" || fail "team id in the identity listing was not masked"
if grep -q -- "--force" "$CODESIGN_LOG"; then
	fail "ambiguous identities should not codesign"
fi
echo "ok: ambiguous identities fail"

# When several identities exist, the one that contains DEVELOPMENT_TEAM wins.
log="$TMP/prefer.log"
: > "$TMP/sign-state"
CODESIGN_LOG="$TMP/prefer-codesign.log"
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=prefer-match DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/prefer/Eloquent.app" >"$TMP/prefer.out" 2>"$log" \
	|| fail "matching identity should win over another Developer ID"
assert_log_hides "$log" "$TEAM"
assert_log_hides "$log" "$OTHER_TEAM"
grep -q -- "--sign Developer ID Application: Example (TESTTEAM01)" "$CODESIGN_LOG" || fail "did not prefer the matching team"
if grep -q "does not contain DEVELOPMENT_TEAM" "$log"; then
	fail "a team match should not use the single-identity fallback"
fi
echo "ok: prefer matching team"

# No matching identity: fail, and do not print the team. Print a redacted listing.
log="$TMP/noid.log"
set +e
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=none DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/noid/Eloquent.app" >"$TMP/noid.out" 2>"$log"
code=$?
set -e
[ "$code" -eq 3 ] || fail "expected exit 3 for a missing identity, got $code"
assert_log_hides "$log" "$TEAM"
grep -q "no Developer ID Application identity" "$log" || fail "missing identity was not reported"
grep -q "security find-identity -v -p codesigning" "$log" || fail "missing identity omitted the identity listing"
grep -q "Apple Development: Example (\[team\])" "$log" || fail "redacted listing missing"
echo "ok: missing identity fails"

# A listing that looks like a PEM is not printed.
log="$TMP/secret.log"
set +e
PATH="$TMP/bin:/usr/bin:/bin" SECURITY_IDENTITIES=secret DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/secret/Eloquent.app" >"$TMP/secret.out" 2>"$log"
code=$?
set -e
[ "$code" -eq 3 ] || fail "expected exit 3 when the listing is unusable, got $code"
if grep -q "BEGIN PRIVATE KEY" "$log" || grep -q "not-a-real-key" "$log"; then
	fail "identity listing leaked key material"
fi
grep -q "unexpected secret material" "$log" || fail "secret listing was not replaced"
echo "ok: secret listing is not printed"

# A non-id value is not a team and is not logged.
secret=supersecretvalue
log="$TMP/bad.log"
set +e
DEVELOPMENT_TEAM=$secret PATH="$TMP/bin:/usr/bin:/bin" python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/bad/Eloquent.app" >"$TMP/bad.out" 2>"$log"
code=$?
set -e
[ "$code" -eq 2 ] || fail "expected exit 2 for a bad team id, got $code"
assert_log_hides "$log" "$secret"
echo "ok: reject invalid team id"

# codesign failure is fatal and redacts the team.
log="$TMP/force-fail.log"
CODESIGN_FORCE_EXIT=1 PATH="$TMP/bin:/usr/bin:/bin" DEVELOPMENT_TEAM=$TEAM python3 "$SIGN" \
	--source "$SRC" --dest "$TMP/force-fail/Eloquent.app" >"$TMP/force-fail.out" 2>"$log" \
	&& fail "codesign failure should fail the sign step"
assert_log_hides "$log" "$TEAM"
grep -q "codesign Developer ID Application failed" "$log" || fail "codesign failure was not reported"
echo "ok: codesign failure is fatal"

# ci_pre still writes the overlay and records that the command line wins.
PRE_ROOT="$TMP/pre-repo"
mkdir -p "$PRE_ROOT/Config"
log="$TMP/pre.log"
CI_XCODEBUILD_ACTION=archive CI_PRIMARY_REPOSITORY_PATH="$PRE_ROOT" DEVELOPMENT_TEAM=$TEAM \
	sh "$SCRIPT_DIR/ci_pre_xcodebuild.sh" >"$log" 2>&1
assert_log_hides "$log" "$TEAM"
grep -q "CODE_SIGN_IDENTITY=-" "$log" || fail "ci_pre should explain the Cloud command-line override"
grep -q "DEVELOPMENT_TEAM = ${TEAM}" "$PRE_ROOT/Config/Release-Signing.xcconfig" || fail "overlay missing team"
echo "ok: ci_pre overlay"

# ci_post signs the archived app and does not exportArchive.
POST_ROOT="$TMP/post-repo"
mkdir -p "$POST_ROOT/Eloquent.xcarchive/Products/Applications"
make_app "$POST_ROOT/Eloquent.xcarchive/Products/Applications/Eloquent.app"
cat > "$TMP/bin/ditto" <<'EOF'
#!/bin/sh
# Zip invocations are `ditto -c -k --keepParent app zip`. Copies are `ditto src dest`.
if [ "$1" = "-c" ]; then
	exit 0
fi
cp -R "$1" "$2"
EOF
cat > "$TMP/bin/xcodebuild" <<'EOF'
#!/bin/sh
echo "xcodebuild $*" >> "$XCODEBUILD_LOG"
exit 1
EOF
chmod +x "$TMP/bin/ditto" "$TMP/bin/xcodebuild"
: > "$TMP/sign-state"
log="$TMP/post.log"
XCODEBUILD_LOG="$TMP/xcodebuild.log"
export XCODEBUILD_LOG
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_TAG -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPER_ID_SIGNED_APP_PATH -u CI_DEVELOPMENT_SIGNED_APP_PATH \
	-u APP_STORE_CONNECT_API_KEY_P8 -u CODESIGN_FORCE_EXIT -u SECURITY_IDENTITIES \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	DEVELOPMENT_TEAM=$TEAM \
	CODESIGN_LOG="$TMP/post-codesign.log" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1 || fail "ci_post sign path failed"
assert_log_hides "$log" "$TEAM"
grep -q "signing the archived app" "$log" || fail "ci_post should sign the archived app"
grep -q -- "--sign Developer ID Application: Example (TESTTEAM01)" "$TMP/post-codesign.log" || fail "ci_post did not codesign Developer ID"
if [ -s "$XCODEBUILD_LOG" ]; then
	fail "ci_post called xcodebuild exportArchive"
fi
test -d "$POST_ROOT/build/release/Eloquent.app/Contents/MacOS" || fail "ci_post did not write the signed app"
echo "ok: ci_post signs archived app"

# Archive product missing: sign the development export instead.
DEV_APP="$TMP/dev/Eloquent.app"
make_app "$DEV_APP"
mkdir -p "$POST_ROOT/empty.xcarchive"
: > "$TMP/sign-state"
log="$TMP/devpath.log"
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_TAG -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPER_ID_SIGNED_APP_PATH -u APP_STORE_CONNECT_API_KEY_P8 \
	CI_ARCHIVE_PATH="$POST_ROOT/empty.xcarchive" \
	CI_DEVELOPMENT_SIGNED_APP_PATH="$DEV_APP" \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	DEVELOPMENT_TEAM=$TEAM \
	CODESIGN_LOG="$TMP/dev-codesign.log" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1 || fail "development-signed fallback failed"
assert_log_hides "$log" "$TEAM"
grep -q "CI_DEVELOPMENT_SIGNED_APP_PATH" "$log" || fail "fallback should name the development app"
grep -q -- "--force" "$TMP/dev-codesign.log" || fail "fallback did not codesign"
echo "ok: development app fallback"

echo "developer_id_sign_test: pass"
