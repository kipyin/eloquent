# Eloquent

Native macOS menu-bar app. The speak hotkey reads the clipboard and speaks it through an OpenAI-compatible TTS endpoint.

## What it does

- Configurable global speak hotkey (default Option+Escape, `⌥⎋`) reads clipboard text and plays speech
- Speaker icon stays in the menu bar
- Floating previous / pause / stop / next / speed panel appears only while speaking
- Settings: Engine, Endpoint, API key, Model, Voice, Speed, Speed apply, Paragraph split, Speak hotkey, Open at Login

## Install / run

macOS 14+, Apple Silicon, Xcode 15.4+.

```bash
open Eloquent.xcodeproj
```

Select the **Eloquent** scheme, destination **My Mac**, then Run. Grant Accessibility when prompted so the hotkey works in every app. Open Settings and set **Endpoint** (the `/v1` base URL) plus an API key.

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
