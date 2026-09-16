# Eloquent — native macOS menu-bar TTS

Finish-owned product. Separate from Moshi. Ship for Kip’s Mac (Ark).

Repo: [github.com/kipyin/eloquent](https://github.com/kipyin/eloquent). Local checkout on Ark: `~/Code/eloquent`.

## Product (locked)

1. **Global hotkey** `⌥⎋` (Option+Escape): read current clipboard text → send to TTS → play audio. **Prompt the user to grant Accessibility** so the hotkey works in every app.
2. **Always-on menu-bar icon.** The status item stays in the menu bar for the life of the app (LSUIElement, no Dock icon). It is not a playback-only extra.
3. **Floating control panel only while speaking:** previous paragraph, pause, stop, next paragraph. Show during loading / playing / paused. **Hide when idle or stopped.** Do not leave the panel up as a standing window.
4. **Settings** (Moshi-style OpenAI TTS fields, plus paragraph split):
    - Engine (default `openai`)
    - Endpoint / base URL (default `http://127.0.0.1:8787/v1`)
    - API key (default empty or `unused` — the local proxy holds the real upstream key; do **not** bake any real key into the repo)
    - Model (default `grok-tts`)
    - Voice (default `carina`)
    - Speed (default `1.1`, clamp 0.7–1.5 to match proxy)
    - **Paragraph split** (prev/next uses this). Four modes:
      1. Blank lines only (double newline)
      2. Every newline is a paragraph
      3. Blank lines when present, otherwise every newline (**default**)
      4. Split on sentences
    - **Open at Login** — optional Login Item (`SMAppService`). **OFF by default.** Do not register on first launch.
5. **Language**: do not force Japanese. Prefer omitting `language` so the proxy’s zh/en-only heuristic runs; if sending language, only `zh` or `en`.
6. Menu-bar / local service app — **not** iOS, not a Moshi fork.

## TTS API (local proxy already running on Ark)

- Base: `http://127.0.0.1:8787/v1`
- `POST /v1/audio/speech` JSON: `{ "model", "voice", "input", "speed"?, "response_format"?: "mp3" }`
- Optional `language`: `zh` | `en` only (proxy remaps everything else via Han heuristic)
- `GET /v1/models` → `grok-tts`
- Client `api_key` may be unused; Authorization Bearer still send if key set
- Returns audio bytes (mp3)

Proxy repo (reference only, do not modify): local path `~/Code/xai-openai-tts-proxy` on Ark.

## Implementation expectations

- Swift + SwiftUI (or AppKit where needed for menu bar / global hotkey / floating panel)
- LSUIElement / always-on menu-bar accessory; floating panel only while speaking
- Global hotkey via Carbon plus event monitors; **prompt to grant Accessibility** for ⌥⎋
- Split clipboard text into paragraphs for prev/next using the selected Paragraph split mode
- Persist settings in UserDefaults (API key in Keychain preferred)
- README: build (`xcodebuild` or Xcode), run, grant Accessibility if prompted, verify Opt+Esc with proxy up
- HANDOFF.md: acceptance checklist + known gaps

## Out of scope

- Do not recreate Moshi
- Do not rotate or embed xAI keys
- Do not implement Life OS / other Kip products

## Done when

- App builds
- Settings UI has Engine / Endpoint / API key / Model / Voice / Speed / Paragraph split / Open at Login (off by default)
- Opt+Esc path implemented (clipboard → speech → play)
- Always-on menu-bar icon; floating panel with prev / pause / stop / next only while speaking (hidden when idle/stopped)
- First-launch Accessibility prompt for ⌥⎋; README documents the grant steps
- README + HANDOFF present
