# Eloquent

Native macOS menu-bar app. The speak hotkey reads the current selection — or the clipboard when nothing is selected — and speaks it through OpenAI-compatible or Grok (xAI) TTS.

## What it does

- Configurable global speak hotkey (default Option+Escape, `⌥⎋`) reads the selected text, or the clipboard when nothing is selected, and plays speech
- Speaker icon stays in the menu bar
- Floating previous / pause / stop / next / speed panel appears only while speaking
- Settings: Engine, Endpoint, API key, Model, Voice, Speed, Speed apply, Paragraph split, Speak hotkey, Open at Login

## Text source: selection first, clipboard fallback

Speaking prefers the live text selection in the frontmost app, read through the same Accessibility permission the hotkey uses. When nothing is selected or the app does not expose its selection, Eloquent speaks the clipboard instead. If both are empty, it fails with a transient error and the floating panel stays hidden.

The selection cannot be read everywhere; in these cases Eloquent silently falls back to the clipboard:

- Accessibility permission not granted (System Settings → Privacy & Security → Accessibility)
- Apps that do not expose selected text to Accessibility — some terminals, canvas-rendered editors, and custom text controls
- Secure text fields (passwords), which never expose their contents
- No focused text element (for example the selection sits in a dialog that lost focus)

## Install

**Today:** a **Release** `.app` you build from a clone. Requires macOS 14+, Apple Silicon, and a full Xcode 15.4+ install. Command Line Tools alone is not enough.

```bash
git clone https://github.com/kipyin/eloquent.git
cd eloquent
CONFIG=Release make run
```

That builds `build/Build/Products/Release/Eloquent.app` and opens it. Copy that `.app` somewhere stable (for example `/Applications`) if you want to keep using it after you leave the clone.

**GitHub Releases (notarized):** a Developer ID signed, notarized zip. Latest tag `v0.1.5`, asset `Eloquent-v0.1.5.zip`. How a tag stays in lockstep with the marketing version: [docs/release.md](docs/release.md). Publishing the release bumps the `eloquent` cask in [`kipyin/homebrew-tap`](https://github.com/kipyin/homebrew-tap). That job needs the repo secret `HOMEBREW_TAP_TOKEN`.

### First run

1. Grant **Accessibility** when prompted so the global speak hotkey and selection reading work in every app. System Settings → Privacy & Security → Accessibility → enable Eloquent, then quit from the menu bar and reopen.
2. Open Settings. Pick an **Engine**, then set **Endpoint** (the `/v1` base URL) and an API key.

### Signing and Accessibility after rebuilds

Local Makefile builds are ad-hoc unless you set `DEVELOPMENT_TEAM` (Apple Development — a local identity, not Developer ID). After a rebuild, System Settings may still show Accessibility “on” for an old binary while the running one is untrusted. Remove Eloquent from the Accessibility list, add the current `.app`, grant it, then quit and reopen.

Public distribution is Developer ID + notarization, not this local identity. See [docs/release.md](docs/release.md).

### If `xcodebuild` fails with Command Line Tools

`xcodebuild` needs a full `Xcode.app` or `Xcode-beta.app`. Point it at the Xcode you actually have:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

or:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

Use your machine’s real Xcode path. Command Line Tools alone is not enough.

## Develop

```bash
make build          # Debug
make test
make run            # Debug, then open the .app
open Eloquent.xcodeproj
```

Optional: set `DEVELOPMENT_TEAM` in your shell so the Makefile signs with your Apple Development certificate. That stops macOS Keychain from re-prompting after every rebuild. It is not a committed repo default.

`Eloquent/` is the app. `Eloquent.xcodeproj` is the Xcode project; `project.yml` can regenerate it with XcodeGen. `Makefile` wraps xcodebuild. `make archive` / `make release-zip` need a Developer ID identity — [docs/release.md](docs/release.md).

## Distribution

**Today:** source plus a local Release build, as in [Install](#install).

**Public download:** Developer ID + notarization → GitHub Releases (latest `v0.1.5`). Follow [docs/release.md](docs/release.md).

**Homebrew:** the `eloquent` cask in `kipyin/homebrew-tap` tracks that Release. Sparkle auto-update is separate.
