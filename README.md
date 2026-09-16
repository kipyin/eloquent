# Eloquent

Native macOS menu-bar TTS. Option+Escape (`⌥⎋`) reads the clipboard, sends it to an OpenAI-compatible TTS endpoint, and plays the audio.

The speaker icon stays in the menu bar. A floating panel (previous / pause / stop / next) appears only while speaking and hides when idle or stopped.

Repo: [github.com/kipyin/eloquent](https://github.com/kipyin/eloquent). This is not Moshi and is not a Moshi fork.

Product lock: [SPEC.md](SPEC.md). Acceptance: [HANDOFF.md](HANDOFF.md).

## Requirements

- Apple Silicon Mac
- macOS 14+
- Xcode 15.4+ (Xcode 16 is fine)
- An OpenAI-compatible TTS provider. Set **Endpoint** (the `/v1` base URL) and an API key in Settings before speaking.

## Open in Xcode

```bash
open Eloquent.xcodeproj
```

Select the **Eloquent** scheme, destination **My Mac**, then Run (`⌘R`).

The app is an `LSUIElement` accessory: it does not appear in the Dock. The speaker icon stays in the menu bar for the life of the app. The floating control panel appears only while speaking (loading / playing / paused) and is hidden when idle or after Stop.

## Build from the command line

```bash
xcodebuild -project Eloquent.xcodeproj -scheme Eloquent -configuration Release -arch arm64 -derivedDataPath build build
open build/Build/Products/Release/Eloquent.app
```

Or `make run` (Debug) / `CONFIG=Release make run`.

The project is ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`) so it runs locally without a Development Team. App Sandbox is off so network, clipboard, Keychain, and the global hotkey work as a local utility.

`project.yml` is optional. If you install [XcodeGen](https://github.com/yonaskolb/XcodeGen), `xcodegen generate` can regenerate the `.xcodeproj`.

## Settings

Configure **Endpoint** and **API key** for your provider. Speak fails with a clear error if Endpoint is empty.

| Field | Default |
| --- | --- |
| Engine | `openai` |
| Endpoint | empty (required) |
| API key | empty (Keychain) |
| Model | `tts-1` |
| Voice | `alloy` |
| Speed | `1.1` (clamped 0.7–1.5) |
| Paragraph split | Blank lines when present, otherwise every newline |
| Open at Login | Off (optional; not registered until the user enables it) |

Engine / Endpoint / Model / Voice / Speed / Paragraph split persist in UserDefaults. The API key persists in Keychain (`com.kipyin.eloquent`). Open at Login is a macOS Login Item via `SMAppService.mainApp` (not UserDefaults). Never commit API keys.

**Paragraph split** controls how prev/next walks the clipboard:

1. **Blank lines only** — split on double newlines; single line breaks stay in one paragraph.
2. **Every newline** — each newline is a paragraph.
3. **Blank lines, else every newline** — default. Use blank lines when they exist; otherwise split on every newline.
4. **Sentences** — split on `. ! ? 。 ！ ？` (and fullwidth/ellipsis variants). Prev/next is per sentence.

Any OpenAI-compatible `POST {endpoint}/audio/speech` works. The JSON body is `{ model, voice, input, speed, response_format: "mp3" }`. The client omits `language`; providers may apply their own heuristics. `ja` and `auto` are never sent. If an API key is set, it is sent as `Authorization: Bearer …`.

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

## Try it

1. Launch Eloquent. Confirm the always-on menu-bar speaker icon (no Dock icon). The floating panel should not be visible yet.
2. Grant Accessibility when prompted, then quit and reopen.
3. Open **Settings…**. Set Endpoint to your provider’s OpenAI-compatible `/v1` base and paste an API key. Leave Open at Login off unless you want it.
4. Copy a short sentence. Press **Option+Escape**. Audio should play. The floating panel should appear with previous / pause / stop / next.
5. Press **Stop** (or let the last paragraph finish). The panel must hide. The menu-bar icon must remain.
6. Empty the clipboard and press Option+Escape. The menu bar can show “Clipboard is empty.” The floating panel must stay hidden.
7. Clear Endpoint and speak. The menu bar should tell you to set Endpoint. The app must not crash.

## Layout

```
Eloquent.xcodeproj      Xcode project + shared scheme
Eloquent/               app sources, Info.plist, entitlements
project.yml             optional XcodeGen spec
Makefile                xcodebuild helpers
SPEC.md                 product lock
HANDOFF.md              acceptance checklist
LICENSE                 MIT
```
