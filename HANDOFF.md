# HANDOFF

Eloquent. Repo [kipyin/eloquent](https://github.com/kipyin/eloquent). Product lock is [SPEC.md](SPEC.md). This is not Moshi.

## Acceptance checklist

- [ ] `Eloquent.xcodeproj` opens in Xcode (scheme **Eloquent**, destination My Mac).
- [ ] App builds for Apple Silicon (`xcodebuild -project Eloquent.xcodeproj -scheme Eloquent -configuration Release -arch arm64`).
- [ ] Run produces a menu-bar accessory (`LSUIElement`): no Dock icon, **always-on** speaker status item (still there when idle).
- [ ] First launch prompts to grant Accessibility for global ⌥⎋ (also Settings → Hotkey and menu **Grant Accessibility…**). After enabling Eloquent in System Settings → Privacy & Security → Accessibility, quit and reopen.
- [ ] Floating panel is hidden at launch and when idle/stopped. It appears only while speaking (loading / playing / paused) with previous / pause / stop / next.
- [ ] Settings shows Engine, Endpoint, API key, Model, Voice, Speed, Paragraph split with defaults:
  - Engine `openai`
  - Endpoint empty
  - API key empty
  - Model `tts-1`
  - Voice `alloy`
  - Speed `1.1`, slider clamped 0.7–1.5
  - Paragraph split: **Blank lines, else every newline**
  - Open at Login: **off**
- [ ] Settings copy tells the user to configure Endpoint and API key for their provider. Speak with an empty Endpoint fails clearly in the UI and does not crash.
- [ ] Open at Login toggle uses `SMAppService`. Enabling registers a Login Item; disabling unregisters. First launch does not register.
- [ ] Paragraph split has all four modes; prev/next follows the selected mode:
  1. Blank lines only
  2. Every newline
  3. Blank lines when present, otherwise every newline (default)
  4. Sentences
- [ ] Settings survive quit/relaunch (UserDefaults + Keychain for the API key).
- [ ] With Endpoint set to an OpenAI-compatible `/v1` base, Option+Escape reads the clipboard, `POST`s `{endpoint}/audio/speech`, and plays mp3 audio.
- [ ] Request body includes `model`, `voice`, `input`, `speed`, `response_format=mp3`. No `language` field. Never `ja` or `auto`.
- [ ] Authorization Bearer is sent only when an API key is set.
- [ ] English and Chinese clipboard text both speak. Empty clipboard does not pop the floating panel.
- [ ] No API keys in the repo. No Moshi UI/code. No Life OS scope.

## How to verify

```bash
open Eloquent.xcodeproj   # Run, or: make run
```

Set Endpoint + API key in Settings. Copy text → `⌥⎋` → hear audio → use the floating controls. Details in [README.md](README.md).

## Known gaps

- Signing is ad-hoc. Not notarized. Sandbox is off on purpose for a local utility.
- On some recent macOS / Xcode versions, `@main` AppDelegate did not receive `applicationDidFinishLaunching`; keep explicit `main.swift` that sets `NSApplication.shared.delegate` before `NSApplicationMain`.
- Engine is stored for settings parity. The only network path is OpenAI-compatible `POST /audio/speech`; engine is not sent in the JSON body.
- Hotkey is locked to Option+Escape (not user-configurable).
- After granting Accessibility, macOS requires a relaunch before `AXIsProcessTrusted()` returns true.
- Sentence split is punctuation-based (`. ! ? 。 ！ ？`). Abbreviations such as `Dr.` may over-split. Unpunctuated text stays one unit.
- Open at Login from a Xcode debug run registers that debug build. Prefer the Release `.app` for a real login item.
- No auto-update, no voice catalog fetch from `GET /v1/models`.
