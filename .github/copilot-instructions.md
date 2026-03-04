# Copilot Workspace Instructions 🤖

Use these repository standards for all generated code, docs, and workflow updates.

## Core principles

- Keep it **minimal**, **readable**, and **idempotent**.
- Prefer safe defaults:
  - Preserve existing user config files by default.
  - Only overwrite when explicit override behavior is requested.
- Avoid unnecessary churn and avoid introducing nonstandard patterns.

## Shell/config standards

- Primary shell target is **zsh**.
- Keep `.zshrc` concise and close to project conventions.
- Do not add `.zprofile` dependencies.
- Any overwrite flow must create `.bak.<date>` backups.

## Installer standards

- Preserve rerun safety (idempotent behavior is required).
- Prefer `command -v` checks before installation or configuration actions.
- Keep logs concise in normal mode and detailed in verbose mode.
- New behavior should include dry-run compatibility.

## Build + CI standards

- For shell scripts, always include:
  - `bash -n` syntax checks
  - `shellcheck -x` lint checks
- Add/extend tests when behavior changes, especially installer idempotency.
- Keep workflows simple and deterministic.

## DRY standards

- Reuse shared helpers instead of duplicating shell setup logic.
- Keep repeated constants and behaviors centralized where possible.
- Update docs when behavior changes.

## Docs/content standards

- Keep README clear, practical, and concise.
- Emojis are welcome but should remain tasteful and sparse.
- Keep changelog entries meaningful and user-facing.
