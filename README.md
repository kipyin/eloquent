# Eloquent

Native macOS menu-bar app. The speak hotkey reads the current selection — or the clipboard when nothing is selected — and speaks it through OpenAI-compatible or Grok (xAI) TTS.

## What it does

- Configurable global speak hotkey (default Option+Escape, `⌥⎋`) reads the selected text, or the clipboard when nothing is selected, and plays speech
- Speaker icon stays in the menu bar
- Floating previous / pause / stop / next / speed panel appears only while speaking
- Settings: Engine, Endpoint, API key, Model, Voice, Speed, Speed apply, Paragraph split, Speak hotkey, Open at Login

## Text source: selection first, clipboard fallback

Speaking prefers the live text selection in the frontmost app, read through the same Accessibility permission the hotkey uses. When nothing is selected or the app does not expose its selection, Eloquent speaks the clipboard instead. If both are empty, it fails with a transient error and the floating panel stays hidden.

The selection cannot be read everywhere; in these cases Eloquent silently falls back to the clipboard:

- Accessibility permission not granted (System Settings → Privacy & Security → Accessibility)
- Apps that do not expose selected text to Accessibility — some terminals, canvas-rendered editors, and custom text controls
- Secure text fields (passwords), which never expose their contents
- No focused text element (for example the selection sits in a dialog that lost focus)

## Install / run

macOS 14+, Apple Silicon, Xcode 15.4+.

```bash
open Eloquent.xcodeproj
```

Select the **Eloquent** scheme, destination **My Mac**, then Run. Grant Accessibility when prompted so the hotkey works in every app. Open Settings, pick an **Engine**, and set **Endpoint** (the `/v1` base URL) plus an API key.

From the command line:

```bash
make run
```

## Develop

```bash
make build
make test
CONFIG=Release make run
xcodebuild -project Eloquent.xcodeproj -scheme Eloquent -configuration Release -arch arm64 -derivedDataPath build build
```

`Eloquent/` is the app. `Eloquent.xcodeproj` is the Xcode project; `project.yml` can regenerate it with XcodeGen. `Makefile` wraps xcodebuild.
