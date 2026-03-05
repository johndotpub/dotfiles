# Changelog 📝

All notable changes to this project are documented here.

## [v1.0.0] 🎉

### Added ✨
- 🧱 New repo layout for bootstrap + config management:
  - `install.sh`, `bootstrap.sh`
  - `packages/`, `inventory/`, `skel/`, `scripts/`
  - `.github/workflows/` for CI + release automation
- 🍺 Brew-first installer with apt fallback controls and host/inventory support.
- 🌐 Release-verifying bootstrap (`SHA256`, optional GPG checksum signature).
- 🧩 Idempotent skel deployment with preserve-by-default behavior.
- 🔎 Verbose mode, 🧪 dry-run mode, and 🚦 traffic-light post-checks.
- 🔒 Installer execution lock to prevent overlapping runs.
- 🧪 Installer preflight checks for required tooling.
- 📋 Optional machine-readable install report (`--report-json <path>`) with phase status + exit code.
- 🌃 Default Starship **Tokyo Night** preset support:
  - `skel/default/.config/starship.toml` includes the official preset.
  - Installer and `scripts/setup-starship.sh` apply `starship preset tokyo-night` when available.
- 🧱 tmux experience improvements:
  - installer can bootstrap **oh-my-tmux** (`gpakosz/.tmux`) and link `~/.tmux.conf`
  - default local overrides shipped in `skel/default/.tmux.conf.local`
  - zsh plugin set now includes Oh My Zsh `tmux` plugin
- 🔐 SSH config migration helper:
  - when `~/.ssh/config` exists and `~/.ssh/config.local` is absent, installer migrates existing config to `config.local`
  - managed `~/.ssh/config` is seeded with `Include ~/.ssh/config.local`
- 📝 Nano tooling support:
  - default git editor set to `nano`
  - nanorc setup (`~/.nano` + `~/.nanorc` include line)
- 🤖 Optional inference tools behind explicit flag:
  - `--install-inference` installs **ollama** and **llmfit** via curl scripts.
  - Default behavior remains off (`install_inference: false`).
- 📦 Single-source package inventory in `packages/packages.yaml`:
  - Brew list includes `curl`, `git`, `ca-certificates`, `ripgrep`, `btop`, `bandwhich`, `dust` (plus core tools)
  - Apt fallback list includes `iftop` and `iotop`
- 🌐 Safer remote wrapper for optional installer scripts (download-then-execute with retry).
- ✅ CI quality gates and tests:
  - `bash -n` syntax checks
  - `shellcheck -x` linting
  - no duplicate repo-root shell config checks
  - installer/bootstrap help smoke tests
  - dry-run smoke test
  - DRY BATS test suite (`test/installer.bats`) covering:
    - idempotency + override backup assertions
    - backup collision suffixing
    - skel merge behavior
    - SSH include migration behavior
    - oh-my-tmux behavior
    - installer lock contention
    - report JSON validity/escaping
    - release reproducibility check
  - test layout standardized under `test/`
  - CI matrix on Ubuntu + macOS
- ♻️ Release reproducibility checks:
  - deterministic tarball creation (`--sort=name`, normalized mtime/owner/group)
  - `test/verify-release-reproducible.sh`
- 🤖 Repo guidance and collaboration templates:
  - `.github/copilot-instructions.md`
  - `.github/pull_request_template.md`
- 📝 Copilot/agentic standards now explicitly require ample, purposeful section/function comments in shell scripts and tests.
- 📌 README badge set expanded to 12 badges (4-per-line layout).
- 🧾 Substantial inline comments added across installer and key operational scripts.

### Changed 🔧
- ♻️ Overwrite behavior now uses `--override` (`--force` alias retained).
- 🛟 `--override` modifications create `.bak.<date>` backups for changed configs.
- 🧹 Moved to zsh-first defaults; legacy `.dot/bootstrap` coupling removed.
- 🧪 Installer logic hardened for portability and reruns:
  - portable argument parsing (no GNU `getopt` dependency)
  - cross-platform file copy/merge behavior for Linux, WSL Ubuntu, and macOS
  - explicit merge fallback logic (replacing `cp -n` fallback behavior)
  - JSON report escaping now handles additional control characters safely
- 🐚 Removed custom `zsh-pyenv` cloning flow; standardized on default Oh My Zsh `pyenv` plugin usage in `skel/default/.zshrc`.
- 🔐 nanorc clone path now supports pinned commit installs via `NANORC_REF` (default pinned to a known-good ref).
- 🔐 Bootstrap checksum verification now relies on native SHA256 tools (`sha256sum`/`shasum`) without Python fallback.
- 🔐 Bootstrap GPG verification now supports optional signer pinning via `BOOTSTRAP_GPG_FINGERPRINT`.
- 🔐 Optional inference installer scripts are checksum-pinned by default (override via `OLLAMA_SCRIPT_SHA256` / `LLMFIT_SCRIPT_SHA256`).
- 📦 Release/reproducibility tarballs now use deterministic gzip headers (`gzip -n`) in CI and verification checks.
- 🧰 Canonical shell config ownership consolidated under `skel/default/` (DRY, zsh-first).
- 📜 License standardized to canonical `UNLICENSE`.
- 🗂️ Release notes source changed from `RELEASES.md` to `CHANGELOG.md`.
- 🌐 README bootstrap quick start set to `https://dot.rly.wtf/bootstrap.sh`.
