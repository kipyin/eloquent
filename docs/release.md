# Release: Developer ID, notarization, GitHub Releases

Public distribution is a **Developer ID** signed, **notarized** `.app` on a GitHub Release. This repo scaffolds that path. It does not ship a Team ID, a `.p12`, or Apple API keys.

Until the first `v*` tag produces an artifact, there is no public download. Local `CONFIG=Release make run` remains the way to run a build from a clone ([README Install](../README.md#install)). Homebrew is later, after that first Release exists.

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
     - `DEVELOPMENT_TEAM` = your Team ID. `ci_pre_xcodebuild.sh` writes `Config/Release-Signing.xcconfig` from this on Archive only. It does not print the value.
     - `GITHUB_TOKEN` or `GH_TOKEN` (mark **Secret**) = a GitHub PAT or fine-grained token with **Contents: Read and write** on `kipyin/eloquent`, so the post script can attach the zip. Omit this until you want automatic upload; the script then zips and logs that upload was skipped.
3. **Start Conditions**
   - Remove **Branch Changes** if this workflow should not run on every push.
   - **+** → **Tag Changes**. Restrict to tags matching `v*` (the control is labelled **Tag** / **Tags** and accepts a glob such as `v*`).
4. **Actions**
   - **+** → **Archive**.
   - Platform: **macOS**. Scheme: **Eloquent**.
   - Signing / deployment preparation: **Developer ID** (Xcode Cloud may say **Direct Distribution**). Not App Store, not TestFlight.
   - Optional: a **Test** action before Archive. The existing Build + Test workflow already covers PRs and `main`.
5. **Post-Actions** (on the Archive action)
   - **+** → **Notarize**. That is the macOS notarize post-action. It is what populates `CI_DEVELOPER_ID_SIGNED_APP_PATH` and submits to Apple’s notary service.
6. **Signing certificates**: Xcode Cloud → Settings (or the workflow’s signing section) → create or upload **Developer ID Application** for this team. Cloud can create it when the account role allows.
7. Save.

`ci_scripts/ci_post_xcodebuild.sh` runs after `xcodebuild`. On a successful Archive (`CI_ARCHIVE_PATH` set, exit code 0) it zips the Developer ID app. If `CI_DEVELOPER_ID_SIGNED_APP_PATH` is missing, it exports with `ExportOptions-DeveloperID.plist`. GitHub upload uses `GITHUB_TOKEN` / `GH_TOKEN` and skips when the token is missing.

Xcode Cloud still has no hook *after* the Notarize post-action. If Gatekeeper rejects the zip the script uploaded, download **Download Notarized App** from that build in App Store Connect / Xcode and attach that zip to the GitHub Release instead.

### 5. First GitHub Release

1. Marketing version is `MARKETING_VERSION` / `CFBundleShortVersionString` (today `1.0.0`). Bump it in `project.yml`, `Eloquent.xcodeproj`, and `Eloquent/Info.plist` when you intend a new version.
2. Tag and push:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Wait for the **Release** workflow. Confirm Archive and Notarize succeeded.
4. GitHub → **Releases** → the `v1.0.0` release (created by the post script if the token was set, or **Draft a new release** yourself). Attach `Eloquent-v1.0.0.zip` if it is not already there.
5. Spot-check on a Mac that is not your build machine: unzip, move `Eloquent.app` to `/Applications`, open it. Gatekeeper should accept a stapled notarized build.

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
```

Store notary credentials with `xcrun notarytool store-credentials`. Do not put an app-specific password in the repo.

`make test` is unchanged: Debug, ad-hoc unless `DEVELOPMENT_TEAM` is set, same timeouts as today.
