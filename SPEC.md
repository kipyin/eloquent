# Eloquent — native macOS menu-bar TTS

Finish-owned product. Separate from Moshi.

Repo: [github.com/kipyin/eloquent](https://github.com/kipyin/eloquent).

## Product (locked)

1. **Global hotkey** `⌥⎋` (Option+Escape): read current clipboard text → send to TTS → play audio. **Prompt the user to grant Accessibility** so the hotkey works in every app.
2. **Always-on menu-bar icon.** The status item stays in the menu bar for the life of the app (LSUIElement, no Dock icon). It is not a playback-only extra.
3. **Floating control panel only while speaking:** previous paragraph, pause, stop, next paragraph. Show during loading / playing / paused. **Hide when idle or stopped.** Do not leave the panel up as a standing window.
4. **Settings** (OpenAI TTS fields, plus paragraph split):
    - Engine (default `openai`)
    - Endpoint / base URL (default empty). User must configure an OpenAI-compatible `/v1` base. Speak fails clearly in the UI if Endpoint is empty. Do not crash.
    - API key (default empty; persist in Keychain). Never commit API keys.
    - Model (default `tts-1`)
    - Voice (default `alloy`)
    - Speed (default `1.1`, clamp 0.7–1.5)
    - **Paragraph split** (prev/next uses this). Four modes:
      1. Blank lines only (double newline)
      2. Every newline is a paragraph
      3. Blank lines when present, otherwise every newline (**default**)
      4. Split on sentences
    - **Open at Login** — optional Login Item (`SMAppService`). **OFF by default.** Do not register on first launch.
5. **Language**: omit the `language` field. The client never sends `ja` or `auto`. Providers may apply their own heuristics.
6. Menu-bar / local service app — **not** iOS, not a Moshi fork.

## TTS API

- User-configured OpenAI-compatible `/v1` base (Settings → Endpoint)
- `POST {endpoint}/audio/speech` JSON: `{ "model", "voice", "input", "speed"?, "response_format"?: "mp3" }`
- Omit `language`. Never send `ja` or `auto`.
- Authorization Bearer is sent only when an API key is set
- Returns audio bytes (mp3)

Any provider that implements that POST works. Neutral placeholders: model `tts-1`, voice `alloy`.

## Implementation expectations

- Swift + SwiftUI (or AppKit where needed for menu bar / global hotkey / floating panel)
- LSUIElement / always-on menu-bar accessory; floating panel only while speaking
- Global hotkey via Carbon plus event monitors; **prompt to grant Accessibility** for ⌥⎋
- Split clipboard text into paragraphs for prev/next using the selected Paragraph split mode
- Persist settings in UserDefaults (API key in Keychain)
- README: build (`xcodebuild` or Xcode), run, grant Accessibility if prompted, configure Endpoint + API key
- HANDOFF.md: portable acceptance checklist + known gaps

## Out of scope

- Do not recreate Moshi
- Do not commit API keys
- Do not implement Life OS / other Kip products

## Done when

- App builds
- Settings UI has Engine / Endpoint / API key / Model / Voice / Speed / Paragraph split / Open at Login (off by default)
- Endpoint default is empty; empty Endpoint fails clearly in the UI
- Opt+Esc path implemented (clipboard → speech → play)
- Always-on menu-bar icon; floating panel with prev / pause / stop / next only while speaking (hidden when idle/stopped)
- First-launch Accessibility prompt for ⌥⎋; README documents the grant steps
- README + HANDOFF present
- MIT LICENSE (Copyright (c) 2026 Kip Yin)
