#!/bin/sh
# After a successful Xcode Cloud Archive, notarize and staple the Developer ID
# app on tag builds, zip it, and optionally attach it to a GitHub Release.
#
# Runs after xcodebuild and before Cloud's Notarize post-action. Keep that
# post-action on the Archive workflow: it is what populates
# CI_DEVELOPER_ID_SIGNED_APP_PATH. The GitHub zip is notarized here because
# Cloud has no custom-script hook after Notarize. Staple the .app, then zip;
# stapler cannot staple a zip.
set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
PRODUCT_NAME=${CI_PRODUCT:-Eloquent}
EXPORT_OPTIONS="$REPO_ROOT/ExportOptions-DeveloperID.plist"
OUT_DIR="$REPO_ROOT/build/release"
GITHUB_REPO=${GITHUB_REPOSITORY:-kipyin/eloquent}

KEY_FILE=
NOTARY_ZIP=

skip() {
	echo "ci_post_xcodebuild: $*"
	exit 0
}

cleanup_notary_materials() {
	if [ -n "$KEY_FILE" ]; then
		rm -f "$KEY_FILE"
		KEY_FILE=
	fi
	if [ -n "$NOTARY_ZIP" ]; then
		rm -f "$NOTARY_ZIP"
		NOTARY_ZIP=
	fi
}

if [ -z "${CI_ARCHIVE_PATH:-}" ]; then
	skip "CI_ARCHIVE_PATH unset; not an Archive action. Skipping packaging."
fi

if [ -n "${CI_XCODEBUILD_EXIT_CODE:-}" ] && [ "$CI_XCODEBUILD_EXIT_CODE" != "0" ]; then
	skip "xcodebuild failed (CI_XCODEBUILD_EXIT_CODE=$CI_XCODEBUILD_EXIT_CODE). Skipping packaging."
fi

if [ ! -d "$CI_ARCHIVE_PATH" ]; then
	echo "ci_post_xcodebuild: CI_ARCHIVE_PATH is not a directory: $CI_ARCHIVE_PATH" >&2
	exit 1
fi

mkdir -p "$OUT_DIR"

find_app() {
	candidate=$1
	if [ -z "$candidate" ] || [ ! -e "$candidate" ]; then
		return 1
	fi
	if [ -d "$candidate/Contents/MacOS" ]; then
		printf '%s\n' "$candidate"
		return 0
	fi
	if [ -d "$candidate/${PRODUCT_NAME}.app/Contents/MacOS" ]; then
		printf '%s\n' "$candidate/${PRODUCT_NAME}.app"
		return 0
	fi
	return 1
}

# Official Cloud name is CI_DEVELOPER_ID_SIGNED_APP_PATH (a .app or a
# directory that contains PRODUCT.app). Set when the workflow includes the
# Notarize (macOS) post-action, even though this script runs before that
# post-action finishes.
APP_PATH=
if APP_PATH=$(find_app "${CI_DEVELOPER_ID_SIGNED_APP_PATH:-}"); then
	echo "ci_post_xcodebuild: using CI_DEVELOPER_ID_SIGNED_APP_PATH."
else
	EXPORT_DIR="$OUT_DIR/export"
	mkdir -p "$EXPORT_DIR"
	echo "ci_post_xcodebuild: CI_DEVELOPER_ID_SIGNED_APP_PATH missing; exporting archive with ExportOptions-DeveloperID.plist."
	echo "ci_post_xcodebuild: add the Notarize (macOS) post-action on the Xcode Cloud Archive workflow so Cloud exports a Developer ID-signed app into CI_DEVELOPER_ID_SIGNED_APP_PATH. See docs/release.md."
	xcodebuild -exportArchive \
		-archivePath "$CI_ARCHIVE_PATH" \
		-exportOptionsPlist "$EXPORT_OPTIONS" \
		-exportPath "$EXPORT_DIR"
	if ! APP_PATH=$(find_app "$EXPORT_DIR"); then
		echo "ci_post_xcodebuild: export did not produce ${PRODUCT_NAME}.app in $EXPORT_DIR" >&2
		exit 1
	fi
fi

# Official tag start-condition variable is CI_TAG. CI_GIT_TAG is a synonym
# some images set; refs/tags/* on CI_GIT_REF covers the rest.
TAG=${CI_GIT_TAG:-${CI_TAG:-}}
if [ -z "$TAG" ]; then
	case "${CI_GIT_REF:-}" in
	refs/tags/*) TAG=${CI_GIT_REF#refs/tags/} ;;
	esac
fi

notarize_and_staple() {
	app=$1
	missing=
	[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ] || missing="$missing APP_STORE_CONNECT_KEY_ID"
	[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ] || missing="$missing APP_STORE_CONNECT_ISSUER_ID"
	[ -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ] || missing="$missing APP_STORE_CONNECT_API_KEY_P8"
	if [ -n "$missing" ]; then
		echo "ci_post_xcodebuild: tag Archive ${TAG} requires App Store Connect API credentials so the GitHub zip is notarized and stapled." >&2
		echo "ci_post_xcodebuild: missing:${missing}." >&2
		echo "ci_post_xcodebuild: set APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, and APP_STORE_CONNECT_API_KEY_P8 as Xcode Cloud Secrets (docs/release.md)." >&2
		echo "ci_post_xcodebuild: refusing to ship an unnotarized zip." >&2
		exit 1
	fi

	KEY_FILE=$(mktemp "${TMPDIR:-/tmp}/eloquent-notary-key.XXXXXX")
	NOTARY_ZIP="$OUT_DIR/${PRODUCT_NAME}-notary.zip"
	trap cleanup_notary_materials EXIT INT HUP TERM

	# Expand literal \n so a single-line Cloud secret still becomes PEM.
	# Do not log the key, key id, or issuer.
	printf '%b\n' "$APP_STORE_CONNECT_API_KEY_P8" > "$KEY_FILE"
	chmod 600 "$KEY_FILE"
	if ! grep -q "BEGIN .*PRIVATE KEY" "$KEY_FILE"; then
		echo "ci_post_xcodebuild: APP_STORE_CONNECT_API_KEY_P8 is not PEM (missing BEGIN PRIVATE KEY). Paste the full .p8 text as an Xcode Cloud Secret." >&2
		exit 1
	fi

	rm -f "$NOTARY_ZIP"
	ditto -c -k --keepParent "$app" "$NOTARY_ZIP"
	echo "ci_post_xcodebuild: submitting Developer ID app to notarytool (--wait)."
	xcrun notarytool submit "$NOTARY_ZIP" \
		--key "$KEY_FILE" \
		--key-id "$APP_STORE_CONNECT_KEY_ID" \
		--issuer "$APP_STORE_CONNECT_ISSUER_ID" \
		--wait
	cleanup_notary_materials
	trap - EXIT INT HUP TERM

	echo "ci_post_xcodebuild: stapling $app"
	xcrun stapler staple "$app"
	xcrun stapler validate "$app"
	echo "ci_post_xcodebuild: notarized and stapled $app"
}

if [ -n "$TAG" ]; then
	notarize_and_staple "$APP_PATH"
	ZIP_NAME="${PRODUCT_NAME}-${TAG}.zip"
else
	ZIP_NAME="${PRODUCT_NAME}-macos-arm64.zip"
fi
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "ci_post_xcodebuild: wrote $ZIP_PATH"
echo "ci_post_xcodebuild: TODO: DMG packaging is not implemented; zip is the GitHub Release artifact."

TOKEN=${GITHUB_TOKEN:-${GH_TOKEN:-}}
if [ -z "$TOKEN" ]; then
	skip "GITHUB_TOKEN / GH_TOKEN unset; skipping GitHub Release upload. Attach $ZIP_PATH to the GitHub Release by hand (docs/release.md)."
fi

if [ -z "$TAG" ]; then
	skip "no CI_GIT_TAG / CI_TAG / refs/tags CI_GIT_REF; skipping GitHub Release upload. Token is set but this Archive was not tag-triggered."
fi

upload_with_gh() {
	if ! command -v gh >/dev/null 2>&1; then
		return 1
	fi
	if ! GH_TOKEN=$TOKEN gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
		GH_TOKEN=$TOKEN gh release create "$TAG" --repo "$GITHUB_REPO" --title "$TAG" --generate-notes
	fi
	GH_TOKEN=$TOKEN gh release upload "$TAG" "$ZIP_PATH" --repo "$GITHUB_REPO" --clobber
}

upload_with_api() {
	if ! command -v python3 >/dev/null 2>&1; then
		echo "ci_post_xcodebuild: python3 not found; cannot upload via GitHub API." >&2
		return 1
	fi
	GITHUB_TOKEN=$TOKEN GITHUB_REPO=$GITHUB_REPO TAG=$TAG ZIP_PATH=$ZIP_PATH ZIP_NAME=$ZIP_NAME python3 - <<'PY'
import json, os, urllib.error, urllib.parse, urllib.request

token = os.environ["GITHUB_TOKEN"]
repo = os.environ["GITHUB_REPO"]
tag = os.environ["TAG"]
zip_path = os.environ["ZIP_PATH"]
zip_name = os.environ["ZIP_NAME"]
api = "https://api.github.com"
headers = {
    "Authorization": "Bearer " + token,
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "eloquent-xcode-cloud",
}

def request(method, url, data=None, extra_headers=None, raw=False, ok=(200, 201, 204)):
    body = data if raw else (None if data is None else json.dumps(data).encode())
    req = urllib.request.Request(url, data=body, method=method)
    for key, value in headers.items():
        req.add_header(key, value)
    if extra_headers:
        for key, value in extra_headers.items():
            req.add_header(key, value)
    elif not raw and data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as response:
            payload = response.read()
            parsed = json.loads(payload) if payload else {}
            return response.status, parsed
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        if exc.code not in ok:
            raise SystemExit(f"GitHub API {method} {url} failed ({exc.code}): {detail}") from exc
        parsed = json.loads(detail) if detail else {}
        return exc.code, parsed

status, release = request(
    "GET",
    f"{api}/repos/{repo}/releases/tags/{urllib.parse.quote(tag)}",
    ok=(200, 404),
)
if status == 404:
    _, release = request(
        "POST",
        f"{api}/repos/{repo}/releases",
        {"tag_name": tag, "name": tag, "generate_release_notes": True},
        ok=(201,),
    )

release_id = release.get("id")
if not release_id:
    raise SystemExit("GitHub API returned a release payload without id")

for asset in release.get("assets", []):
    if asset.get("name") == zip_name:
        request("DELETE", f"{api}/repos/{repo}/releases/assets/{asset['id']}", ok=(204,))
        break

with open(zip_path, "rb") as handle:
    blob = handle.read()
upload_url = (
    f"https://uploads.github.com/repos/{repo}/releases/{release_id}/assets?"
    + urllib.parse.urlencode({"name": zip_name})
)
request("POST", upload_url, blob, extra_headers={"Content-Type": "application/zip"}, raw=True, ok=(201,))
print(f"uploaded {zip_name} to {repo} release {tag}")
PY
}

if upload_with_gh; then
	echo "ci_post_xcodebuild: uploaded $ZIP_NAME to GitHub Release $TAG ($GITHUB_REPO) via gh."
elif upload_with_api; then
	echo "ci_post_xcodebuild: uploaded $ZIP_NAME to GitHub Release $TAG ($GITHUB_REPO) via API."
else
	echo "ci_post_xcodebuild: GitHub Release upload failed." >&2
	exit 1
fi
