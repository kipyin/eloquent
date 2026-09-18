# Eloquent language

A glossary for domain terms whose meanings cannot be inferred safely from code. It names concepts; code and tests define behavior.

**Eloquent**:
Native macOS menu-bar TTS app. The speak hotkey reads the current selection — or the clipboard when nothing is selected — and plays speech from an OpenAI-compatible endpoint.

**Status item**:
The always-on speaker icon in the menu bar. It stays there for the life of the app. The app is an `LSUIElement` accessory: no Dock icon.
_Avoid_: playback-only extra, Dock app

**Floating control panel**:
Previous / pause / stop / next, plus speed. Shown only while speaking (loading, playing, paused). Hidden when idle or stopped.
_Avoid_: standing window, always-on panel

**Speed apply**:
When speed changes during a speech session (loading, playing, paused). Next paragraph only (default) leaves the current paragraph playing and uses the new speed on the next synthesis. Re-speak current paragraph cancels the current paragraph’s audio and synthesizes it again at the new speed. Reset Defaults restores 1.1× and next-paragraph-only.

**Selection**:
The live text selection in the frontmost app, read through Accessibility. Preferred source of text to speak; when the selection is empty or the app does not expose it, speaking falls back to the clipboard.

**Clipboard**:
Fallback source of text to speak, used when there is no readable selection. Empty selection and empty clipboard fail clearly; the floating panel stays hidden.

**Paragraph split**:
How previous / next walks the spoken text. Four modes: blank lines only; every newline; blank lines when present otherwise every newline (default); sentences.

**Endpoint**:
The user-configured base URL of the active Engine. Required before speaking. Each engine prefills its official URL; user overrides (proxies, gateways) survive engine switches. Empty Endpoint fails clearly in the UI.
_Avoid_: hardcoded provider URL

**TTS request**:
Per-engine shape, chosen by Engine. `openai`: POST `{endpoint}/audio/speech` with `{ model, voice, input, speed, response_format: "mp3" }`. No `language` field — providers apply their own heuristics. `grok`: POST `{endpoint}/tts` with `{ text, voice_id, language: "auto", speed }` — the provider requires `language`, hardcoded to `auto`; no `model` field. Bearer token only when an API key is set; one shared key for all engines.

**Engine**:
The TTS provider chosen in Settings: `openai` or `grok`. A preset bundle: each engine fixes the request shape, the URL path, the official Endpoint prefill, and the default Voice. Switching engines always resets Voice to the new engine's default, and replaces Endpoint with the official URL only when Endpoint still holds the previous engine's official URL. Unknown stored values fall back to `openai`. The engine choice itself is never sent in the request body.

**Speak hotkey**:
The user-configured global shortcut that reads the current selection — or the clipboard when nothing is selected — and speaks it. Default is Option+Escape (⌥⎋). Persisted in Settings. Changing it rebinds the running app. A reserved or conflicting combo keeps the last working binding.

**Accessibility**:
macOS permission required so the speak hotkey works in every app and so Eloquent can read the frontmost app's selected text. After granting, quit and reopen.

**Open at Login**:
Optional Login Item via `SMAppService`. Off by default. Not registered on first launch.

**API key**:
Provider secret stored in Keychain (`com.kipyin.eloquent`). Never committed.
