# AGENTS

## Source of truth

Code, tests, types, configuration, and the Xcode project define current behavior and architecture. The latest explicit task defines the desired change. Keep documentation for facts the code cannot express.

## Coding standards

See `CODING_STANDARDS.md` when writing or reviewing code.

## Domain language

Use `CONTEXT.md` for non-obvious business terms. When code and the glossary diverge, verify behavior from code and update the glossary.

## Issue tracker

Issues live in GitHub Issues (kipyin/eloquent); use the `gh` CLI. See `docs/agents/issue-tracker.md`. Triage labels are `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` — see `docs/agents/triage-labels.md`.

## Agent skills

### Issue tracker

GitHub Issues on kipyin/eloquent, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical roles identity-mapped. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.

### Coding standards

See `CODING_STANDARDS.md`.
