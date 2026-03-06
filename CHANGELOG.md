# Changelog 📝

All notable changes to this project are documented here.

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
