# HANDOFF

clipboard-tts for Kip’s Mac (Ark). Product lock is [SPEC.md](SPEC.md). This is not Moshi.

## Acceptance checklist

- [ ] `ClipboardTTS.xcodeproj` opens in Xcode on Ark (scheme **ClipboardTTS**, destination My Mac).
- [ ] App builds for Apple Silicon (`xcodebuild -project ClipboardTTS.xcodeproj -scheme ClipboardTTS -configuration Release -arch arm64`).
- [ ] Run produces a menu-bar accessory (`LSUIElement`): no Dock icon, **always-on** speaker status item (still there when idle).
- [ ] Floating panel is hidden at launch and when idle/stopped. It appears only while speaking (loading / playing / paused) with previous / pause / stop / next.
- [ ] Settings shows Engine, Endpoint, API key, Model, Voice, Speed, Paragraph split with defaults:
  - Engine `openai`
  - Endpoint `http://127.0.0.1:8787/v1`
  - API key empty
  - Model `grok-tts`
  - Voice `carina`
  - Speed `1.1`, slider clamped 0.7–1.5
  - Paragraph split: **Blank lines, else every newline**
  - Open at Login: **off**
- [ ] Open at Login toggle uses `SMAppService`. Enabling registers a Login Item; disabling unregisters. First launch does not register.
- [ ] Paragraph split has all four modes; prev/next follows the selected mode:
  1. Blank lines only
  2. Every newline
  3. Blank lines when present, otherwise every newline (default)
  4. Sentences
- [ ] Settings survive quit/relaunch (UserDefaults + Keychain for the API key).
- [ ] With the proxy at `127.0.0.1:8787`, Option+Escape reads the clipboard, `POST`s `{endpoint}/audio/speech`, and plays mp3 audio.
- [ ] Request body includes `model`, `voice`, `input`, `speed`, `response_format=mp3`. No `language` field (so the proxy zh/en heuristic applies). Never `ja` or `auto`.
- [ ] Authorization Bearer is sent only when an API key is set.
- [ ] English and Chinese clipboard text both speak. Empty clipboard does not pop the floating panel.
- [ ] No real API keys in the repo. No Moshi UI/code. No Life OS scope.

## How to verify (Ark)

```bash
curl -sS http://127.0.0.1:8787/v1/models
open ClipboardTTS.xcodeproj   # Run, or: make run
```

Copy text → `⌥⎋` → hear audio → use the floating controls. Details in [README.md](README.md).

## Known gaps

- This Linux agent could not run `xcodebuild` or play audio. First green build has to happen on Ark.
- Signing is ad-hoc. Not notarized. Sandbox is off on purpose for a local loopback utility.
- Engine is stored for Moshi-style settings parity. The only network path is OpenAI-compatible `POST /audio/speech`; engine is not sent in the JSON body.
- Hotkey is locked to Option+Escape (not user-configurable).
- Carbon hotkeys usually work without Accessibility. If `⌥⎋` is swallowed, grant Accessibility as in the README.
- Sentence split is punctuation-based (`. ! ? 。 ！ ？`). Abbreviations such as `Dr.` may over-split. Unpunctuated text stays one unit.
- Open at Login from a Xcode debug run registers that debug build. Prefer the Release `.app` for a real login item.
- No auto-update, no voice catalog fetch from `GET /v1/models`.
