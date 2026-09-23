#!/bin/sh
# Ad-hoc Xcode Cloud archives cannot Developer ID-export (No Team Found).
# When CI_DEVELOPER_ID_SIGNED_APP_PATH is set, ci_post uses that Managed app.
# Otherwise it codesigns the archived app instead of calling exportArchive.
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
echo "ok: codesign developer id"

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

# An empty CI_DEVELOPER_ID_SIGNED_APP_PATH is the same codesign fallback.
: > "$TMP/sign-state"
log="$TMP/empty-path.log"
: > "$TMP/empty-codesign.log"
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_TAG -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPMENT_SIGNED_APP_PATH -u APP_STORE_CONNECT_API_KEY_P8 \
	-u CODESIGN_FORCE_EXIT -u SECURITY_IDENTITIES \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_DEVELOPER_ID_SIGNED_APP_PATH= \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	DEVELOPMENT_TEAM=$TEAM \
	CODESIGN_LOG="$TMP/empty-codesign.log" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1 || fail "empty Managed path should codesign"
grep -q "signing the archived app" "$log" || fail "empty Managed path should sign the archive"
grep -q -- "--force" "$TMP/empty-codesign.log" || fail "empty Managed path did not codesign"
echo "ok: empty CI_DEVELOPER_ID_SIGNED_APP_PATH codesigns"

# Notarize configured: use the Managed app and do not codesign it.
MANAGED="$TMP/managed/Eloquent.app"
make_app "$MANAGED"
printf 'developer-id-managed\n' > "$MANAGED/Contents/MacOS/marker"
printf 'archive-product\n' > "$POST_ROOT/Eloquent.xcarchive/Products/Applications/Eloquent.app/Contents/MacOS/marker"
: > "$TMP/sign-state"
log="$TMP/managed.log"
: > "$TMP/managed-codesign.log"
: > "$XCODEBUILD_LOG"
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_TAG -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPMENT_SIGNED_APP_PATH -u DEVELOPMENT_TEAM \
	-u APP_STORE_CONNECT_API_KEY_P8 -u CODESIGN_FORCE_EXIT -u SECURITY_IDENTITIES \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_DEVELOPER_ID_SIGNED_APP_PATH="$MANAGED" \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	CODESIGN_LOG="$TMP/managed-codesign.log" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1 || fail "managed app path failed"
grep -q "using CI_DEVELOPER_ID_SIGNED_APP_PATH" "$log" || fail "ci_post should use the Managed app"
if grep -q -- "--force" "$TMP/managed-codesign.log"; then
	fail "Managed app was codesigned"
fi
grep -q "developer-id-managed" "$POST_ROOT/build/release/Eloquent.app/Contents/MacOS/marker" || fail "release app is not the Managed export"
if [ -s "$XCODEBUILD_LOG" ]; then
	fail "managed path called xcodebuild"
fi
echo "ok: ci_post uses CI_DEVELOPER_ID_SIGNED_APP_PATH"

# A set path that is not an app is not the codesign fallback.
log="$TMP/bad-managed.log"
: > "$TMP/bad-managed-codesign.log"
set +e
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_TAG -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPMENT_SIGNED_APP_PATH -u APP_STORE_CONNECT_API_KEY_P8 \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_DEVELOPER_ID_SIGNED_APP_PATH="$TMP/missing-managed" \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	DEVELOPMENT_TEAM=$TEAM \
	CODESIGN_LOG="$TMP/bad-managed-codesign.log" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1
code=$?
set -e
[ "$code" -ne 0 ] || fail "a missing Managed app should fail"
grep -q "was not found" "$log" || fail "missing Managed app was not reported"
if grep -q -- "--force" "$TMP/bad-managed-codesign.log"; then
	fail "missing Managed app fell through to codesign"
fi
echo "ok: set CI_DEVELOPER_ID_SIGNED_APP_PATH must exist"

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

# Tag Archive: trailing newlines on issuer and key id must not reach notarytool.
# Command substitution strips trailing newlines, so keep a sentinel until after.
issuer=$(printf ' 11111111-2222-4333-8444-555555555555\r\n\nX')
issuer=${issuer%X}
key_id=$(printf 'ABCDE12345\n\nX')
key_id=${key_id%X}
# Real newlines surround a one-line Cloud secret whose PEM body uses literal \n.
p8=$(printf '\n\n  -----BEGIN PRIVATE KEY-----\\nnot-a-real-key\\n-----END PRIVATE KEY-----  \n\nX')
p8=${p8%X}
cat > "$TMP/bin/xcrun" <<'EOF'
#!/bin/sh
if [ -n "${XCRUN_LOG:-}" ]; then
	python3 -c 'import json, os, sys; open(os.environ["XCRUN_LOG"], "a").write(json.dumps(sys.argv[1:]) + "\n")' "$@"
fi
if [ "${1:-}" = "notarytool" ] && [ -n "${XCRUN_KEY_COPY:-}" ]; then
	prev=
	for arg in "$@"; do
		if [ "$prev" = "--key" ]; then
			cp "$arg" "$XCRUN_KEY_COPY"
		fi
		prev=$arg
	done
fi
exit 0
EOF
chmod +x "$TMP/bin/xcrun"
: > "$TMP/sign-state"
log="$TMP/notary.log"
: > "$TMP/notary-codesign.log"
: > "$TMP/xcrun.log"
: > "$XCODEBUILD_LOG"
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPMENT_SIGNED_APP_PATH -u DEVELOPMENT_TEAM \
	-u CODESIGN_FORCE_EXIT -u SECURITY_IDENTITIES \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_DEVELOPER_ID_SIGNED_APP_PATH="$MANAGED" \
	CI_TAG=v0.1.4 \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	APP_STORE_CONNECT_ISSUER_ID="$issuer" \
	APP_STORE_CONNECT_KEY_ID="$key_id" \
	APP_STORE_CONNECT_API_KEY_P8="$p8" \
	CODESIGN_LOG="$TMP/notary-codesign.log" \
	XCRUN_LOG="$TMP/xcrun.log" \
	XCRUN_KEY_COPY="$TMP/notary-key.p8" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1 || fail "trimmed notary credentials should submit"
grep -q "using CI_DEVELOPER_ID_SIGNED_APP_PATH" "$log" || fail "tag Archive should still use the Managed app"
if grep -q -- "--force" "$TMP/notary-codesign.log"; then
	fail "tag Archive codesigned the Managed app"
fi
grep -q "developer-id-managed" "$POST_ROOT/build/release/Eloquent.app/Contents/MacOS/marker" || fail "tag Archive release app is not the Managed export"
assert_log_hides "$log" "11111111-2222-4333-8444-555555555555"
assert_log_hides "$log" "ABCDE12345"
assert_log_hides "$log" "not-a-real-key"
python3 - "$TMP/xcrun.log" "$TMP/notary-key.p8" <<'PY' || fail "notarytool argv was not trimmed"
import json
import sys

log_path, key_path = sys.argv[1], sys.argv[2]
calls = [json.loads(line) for line in open(log_path) if line.strip()]
submit = next(args for args in calls if args[:2] == ["notarytool", "submit"])

def flag(name):
    return submit[submit.index(name) + 1]

issuer = flag("--issuer")
key_id = flag("--key-id")
expected_issuer = "11111111-2222-4333-8444-555555555555"
expected_key_id = "ABCDE12345"
if issuer != expected_issuer:
    raise SystemExit("notarytool --issuer was not the trimmed UUID")
if key_id != expected_key_id:
    raise SystemExit("notarytool --key-id was not the trimmed key id")
if any(ch in issuer or ch in key_id for ch in "\r\n \t"):
    raise SystemExit("notarytool id still contains whitespace")
pem = open(key_path).read()
expected_pem = "-----BEGIN PRIVATE KEY-----\nnot-a-real-key\n-----END PRIVATE KEY-----\n"
if pem != expected_pem:
    raise SystemExit("p8 surrounding whitespace was not trimmed")
PY
echo "ok: notarytool argv trims issuer and key id"

# A non-UUID issuer fails before notarytool and is not printed.
bad_issuer=$(printf 'not-a-uuid-value\n\nX')
bad_issuer=${bad_issuer%X}
log="$TMP/bad-issuer.log"
: > "$TMP/xcrun-bad.log"
set +e
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPMENT_SIGNED_APP_PATH -u DEVELOPMENT_TEAM \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_DEVELOPER_ID_SIGNED_APP_PATH="$MANAGED" \
	CI_TAG=v0.1.4 \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	APP_STORE_CONNECT_ISSUER_ID="$bad_issuer" \
	APP_STORE_CONNECT_KEY_ID="$key_id" \
	APP_STORE_CONNECT_API_KEY_P8="$p8" \
	XCRUN_LOG="$TMP/xcrun-bad.log" \
	PATH="$TMP/bin:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1
code=$?
set -e
[ "$code" -ne 0 ] || fail "a non-UUID issuer should fail"
grep -q "is not a UUID after trimming whitespace" "$log" || fail "non-UUID issuer was not reported"
assert_log_hides "$log" "not-a-uuid-value"
if [ -s "$TMP/xcrun-bad.log" ]; then
	fail "non-UUID issuer called notarytool"
fi
echo "ok: non-UUID issuer fails closed"

echo "developer_id_sign_test: pass"
