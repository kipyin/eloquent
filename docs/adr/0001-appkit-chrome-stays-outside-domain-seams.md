# ADR 0001: AppKit chrome stays outside domain seams

## Status

Accepted

## Context

Eloquent is a small menu-bar TTS app. An architecture review using the explore + deepen flow found real shallowness at TTS synthesis, paragraph split, speech playback, and settings persistence. Status item, global hotkey, floating control panel, application menu, Accessibility prompt, and Open at Login are working AppKit glue. They have changed when product behavior around those chrome pieces broke (paste, always-on status item, launch).

## Decision

Do not introduce a seam in status item, hotkey, floating panel, application menu, Accessibility, or Login Items unless domain policy moves there. Domain seams sit at:

- TTS synthesis (`TTSSynthesizing`, HTTP transport as an internal seam)
- paragraph split (`ParagraphSplitter.split`)
- speech playback (`AudioPlaying`)
- settings persistence (`AppSettings` with injected defaults and `APIKeyStoring`)

`SpeechController` is the deep speech-session module. It accepts those adapters; it does not own AppKit chrome.

## Consequences

The default XCTest suite hits the domain interfaces above, not NSStatusItem or Carbon hotkeys. A future review should not re-propose wrapping the chrome unless a testable invariant actually lives there.
