# Changelog 📝

All notable changes to this project are documented here.

## [v1.0.4] 🔐

### Fixed ✅
- 🔐 SSH config migration now backs up any pre-existing `~/.ssh/config.local` before writing migrated content, preventing silent clobbering.
- 🔐 SSH migration sanitizes self-referencing `Include ~/.ssh/config.local` and its preceding comment from migrated content to prevent recursive include loops on rerun.
- 🔐 SSH migration uses an idempotency guard (presence of `Include ~/.ssh/config.local` in `~/.ssh/config`) instead of only checking for `config.local` existence, preventing repeated re-migration on reruns.
- 🐚 Shell change flow now registers the Homebrew-installed zsh path in `/etc/shells` via `sudo` before calling `chsh`, ensuring `chsh` accepts the path on Linux.
- 🐚 Shell change `warn` and help output is now emitted near the end of script output (after the install summary), improving output readability.
- 🔒 `sudo -n` flag is now applied to the `tee -a /etc/shells` call, not only to the guard check, closing a TOCTOU window that could prompt interactively on some systems.
- 🌐 Bootstrap tagless warning now shows `--tag <release-tag>` instead of a hardcoded version, preventing a stale hint after every release.
- 🧪 Portable test: `test/bootstrap-main-fallback.sh` now uses a staging-directory approach instead of GNU-only `tar --transform`, fixing CI on macOS (`bsdtar`).
- 📝 SSH config migration comment updated to accurately describe the create-sanitized-copy-then-remove-original behavior.

### Changed 🔄
- 🔒 `sudo -v` warmup is performed immediately after the installer starts so interactive sudo prompts appear upfront rather than mid-run.
- 🔒 A background `sudo` keepalive loop is spawned for the script lifetime and cleaned up on exit via trap, removing the need for password re-entry on long installs.
- 🔒 Sudo keepalive loop now uses `read -r -t 50` (shell builtin timed wait) instead of `sleep 50`, avoiding orphaned background processes after the keepalive subshell is killed.
- 📦 README version references updated to `v1.0.4` (badge from `v1.0.2`, bootstrap example from `v1.0.3`).

### Tests ✅
- 🧪 New `test/backup-semantics.sh` closes the only gap in backup coverage: `backup_copy` (used by nanorc `--override`) was never exercised.
  - Asserts `backup_path` move semantics: original moved to `.bak.<ts>`, skel replacement deployed, original content preserved in backup.
  - Asserts `backup_copy` keep-in-place semantics: original file stays at its path, `.bak.<ts>` copy is also created, include line is appended.
  - Uses `DOTFILES_TEST_TIMESTAMP` to freeze time for deterministic backup filenames.
- 🧪 Removed duplicate test body from `test/bootstrap-main-fallback.sh` that ran the full bootstrap flow twice.

## [v1.0.2] 🛠️

### Fixed ✅
- 🍺 Homebrew bootstrap initialization now reliably resolves Linuxbrew/macOS paths after installer bootstrap.
- 🧪 `setup_brew_env` now treats failed `brew shellenv` calls as real failures (no false-positive success on `eval`).

### Changed 🔄
- 🧰 Consolidated brew env coverage into one DRY scenario suite (`test/brew-env.sh`) instead of multiple near-duplicate scripts.
- 🗂️ Standardized test filenames to concise, consistent names and switched the BATS entrypoint to `test/suite.bats`.
- 🌐 Reworked bootstrap E2E coverage to mirror README curl usage (`curl .../bootstrap.sh | bash -s -- --tag ...`) against the active PR payload in CI.
- ⚙️ CI trigger behavior now avoids duplicate branch runs by limiting push-triggered CI to `main` while PR validation runs on `pull_request`.

## [v1.0.1] 🎉

### Added ✨
- 🧱 New dotfiles bootstrap/install system with clear repo layout (`install.sh`, `bootstrap.sh`, `packages/`, `inventory/`, `skel/`, `test/`, CI workflows).
- 🍺 Brew-first installer with inventory-driven package selection (`packages/packages.yaml`) and apt fallback support.
- 🧩 Idempotent, preserve-by-default config deployment with explicit `--override` backups (`.bak.<date>[.<n>]`).
- 🔧 Core installer ergonomics:
  - `--dry-run`, `--verbose`, `--report-json`, and installer lock protection
  - preflight checks and traffic-light post-install status output
- 🔐 Verified bootstrap flow:
  - SHA256 artifact verification
  - optional GPG checksum signature verification with optional signer fingerprint pin (`BOOTSTRAP_GPG_FINGERPRINT`)
- 🐚 Zsh-first default environment with Oh My Zsh plugin baseline (`git pyenv python pip tmux`, plus conditional `fzf`/`sudo`).
- 🌃 Prompt/editor/dev UX defaults:
  - Starship Tokyo Night preset
  - Nano as default git editor + nanorc setup (graceful if nanorc clone fails)
  - tmux + oh-my-tmux bootstrap with `~/.tmux.conf.local` overrides
- 🔑 SSH safety migration:
  - managed `~/.ssh/config` includes `~/.ssh/config.local`
  - existing user `~/.ssh/config` auto-migrates to `config.local` when needed
- 🤖 Optional inference tools via explicit opt-in only (`--install-inference` for ollama + llmfit, with interactive confirmation unless `-y`).
- ✅ CI/release quality gates with DRY BATS integration suite covering idempotency, backups, merge behavior, SSH migration, tmux behavior, lock contention, JSON report validity, inference opt-in, nanorc failure handling, and reproducibility checks.
- 📦 Deterministic release artifact creation (`gzip -n` + normalized tar metadata) with checksum/signature publishing.
- 📜 Project standards/docs baseline:
  - canonical `UNLICENSE`
  - consolidated changelog
  - Copilot/agent instructions + PR template
