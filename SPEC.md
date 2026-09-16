# clipboard-tts — native macOS menu-bar TTS

Finish-owned product. Separate from Moshi. Ship for Kip’s Mac (Ark).

## Product (locked)

1. **Global hotkey** `⌥⎋` (Option+Escape): read current clipboard text → send to TTS → play audio.
2. **Floating control panel** while speaking: previous paragraph, pause, stop, next paragraph.
3. **Settings** (Moshi-style OpenAI TTS fields):
    - Engine (default `openai`)
    - Endpoint / base URL (default `http://127.0.0.1:8787/v1`)
    - API key (default empty or `unused` — the local proxy holds the real upstream key; do **not** bake any real key into the repo)
    - Model (default `grok-tts`)
    - Voice (default `carina`)
    - Speed (default `1.1`, clamp 0.7–1.5 to match proxy)
4. **Language**: do not force Japanese. Prefer omitting `language` so the proxy’s zh/en-only heuristic runs; if sending language, only `zh` or `en`.
5. Menu-bar / local service app — **not** iOS, not a Moshi fork.

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
- LSUIElement / menu-bar accessory app
- Global hotkey via Carbon/HotKey or `KeyboardShortcuts` / equivalent; document Accessibility permission if required
- Split clipboard text into paragraphs for prev/next
- Persist settings in UserDefaults (API key in Keychain preferred)
- README: build (`xcodebuild` or Xcode), run, grant Accessibility if prompted, verify Opt+Esc with proxy up
- HANDOFF.md: acceptance checklist + known gaps

## Out of scope

- Do not recreate Moshi
- Do not rotate or embed xAI keys
- Do not implement Life OS / other Kip products

## Done when

- App builds
- Settings UI has Engine / Endpoint / API key / Model / Voice / Speed with defaults above
- Opt+Esc path implemented (clipboard → speech → play)
- Floating panel with prev / pause / stop / next
- README + HANDOFF present
