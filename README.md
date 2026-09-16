# clipboard-tts

Native macOS menu-bar app. Display name: **Clipboard TTS**.

Option+Escape (`⌥⎋`) reads the current clipboard, sends it to an OpenAI-compatible TTS endpoint, and plays the returned audio. A floating panel exposes previous paragraph, pause, stop, and next paragraph. This is not Moshi and is not a Moshi fork.

Product lock: [SPEC.md](SPEC.md). Acceptance: [HANDOFF.md](HANDOFF.md).

## Requirements

- Apple Silicon Mac
- macOS 14+
- Xcode 15.4+ (Xcode 16 is fine)
- Local OpenAI-compatible TTS proxy at `http://127.0.0.1:8787/v1` (on Ark: `~/Code/xai-openai-tts-proxy`)

## Open in Xcode

```bash
open ClipboardTTS.xcodeproj
```

Select the **ClipboardTTS** scheme, destination **My Mac**, then Run (`⌘R`).

The app is an `LSUIElement` accessory: it does not appear in the Dock. Look for the speaker icon in the menu bar.

## Build from the command line

```bash
xcodebuild -project ClipboardTTS.xcodeproj -scheme ClipboardTTS -configuration Release -arch arm64 -derivedDataPath build build
open build/Build/Products/Release/ClipboardTTS.app
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

Engine / Endpoint / Model / Voice / Speed / Paragraph split persist in UserDefaults. The API key persists in Keychain (`com.kipyin.clipboard-tts`). Do not paste a real xAI key into this repo.

**Paragraph split** controls how prev/next walks the clipboard:

1. **Blank lines only** — split on double newlines; single line breaks stay in one paragraph.
2. **Every newline** — each newline is a paragraph.
3. **Blank lines, else every newline** — default. Use blank lines when they exist; otherwise split on every newline.
4. **Sentences** — split on `. ! ? 。 ！ ？` (and fullwidth/ellipsis variants). Prev/next is per sentence.

The JSON body is `{ model, voice, input, speed, response_format: "mp3" }` posted to `{endpoint}/audio/speech`. `language` is omitted so the proxy’s zh/en heuristic runs. `ja` and `auto` are never sent. If an API key is set, it is sent as `Authorization: Bearer …`.

## Accessibility

The global hotkey uses Carbon `RegisterEventHotKey` for Option+Escape. That usually works **without** Accessibility or Input Monitoring.

If `⌥⎋` does nothing:

1. System Settings → Privacy & Security → Accessibility
2. Enable **Clipboard TTS** (or Xcode / `ClipboardTTS.app` if you launched from Xcode)
3. Quit and reopen the app, then try again

You should not need Input Monitoring for this hotkey.

## Verify on Ark with the loopback proxy

1. Confirm the proxy is up: `curl -sS http://127.0.0.1:8787/v1/models` should mention `grok-tts`.
2. Launch Clipboard TTS. Confirm the menu-bar speaker icon.
3. Open **Settings…**. Confirm the defaults in the table above. Leave API key empty.
4. Copy a short English sentence. Press **Option+Escape**. Audio should play. The floating panel should show previous / pause / stop / next.
5. Copy a Chinese paragraph (or mixed zh/en). Press Option+Escape again. Language must still work without sending `ja` or `auto`.
6. In Settings, switch **Paragraph split** across all four modes. Copy matching sample text (blank lines, one-line-per-paragraph, and multi-sentence prose) and confirm prev/next follows the selected mode.
7. Copy a Chinese paragraph (or mixed zh/en). Press Option+Escape again. Language must still work without sending `ja` or `auto`.
8. **Pause** should freeze audio; **Stop** should dismiss the panel.
9. Empty the clipboard and press Option+Escape. The panel should show a short “Clipboard is empty.” error and then hide.

## Layout

```
ClipboardTTS.xcodeproj      Xcode project + shared scheme
ClipboardTTS/               app sources, Info.plist, entitlements
project.yml                 optional XcodeGen spec
Makefile                    xcodebuild helpers
SPEC.md                     product lock
HANDOFF.md                  acceptance checklist
```
