# Eloquent language

A glossary for domain terms whose meanings cannot be inferred safely from code. It names concepts; code and tests define behavior.

**Eloquent**:
Native macOS menu-bar TTS app. The speak hotkey reads clipboard text and plays speech from an OpenAI-compatible endpoint.

**Status item**:
The always-on speaker icon in the menu bar. It stays there for the life of the app. The app is an `LSUIElement` accessory: no Dock icon.
_Avoid_: playback-only extra, Dock app

**Floating control panel**:
Previous / pause / stop / next. Shown only while speaking (loading, playing, paused). Hidden when idle or stopped.
_Avoid_: standing window, always-on panel

**Clipboard**:
The source of text to speak. Empty clipboard does not show the floating panel.

**Paragraph split**:
How previous / next walks clipboard text. Four modes: blank lines only; every newline; blank lines when present otherwise every newline (default); sentences.

**Endpoint**:
The user-configured OpenAI-compatible `/v1` base URL. Required before speaking. Empty Endpoint fails clearly in the UI.
_Avoid_: hardcoded provider URL

**TTS request**:
`POST {endpoint}/audio/speech` with `{ model, voice, input, speed, response_format: "mp3" }`. No `language` field. Bearer token only when an API key is set.

**Engine**:
Stored in Settings for parity (`openai` by default). Not sent in the TTS JSON body.

**Speak hotkey**:
The user-configured global shortcut that reads the clipboard and speaks it. Default is Option+Escape (⌥⎋). Persisted in Settings. Changing it rebinds the running app. A reserved or conflicting combo keeps the last working binding.

**Accessibility**:
macOS permission required so the speak hotkey works in every app. After granting, quit and reopen.

**Open at Login**:
Optional Login Item via `SMAppService`. Off by default. Not registered on first launch.

**API key**:
Provider secret stored in Keychain (`com.kipyin.eloquent`). Never committed.
