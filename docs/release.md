# Release: Developer ID, notarization, GitHub Releases

Public distribution is a **Developer ID** signed, **notarized and stapled** `.app` on a GitHub Release. This repo scaffolds that path. It does not ship a Team ID, a `.p12`, or Apple API keys.

Xcode Cloud’s **Notarize** post-action is what produces the Developer ID Managed export. When that post-action is on the Archive workflow, Cloud sets `CI_DEVELOPER_ID_SIGNED_APP_PATH` before `ci_post_xcodebuild.sh`. Build 6 used that app for the GitHub zip. Keep Notarize. The post script copies that app, then notarizes, staples, zips, and uploads it. Notarize itself is not the GitHub upload, and the build page still has a notarized app to download by hand. If `CI_DEVELOPER_ID_SIGNED_APP_PATH` is missing or empty, `ci_post` codesigns the archived `.app` instead (local, or a workflow without Notarize).

Published GitHub Releases use SemVer tags `vX.Y.Z` (latest `v0.1.5`, asset `Eloquent-v0.1.5.zip`). Local `CONFIG=Release make run` remains the way to run a build from a clone ([README Install](../README.md#install)). Homebrew is later.

## Checklist

### 1. Apple team and Developer ID certificate

1. Enroll the Apple Developer Program for the team that will sign Eloquent (`com.kipyin.eloquent`).
2. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list): confirm an App ID for `com.kipyin.eloquent` (register one if it is missing).
3. Note the **Team ID** from [Membership details](https://developer.apple.com/account). Do not commit it.
4. Create a **Developer ID Application** certificate if the team does not already have one:
   - Xcode → Settings → Accounts → select the team → **Manage Certificates…** → **+** → **Developer ID Application**, or
   - Developer portal → Certificates → **+** → **Developer ID Application**.
5. Never add a `.p12`, `.p8`, or App Store Connect API key to git. `*.p12` and `AuthKey_*.p8` are gitignored.

### 2. Signing in this repo (no secrets committed)

Committed Release settings do **not** pin a team. `DEVELOPMENT_TEAM` comes from the environment, Xcode Cloud, or a gitignored overlay.

Local overlay:

```bash
cp Config/Release-Signing.xcconfig.example Config/Release-Signing.xcconfig
```

Replace `YOUR_TEAM_ID` in that copy. The file is gitignored. Alternatively:

```bash
export DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

Then `make archive` / `make release-zip` pass `Developer ID Application` into xcodebuild. `make build`, `make test`, and `make run` still use Apple Development when `DEVELOPMENT_TEAM` is set, and ad-hoc (`CODE_SIGN_IDENTITY=-`) when it is not.

Release itself enables **Hardened Runtime** (`Config/Release.xcconfig`). Notarization requires that.

### 3. App Store Connect record (once)

Xcode Cloud hangs off an App Store Connect app, even when you never ship on the Mac App Store.

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
2. Platform: **macOS**. Bundle ID: `com.kipyin.eloquent`. Fill in the rest of the form.
3. You do not need App Store pricing, review, or a Mac App Store build.
4. Create an App Store Connect API key for `notarytool` (once): **Users and Access** → **Integrations** → **App Store Connect API** → **Generate API Key**. Role: **Developer** or higher. Download the `.p8` once. Put Key ID, Issuer ID, and the full PEM into the three `APP_STORE_CONNECT_*` Xcode Cloud Secrets in step 4. Do not commit them.

### 4. Xcode Cloud Release workflow (UI — this is not in git)

Keep the existing **Build + Test** workflow. Add a second workflow for tags.

**Create the workflow**

1. Xcode: **Product → Xcode Cloud → Create Workflow…** (or open the app in App Store Connect → **Xcode Cloud** → **Manage Workflows** → **+**).
2. Product / app: the macOS Eloquent record from step 3. Scheme: **Eloquent**.
3. If Xcode Cloud asks to connect GitHub (`kipyin/eloquent`), grant access.

**Edit the new workflow** (pencil / **Edit Workflow**)

1. Name it **Release** (or **Notarized Release**).
2. **Environment**
   - Xcode: Latest Release (or the version you already use for Test).
   - macOS: Latest Release.
   - Environment variables:
     - `DEVELOPMENT_TEAM` = your Team ID. `ci_pre_xcodebuild.sh` writes `Config/Release-Signing.xcconfig` from this on Archive only. It does not print the value. The Cloud path does not codesign with it: `ci_post` copies `CI_DEVELOPER_ID_SIGNED_APP_PATH`. The codesign fallback (that variable missing or empty) uses it to choose a `Developer ID Application: … (TEAM)` identity and does not print it. If that fallback finds no identity, the log includes a redacted `security find-identity -v -p codesigning` listing (`(TEAMID)` shown as `([team])`).
     - `GITHUB_TOKEN` or `GH_TOKEN` (mark **Secret**) = a GitHub PAT or fine-grained token with **Contents: Read and write** on `kipyin/eloquent`, so the post script can attach the zip. Omit this until you want automatic upload; the script then notarizes, zips, and logs that upload was skipped.
     - `APP_STORE_CONNECT_KEY_ID` (mark **Secret**) = Key ID of an App Store Connect API key (role **Developer** or higher) used by `notarytool`. Paste the key id only. The script trims surrounding whitespace and newlines before `notarytool` and does not print the value.
     - `APP_STORE_CONNECT_ISSUER_ID` (mark **Secret**) = Issuer ID from App Store Connect → Users and Access → Integrations → App Store Connect API. Paste the UUID only. The script trims surrounding whitespace and newlines before `notarytool` (a trailing newline from the secret field makes `notarytool` reject `--issuer`, exit 64) and fails the build if the result is not a UUID. It does not print the value.
     - `APP_STORE_CONNECT_API_KEY_P8` (mark **Secret**) = full PEM text of that key’s `.p8` (including the `BEGIN` / `END` lines). The script writes it to a temp file mode `600` and deletes it after `notarytool`. If the Cloud UI flattens the secret to one line, keep `\n` between PEM lines; the script expands them. Whitespace surrounding the PEM is trimmed; the PEM body is kept. Never commit the `.p8` (`AuthKey_*.p8` is gitignored).
     - On a tag Archive, missing ASC secrets **fail the build** so an unnotarized zip is never uploaded.
3. **Start Conditions**
   - Remove **Branch Changes** if this workflow should not run on every push.
   - **+** → **Tag Changes**. Restrict to tags matching `v*` (the control is labelled **Tag** / **Tags** and accepts a glob such as `v*`).
4. **Actions**
   - **+** → **Archive**.
   - Platform: **macOS**. Scheme: **Eloquent**.
   - **Distribution Preparation: None** (the control may be labelled **Deployment Preparation**) ad-hoc-signs the archive. Cloud runs `xcodebuild` with `CODE_SIGN_IDENTITY=-` and `AD_HOC_CODE_SIGNING_ALLOWED=YES` even when `Config/Release-Signing.xcconfig` says `Developer ID Application`. The log shows **Sign to Run Locally**. With the Notarize post-action configured, Cloud still runs a Developer ID Managed export and sets `CI_DEVELOPER_ID_SIGNED_APP_PATH` (Build 6 and Build 12). It also exports `CI_DEVELOPMENT_SIGNED_APP_PATH` and `CI_APP_STORE_SIGNED_APP_PATH`.
   - Leave TestFlight and App Store off this workflow.
   - Optional: a **Test** action before Archive. The existing Build + Test workflow already covers PRs and `main`.
5. **Post-Actions** (on the Archive action)
   - **+** → **Notarize**. Keep it. Notarize runs after `ci_post_xcodebuild.sh` for Apple's notarization pass, and when it is configured Cloud sets `CI_DEVELOPER_ID_SIGNED_APP_PATH` for that script from the Developer ID Managed export. Build 6 uploaded the GitHub zip from that path. The build page's notarized app remains available to download by hand.
6. **Signing certificates**: Xcode Cloud → Settings (or the workflow’s signing section) → create or upload **Developer ID Application** for this team. Cloud can create a Managed certificate when the account role allows. That export is what sets `CI_DEVELOPER_ID_SIGNED_APP_PATH`. The codesign fallback runs only when that variable is missing or empty, and it fails the build when no matching keychain identity exists.
7. Save.

**Required environment** (Release workflow; do not commit any of these):

| Variable | Role |
| --- | --- |
| `DEVELOPMENT_TEAM` | Team ID. Used by the codesign fallback to select `Developer ID Application: … (TEAM)`. The Managed path uses `CI_DEVELOPER_ID_SIGNED_APP_PATH` instead. Not printed. |
| `APP_STORE_CONNECT_KEY_ID` | Secret. `notarytool` key id only. Trailing newlines are trimmed. Tag Archives fail closed if missing. |
| `APP_STORE_CONNECT_ISSUER_ID` | Secret. `notarytool` issuer UUID only. Trailing newlines are trimmed. Tag Archives fail closed if missing or the value is not a UUID. |
| `APP_STORE_CONNECT_API_KEY_P8` | Secret. Full `.p8` PEM. Tag Archives fail closed if missing. |
| `GITHUB_TOKEN` or `GH_TOKEN` | Secret. Contents read/write on `kipyin/eloquent`. Omit to skip upload. |

Xcode Cloud's `xcodebuild archive` command line sets `CODE_SIGN_IDENTITY=-` and `AD_HOC_CODE_SIGNING_ALLOWED=YES`. Command-line build settings outrank `Config/Release-Signing.xcconfig` and the Xcode project, so the overlay's `CODE_SIGN_IDENTITY` is ignored. The archived `.app` is **Sign to Run Locally** and has no team. `xcodebuild -exportArchive` then fails: `exportArchive No Team Found in Archive`. Putting `teamID` in an export options plist does not fix an ad-hoc archive. `ci_post` does not call `exportArchive`.

`ci_scripts/ci_post_xcodebuild.sh` runs after `xcodebuild`. Cloud sets `CI_DEVELOPER_ID_SIGNED_APP_PATH` for that script when the Notarize post-action is configured, including on Build 6, which uploaded the GitHub zip from it. On a successful Archive (`CI_ARCHIVE_PATH` set, exit code 0):

1. If `CI_DEVELOPER_ID_SIGNED_APP_PATH` is set and contains `Eloquent.app`, copy that Developer ID Managed app. Do not codesign it again.
2. If that variable is missing or empty, `codesign --force --sign` the archived app (or `CI_DEVELOPMENT_SIGNED_APP_PATH` if the archive product is missing) with the `Developer ID Application: … (DEVELOPMENT_TEAM)` identity, `--options runtime --timestamp`, and the app's entitlements. The identity name is not printed. If no identity matches, the build fails and the log includes a redacted `security find-identity -v -p codesigning` listing (certificate names stay, team ids are `([team])`).
3. On a tag-triggered Archive (`CI_TAG`, `CI_GIT_TAG`, or `CI_GIT_REF=refs/tags/…`): `xcrun notarytool submit --wait` with the three ASC secrets, then `xcrun stapler staple` the `.app`. Key id and issuer are trimmed of surrounding whitespace and newlines before submit. Missing secrets, or an issuer that is not a UUID after trimming, fail the build.
4. Zip the stapled `.app` (`ditto`; stapler cannot staple a zip).
5. Create or update the GitHub Release for that tag and upload the zip (`GITHUB_TOKEN` / `GH_TOKEN`). Upload skips when the token is missing.

### 5. Version and GitHub Release

The public version scheme is SemVer `0.1.x`. Git tags look like `v0.1.5`. The marketing version is the same numbers without the leading `v`.

`MARKETING_VERSION` in `project.yml` is the source of truth. It is set on the Eloquent target and the EloquentTests target. The About panel reads `CFBundleShortVersionString` from `Eloquent/Info.plist`. `GENERATE_INFOPLIST_FILE` is NO, so that plist string is what ships. XcodeGen can regenerate `Eloquent.xcodeproj` from `project.yml`; it does not rewrite `Info.plist`. The Makefile builds the committed Xcode project and does not run XcodeGen.

Before tagging `vX.Y.Z`, set `MARKETING_VERSION` to `X.Y.Z` in `project.yml` (and regenerate `Eloquent.xcodeproj` if you use XcodeGen, or set the same `MARKETING_VERSION` on the Eloquent and EloquentTests configurations in the committed project). Set `CFBundleShortVersionString` in `Eloquent/Info.plist` to the same `X.Y.Z`. Tags and the marketing version must stay in lockstep. Commit those edits, then tag that commit:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

`CURRENT_PROJECT_VERSION` (`CFBundleVersion` in `Eloquent/Info.plist`) is the build number. It is a simple integer, independent of the marketing version and the git tag. It stays `1` until a build-number bump is needed. A marketing-version change does not require a build-number change.

The marketing version on `main` is `0.1.5`, matching tag `v0.1.5` and asset `Eloquent-v0.1.5.zip`.

1. Wait for the **Release** workflow. In Cloud logs, confirm `ci_post_xcodebuild` submitted to notarytool, stapled, and uploaded. Cloud’s Notarize post-action can still succeed afterward; it is not the GitHub upload.
2. GitHub → **Releases** → the `vX.Y.Z` release (created by the post script if the token was set, or **Draft a new release** yourself). Attach `Eloquent-vX.Y.Z.zip` if it is not already there. The post script names a tag zip `Eloquent-<tag>.zip`.
3. Spot-check on a Mac that is not your build machine: unzip, move `Eloquent.app` to `/Applications`, then:

   ```bash
   spctl --assess --verbose --type execute /Applications/Eloquent.app
   ```

   Expect `accepted` / `Notarized Developer ID`. `Unnotarized Developer ID` means the zip was signed but not stapled — do not ship it.

There is no DMG yet. The zip is the artifact. A disk image can wait until this path is boring.

### 6. Homebrew (later)

After a notarized GitHub Release exists, add a **personal tap** (a cask that fetches that Release asset). Do not publish a `brew install` line in the README until that tap is real.

## Local commands

```bash
export DEVELOPMENT_TEAM=YOUR_TEAM_ID   # or the gitignored xcconfig
make archive                           # build/Eloquent.xcarchive
make release-zip                       # export + zip (not notarized)
```

Notarize a local zip when you want to skip Cloud for a one-off:

```bash
xcrun notarytool submit build/Eloquent.zip --keychain-profile YOUR_NOTARY_PROFILE --wait
xcrun stapler staple build/export/Eloquent.app
ditto -c -k --keepParent build/export/Eloquent.app build/Eloquent.zip
```

Store notary credentials with `xcrun notarytool store-credentials`. Do not put an app-specific password or `.p8` in the repo. Cloud tag Archives use `APP_STORE_CONNECT_*` secrets instead of a keychain profile.

`make test` is unchanged: Debug, ad-hoc unless `DEVELOPMENT_TEAM` is set, same timeouts as today.
