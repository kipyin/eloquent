# Coding standards

How to write and review code in this repo. Non-obvious domain terms live in `CONTEXT.md`. `/code-review` reads this file.

This is a Swift / AppKit / SwiftUI / Xcode macOS app.

## Names

A name in code uses the English from `CONTEXT.md` when that concept is defined there. Test titles use the same English. Names are specific.

Source names the domain. Ticket ids, planning labels, and other-repo names belong in the issue tracker and commit history.

`*Tests.swift` is a test (XCTest). A helper that tests import is a regular module, not a `*Tests.swift` file.

## Language

Identifiers, comments, and test titles are English. Chinese domain wording belongs in `CONTEXT.md`.

Join clauses with a colon, a period, or a hyphen.

Quoted platform error strings stay as the wire contract. Chinese in fixtures is data, not voice.

## Comments

Code, tests, types, configuration, and the Xcode project are the source of truth for current behavior and architecture. Comments explain local intent that those artifacts cannot express. A file may open with one line that says what the file does.

## Design

1. Plan each feature as the final version.
2. Required configuration is explicit and fails at the first use that needs it if missing, not later and not by crashing.

## Correctness

- Fix the shared function once. Grep every caller of the function you touch.
- Encode a recurring invariant earlier: type, `Codable`, failable initializer, single validation gate, or assert. Prefer construct or parse time over a later check.
- Switch over a closed enum handles every case. `@unknown default` is for OS-evolved enums, not a skip for a case you know about.
- Correctness outranks implementation cost. The ladder cuts unrequested abstraction and duplicate code, never a trust-boundary check or a real calculation.
- Compiler errors, test failures, and test flakiness get fixed when seen.

## Tests

- Tests protect runtime invariants that an earlier gate cannot prove. Prefer type, `Codable`, parse-time, construction-time, or assert-based enforcement before adding a test.
- Non-trivial logic leaves one runnable XCTest: the smallest check that fails for a plausible logic regression. State transitions, races, and security transformations are strong candidates. Trivial one-liners need no test.
- The default suite exercises owned, deterministic logic and in-process state. External systems (TTS HTTP, Keychain, Accessibility) get explicit live checks outside the default suite.
- Tests target a security or data-integrity invariant, not presence or presentation: control wiring, rendering, snapshots, labels, or copy.
- Fixtures are for Keychain, UserDefaults, or another stateful boundary that cannot be checked more directly.
