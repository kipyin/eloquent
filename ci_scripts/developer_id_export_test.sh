#!/bin/sh
# Regression: an ad-hoc Xcode Cloud archive has no ApplicationProperties.Team,
# and exportArchive then fails with "No Team Found in Archive".
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
STAMP="$SCRIPT_DIR/stamp_developer_id_export.py"
TEMPLATE="$REPO_ROOT/ExportOptions-DeveloperID.plist"
TEAM=TESTTEAM01
OTHER=OTHERTEAM1

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

write_archive() {
	root=$1
	team_xml=$2
	mkdir -p "$root/Products/Applications/Eloquent.app/Contents/MacOS"
	cat > "$root/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ApplicationProperties</key>
	<dict>
		<key>ApplicationPath</key>
		<string>Applications/Eloquent.app</string>
		<key>CFBundleIdentifier</key>
		<string>com.kipyin.eloquent</string>
		<key>SigningIdentity</key>
		<string>Sign to Run Locally</string>
		$team_xml
	</dict>
</dict>
</plist>
EOF
}

assert_team() {
	plist=$1
	expected=$2
	python3 - "$plist" "$expected" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as handle:
    props = plistlib.load(handle)["ApplicationProperties"]
if props.get("Team") != sys.argv[2]:
    raise SystemExit("team mismatch")
if props.get("CFBundleIdentifier") != "com.kipyin.eloquent":
    raise SystemExit("bundle id was not preserved")
PY
}

assert_export_team() {
	plist=$1
	expected=$2
	python3 - "$plist" "$expected" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as handle:
    export = plistlib.load(handle)
if export.get("teamID") != sys.argv[2]:
    raise SystemExit("export teamID mismatch")
if export.get("method") != "developer-id":
    raise SystemExit("export method changed")
if export.get("signingCertificate") != "Developer ID Application":
    raise SystemExit("signingCertificate changed")
PY
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT HUP TERM

# Missing Team is the Build 9 failure. Stamp it and hide the value.
write_archive "$TMP/missing.xcarchive" ""
log="$TMP/missing.log"
if ! DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/missing.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/missing-export.plist" \
	--no-resign \
	>"$TMP/missing.out" 2>"$log"; then
	cat "$log" >&2
	fail "stamp missing team command failed"
fi
assert_team "$TMP/missing.xcarchive/Info.plist" "$TEAM"
assert_export_team "$TMP/missing-export.plist" "$TEAM"
assert_log_hides "$log" "$TEAM"
grep -q "No Team Found in Archive" "$log" || fail "stamp log should name the export error"
echo "ok: stamp missing team"

# Empty Team is the same failure.
write_archive "$TMP/empty.xcarchive" "<key>Team</key><string></string>"
DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/empty.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/empty-export.plist" \
	--no-resign \
	>"$TMP/empty.out" 2>"$TMP/empty.log"
assert_team "$TMP/empty.xcarchive/Info.plist" "$TEAM"
assert_log_hides "$TMP/empty.log" "$TEAM"
echo "ok: stamp empty team"

# A team already in the archive wins over DEVELOPMENT_TEAM.
write_archive "$TMP/kept.xcarchive" "<key>Team</key><string>${OTHER}</string>"
log="$TMP/kept.log"
DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/kept.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/kept-export.plist" \
	--no-resign \
	>"$TMP/kept.out" 2>"$log"
assert_team "$TMP/kept.xcarchive/Info.plist" "$OTHER"
assert_export_team "$TMP/kept-export.plist" "$OTHER"
assert_log_hides "$log" "$TEAM"
assert_log_hides "$log" "$OTHER"
grep -q "does not match" "$log" || fail "mismatch should be reported without values"
echo "ok: keep archive team"

# No team anywhere: this is the red export path.
write_archive "$TMP/none.xcarchive" ""
log="$TMP/none.log"
set +e
DEVELOPMENT_TEAM= python3 "$STAMP" \
	--archive "$TMP/none.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/none-export.plist" \
	--no-resign \
	>"$TMP/none.out" 2>"$log"
code=$?
set -e
[ "$code" -eq 2 ] || fail "expected exit 2 when no team, got $code"
grep -q "No Team Found in Archive" "$log" || fail "missing-team error should name the export failure"
echo "ok: refuse export without a team"

# A non-id value must not be copied into the archive or the log.
write_archive "$TMP/bad.xcarchive" ""
secret=supersecretvalue
log="$TMP/bad.log"
set +e
DEVELOPMENT_TEAM=$secret python3 "$STAMP" \
	--archive "$TMP/bad.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/bad-export.plist" \
	--no-resign \
	>"$TMP/bad.out" 2>"$log"
code=$?
set -e
[ "$code" -eq 2 ] || fail "expected exit 2 for a bad team id, got $code"
assert_log_hides "$log" "$secret"
python3 - "$TMP/bad.xcarchive/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as handle:
    props = plistlib.load(handle)["ApplicationProperties"]
if props.get("Team"):
    raise SystemExit("invalid team was written")
PY
echo "ok: reject invalid team id"

# Re-sign an ad-hoc app when a Developer ID identity for that team exists.
BIN="$TMP/bin"
mkdir -p "$BIN"
cat > "$BIN/codesign" <<'EOF'
#!/bin/sh
if [ -n "${CODESIGN_LOG:-}" ]; then
	printf '%s\n' "$*" >> "$CODESIGN_LOG"
fi
if [ "$1" = "-dv" ]; then
	echo "Signature=adhoc" >&2
	echo "TeamIdentifier=not set" >&2
	exit 0
fi
if [ "$1" = "-d" ]; then
	printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict></dict></plist>'
	exit 0
fi
exit 0
EOF
cat > "$BIN/security" <<'EOF'
#!/bin/sh
if [ "$1" = "find-identity" ]; then
	printf '%s\n' '  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Example (TESTTEAM01)"'
	exit 0
fi
exit 1
EOF
chmod +x "$BIN/codesign" "$BIN/security"
write_archive "$TMP/resign.xcarchive" ""
log="$TMP/resign.log"
CODESIGN_LOG="$TMP/codesign.log"
export CODESIGN_LOG
PATH="$BIN:/usr/bin:/bin" DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/resign.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/resign-export.plist" \
	--product Eloquent \
	>"$TMP/resign.out" 2>"$log"
assert_team "$TMP/resign.xcarchive/Info.plist" "$TEAM"
assert_log_hides "$log" "$TEAM"
grep -q -- "--sign Developer ID Application: Example (TESTTEAM01)" "$CODESIGN_LOG" || fail "did not re-sign with Developer ID"
grep -q -- "--options runtime" "$CODESIGN_LOG" || fail "re-sign dropped hardened runtime"
grep -q -- "--timestamp" "$CODESIGN_LOG" || fail "re-sign dropped secure timestamp"
python3 - "$TMP/resign.xcarchive/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as handle:
    identity = plistlib.load(handle)["ApplicationProperties"].get("SigningIdentity")
if identity != "Developer ID Application":
    raise SystemExit("SigningIdentity still ad-hoc after re-sign")
PY
echo "ok: re-sign ad-hoc archive"

# A team signature stays as it is.
SIGNED_BIN="$TMP/signed-bin"
mkdir -p "$SIGNED_BIN"
cat > "$SIGNED_BIN/codesign" <<'EOF'
#!/bin/sh
if [ -n "${CODESIGN_LOG:-}" ]; then
	printf '%s\n' "$*" >> "$CODESIGN_LOG"
fi
if [ "$1" = "-dv" ]; then
	echo "Signature size=123" >&2
	echo "TeamIdentifier=TESTTEAM01" >&2
	exit 0
fi
echo "unexpected codesign $*" >&2
exit 1
EOF
cat > "$SIGNED_BIN/security" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$SIGNED_BIN/codesign" "$SIGNED_BIN/security"
write_archive "$TMP/signed.xcarchive" "<key>Team</key><string>${TEAM}</string>"
log="$TMP/signed.log"
CODESIGN_LOG="$TMP/signed-codesign.log"
export CODESIGN_LOG
PATH="$SIGNED_BIN:/usr/bin:/bin" DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/signed.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/signed-export.plist" \
	>"$TMP/signed.out" 2>"$log"
assert_log_hides "$log" "$TEAM"
if grep -q -- "--force" "$CODESIGN_LOG"; then
	fail "re-signed an archive that already had a team"
fi
python3 - "$TMP/signed.xcarchive/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as handle:
    identity = plistlib.load(handle)["ApplicationProperties"].get("SigningIdentity")
if identity != "Sign to Run Locally":
    raise SystemExit("SigningIdentity changed on an already-signed archive")
PY
echo "ok: leave a team-signed archive"

# codesign failure still stamps the team and does not print it.
FAIL_BIN="$TMP/fail-bin"
mkdir -p "$FAIL_BIN"
cat > "$FAIL_BIN/codesign" <<'EOF'
#!/bin/sh
if [ "$1" = "-dv" ]; then
	echo "Signature=adhoc" >&2
	echo "TeamIdentifier=not set" >&2
	exit 0
fi
if [ "$1" = "-d" ]; then
	printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict></dict></plist>'
	exit 0
fi
echo "codesign failed for TESTTEAM01" >&2
exit 1
EOF
cp "$BIN/security" "$FAIL_BIN/security"
chmod +x "$FAIL_BIN/codesign" "$FAIL_BIN/security"
write_archive "$TMP/fail.xcarchive" ""
log="$TMP/fail.log"
PATH="$FAIL_BIN:/usr/bin:/bin" DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/fail.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/fail-export.plist" \
	>"$TMP/fail.out" 2>"$log"
assert_team "$TMP/fail.xcarchive/Info.plist" "$TEAM"
assert_export_team "$TMP/fail-export.plist" "$TEAM"
assert_log_hides "$log" "$TEAM"
grep -q "re-sign with Developer ID Application failed" "$log" || fail "expected re-sign failure to be reported"
echo "ok: export prep survives a re-sign failure"

# No codesign on PATH: still stamp so exportArchive can sign.
write_archive "$TMP/nocodesign.xcarchive" ""
log="$TMP/nocodesign.log"
PATH="/usr/bin:/bin" DEVELOPMENT_TEAM=$TEAM python3 "$STAMP" \
	--archive "$TMP/nocodesign.xcarchive" \
	--export-template "$TEMPLATE" \
	--export-out "$TMP/nocodesign-export.plist" \
	>"$TMP/nocodesign.out" 2>"$log"
assert_team "$TMP/nocodesign.xcarchive/Info.plist" "$TEAM"
assert_log_hides "$log" "$TEAM"
grep -q "codesign not available" "$log" || fail "expected codesign skip"
echo "ok: stamp when codesign is absent"

# ci_pre writes the overlay and does not print the team. Command-line
# CODE_SIGN_IDENTITY=- still wins; the log has to say so.
PRE_ROOT="$TMP/pre-repo"
mkdir -p "$PRE_ROOT/Config"
log="$TMP/pre.log"
CI_XCODEBUILD_ACTION=archive CI_PRIMARY_REPOSITORY_PATH="$PRE_ROOT" DEVELOPMENT_TEAM=$TEAM \
	sh "$SCRIPT_DIR/ci_pre_xcodebuild.sh" >"$log" 2>&1
assert_log_hides "$log" "$TEAM"
grep -q "CODE_SIGN_IDENTITY=-" "$log" || fail "ci_pre should explain the Cloud command-line override"
grep -q "DEVELOPMENT_TEAM = ${TEAM}" "$PRE_ROOT/Config/Release-Signing.xcconfig" || fail "overlay missing team"
grep -q "CODE_SIGN_IDENTITY = Developer ID Application" "$PRE_ROOT/Config/Release-Signing.xcconfig" || fail "overlay missing identity"
echo "ok: ci_pre overlay"

# ci_post export path: ad-hoc archive, no Developer ID path, fake xcodebuild.
POST_ROOT="$TMP/post-repo"
mkdir -p "$POST_ROOT/Config" "$BIN"
cp "$TEMPLATE" "$POST_ROOT/ExportOptions-DeveloperID.plist"
write_archive "$POST_ROOT/Eloquent.xcarchive" ""
cat > "$BIN/xcodebuild" <<'EOF'
#!/bin/sh
prev=
plist=
export_path=
for arg in "$@"; do
	if [ "$prev" = "-exportOptionsPlist" ]; then
		plist=$arg
	fi
	if [ "$prev" = "-exportPath" ]; then
		export_path=$arg
	fi
	prev=$arg
done
if [ -z "$plist" ] || [ -z "$export_path" ]; then
	echo "xcodebuild fake: missing export args" >&2
	exit 1
fi
cp "$plist" "$XCODEBUILD_EXPORT_PLIST"
mkdir -p "$export_path/Eloquent.app/Contents/MacOS"
exit 0
EOF
cat > "$BIN/ditto" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$BIN/xcodebuild" "$BIN/ditto"
log="$TMP/post.log"
env -u GITHUB_TOKEN -u GH_TOKEN -u CI_TAG -u CI_GIT_TAG -u CI_GIT_REF \
	-u CI_DEVELOPER_ID_SIGNED_APP_PATH -u APP_STORE_CONNECT_API_KEY_P8 \
	CI_ARCHIVE_PATH="$POST_ROOT/Eloquent.xcarchive" \
	CI_XCODEBUILD_EXIT_CODE=0 \
	CI_PRIMARY_REPOSITORY_PATH="$POST_ROOT" \
	CI_PRODUCT=Eloquent \
	DEVELOPMENT_TEAM=$TEAM \
	XCODEBUILD_EXPORT_PLIST="$TMP/used-export.plist" \
	PATH="$BIN:/usr/bin:/bin" \
	sh "$SCRIPT_DIR/ci_post_xcodebuild.sh" >"$log" 2>&1 || fail "ci_post export path failed"
assert_log_hides "$log" "$TEAM"
grep -q "CI_DEVELOPER_ID_SIGNED_APP_PATH missing" "$log" || fail "ci_post should explain the missing Developer ID path"
test -f "$TMP/used-export.plist" || fail "xcodebuild was not called"
assert_export_team "$TMP/used-export.plist" "$TEAM"
assert_team "$POST_ROOT/Eloquent.xcarchive/Info.plist" "$TEAM"
echo "ok: ci_post exports a stamped archive"

echo "developer_id_export_test: pass"
