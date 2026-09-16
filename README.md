# Eloquent

Native macOS menu-bar TTS. Product name: **Eloquent**. Repo: [github.com/kipyin/eloquent](https://github.com/kipyin/eloquent). On Ark: `~/Code/eloquent`.

Option+Escape (`⌥⎋`) reads the current clipboard, sends it to an OpenAI-compatible TTS endpoint, and plays the returned audio. The speaker icon stays in the menu bar at all times. A floating panel (previous / pause / stop / next) appears only while speaking and hides when idle or stopped. This is not Moshi and is not a Moshi fork.

Product lock: [SPEC.md](SPEC.md). Acceptance: [HANDOFF.md](HANDOFF.md).

## Requirements

- Apple Silicon Mac
- macOS 14+
- Xcode 15.4+ (Xcode 16 is fine)
- Local checkout: `~/Code/eloquent`
- Local OpenAI-compatible TTS proxy at `http://127.0.0.1:8787/v1` (on Ark: `~/Code/xai-openai-tts-proxy`)

## Open in Xcode

```bash
open Eloquent.xcodeproj
```

Select the **Eloquent** scheme, destination **My Mac**, then Run (`⌘R`).

The app is an `LSUIElement` accessory: it does not appear in the Dock. The speaker icon is **always on** in the menu bar for the life of the app. The floating control panel appears only while speaking (loading / playing / paused) and is hidden when idle or after Stop.

## Build from the command line

```bash
xcodebuild -project Eloquent.xcodeproj -scheme Eloquent -configuration Release -arch arm64 -derivedDataPath build build
open build/Build/Products/Release/Eloquent.app
```

Or `make run` (Debug) / `CONFIG=Release make run`.

The project is ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`) so it runs locally without a Development Team. App Sandbox is off so localhost HTTP, clipboard, Keychain, and the global hotkey work as a local utility.

`project.yml` is optional. If you install [XcodeGen](https://github.com/yonaskolb/XcodeGen), `xcodegen generate` can regenerate the `.xcodeproj`.

## Settings defaults

| Field | Default |
| --- | --- |
| Engine | `openai` |
| Endpoint | `http://127.0.0.1:8787/v1` |
| API key | empty (the proxy holds the upstream key) |
| Model | `grok-tts` |
| Voice | `carina` |
| Speed | `1.1` (clamped 0.7–1.5) |
| Paragraph split | Blank lines when present, otherwise every newline |
| Open at Login | Off (optional; not registered until the user enables it) |

Engine / Endpoint / Model / Voice / Speed / Paragraph split persist in UserDefaults. The API key persists in Keychain (`com.kipyin.eloquent`). Open at Login is a macOS Login Item via `SMAppService.mainApp` (not UserDefaults). Do not paste a real xAI key into this repo.

**Paragraph split** controls how prev/next walks the clipboard:

1. **Blank lines only** — split on double newlines; single line breaks stay in one paragraph.
2. **Every newline** — each newline is a paragraph.
3. **Blank lines, else every newline** — default. Use blank lines when they exist; otherwise split on every newline.
4. **Sentences** — split on `. ! ? 。 ！ ？` (and fullwidth/ellipsis variants). Prev/next is per sentence.

The JSON body is `{ model, voice, input, speed, response_format: "mp3" }` posted to `{endpoint}/audio/speech`. `language` is omitted so the proxy’s zh/en heuristic runs. `ja` and `auto` are never sent. If an API key is set, it is sent as `Authorization: Bearer …`.

## Accessibility (required for global ⌥⎋)

Eloquent prompts on **first launch** to grant Accessibility so Option+Escape works in every app. You can also grant later from the menu bar (**Grant Accessibility…**) or **Settings → Hotkey**.

1. When the alert appears, click **Grant Accessibility**.
2. System Settings → **Privacy & Security → Accessibility**.
3. Enable **Eloquent**. If you launched from Xcode, enable **Xcode** (or the `Eloquent.app` product you ran).
4. **Quit Eloquent** from the menu bar and reopen it. macOS only applies Accessibility to a process after relaunch.

The same path without the prompt:

- System Settings → Privacy & Security → Accessibility → enable Eloquent → quit and reopen.

Input Monitoring is not required.

If `⌥⎋` still does nothing after a relaunch, confirm Eloquent (not only Xcode) is enabled, then try **Speak Clipboard** from the menu bar to separate hotkey issues from TTS.

## Verify on Ark with the loopback proxy

1. Confirm the proxy is up: `curl -sS http://127.0.0.1:8787/v1/models` should mention `grok-tts`.
2. Launch Eloquent. Confirm the **always-on** menu-bar speaker icon (no Dock icon). The floating panel must **not** be visible yet. Grant Accessibility when prompted (or via **Grant Accessibility…**), then quit and reopen.
3. Open **Settings…**. Confirm the defaults in the table above. Leave API key empty. Confirm **Open at Login** is off.
4. Copy a short English sentence. Press **Option+Escape**. Audio should play. The floating panel should appear with previous / pause / stop / next.
5. Press **Stop** (or let the last paragraph finish). The panel must hide. The menu-bar icon must remain.
6. Copy a Chinese paragraph (or mixed zh/en). Press Option+Escape again. Language must still work without sending `ja` or `auto`.
7. In Settings, switch **Paragraph split** across all four modes. Copy matching sample text (blank lines, one-line-per-paragraph, and multi-sentence prose) and confirm prev/next follows the selected mode.
8. **Pause** should freeze audio and keep the panel up; **Stop** should dismiss the panel.
9. Empty the clipboard and press Option+Escape. The menu bar can show “Clipboard is empty.” The floating panel must stay hidden.
10. Optional: enable **Open at Login**, log out/in, and confirm the menu-bar extra comes back. If macOS asks, allow it under System Settings → General → Login Items & Extensions. Leave it off if you do not want it.

## Layout

```
Eloquent.xcodeproj      Xcode project + shared scheme
Eloquent/               app sources, Info.plist, entitlements
project.yml                 optional XcodeGen spec
Makefile                    xcodebuild helpers
SPEC.md                     product lock
HANDOFF.md                  acceptance checklist
```
