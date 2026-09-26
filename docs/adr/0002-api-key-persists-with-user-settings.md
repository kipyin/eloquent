# ADR 0002: API key persists with other user settings

## Status

Accepted

## Context

The API key is a user-entered TTS provider secret. User configuration has two requirements: it persists across updates, and Eloquent redacts it (masked in Settings, absent from logs and error text). Plaintext at rest meets both. The login Keychain binds each item to the creating binary's code signature, so a replaced app must ask for the login keychain password before it can read the key.

## Decision

Persist the API key with the other user settings. Do not keep it in the Keychain.

On launch, copy the existing Keychain item into user settings only when migration has not succeeded and the user has neither saved nor cleared an API key. Then delete that item once. If the read is denied or fails, leave the key empty for this launch and try again on the next launch. A value the user has saved in Settings is never overwritten by the Keychain. Clearing the API key, including Reset Defaults, leaves it empty and does not restore the Keychain value. If the copy succeeds and the delete fails, leave the Keychain item; later launches neither read nor delete it.

## Considered options

- Keep the Keychain and silence the dialog with an access group or the data-protection keychain. Rejected: the two requirements do not need the Keychain.
- Leave the old item in place and make the user type the key again. Rejected: a key they already entered should survive the move.

## Consequences

The first launch that copies an existing Keychain item may still show the login-keychain dialog. A denial brings that dialog back on later launches until the copy succeeds, or until the user saves or clears a key in Settings. Reset Defaults before a successful copy abandons the Keychain key. A failed delete leaves the old secret in the login keychain, and Eloquent does not ask again to remove it.

Anything that can read this user's preferences can read the API key.

ADR 0001 names `APIKeyStoring` as a settings seam because the secret had its own store. That separate store is gone. The seam can remain as a test boundary; it is no longer a second place the key lives.
