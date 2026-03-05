# Changelog 📝

All notable changes to this project are documented here.

## [Unreleased] 🚧

### Added ✨
- 🔒 Installer execution lock to prevent overlapping runs from mutating the same files concurrently.
- 🧪 Preflight phase in `install.sh` to validate required tooling early and surface actionable warnings.
- 📋 Optional machine-readable install report via `--report-json <path>`, including per-phase status and exit code.
- 🌐 Safer remote installer wrapper for optional inference tools (download-then-execute with retries and clear status logs).
- 🧾 Canonical package source of truth at `packages/manifest.json`.
- 🛠️ `scripts/generate-package-manifests.sh` to generate and verify `packages/*.txt` manifests.
- 🧹 `scripts/check-no-root-config-duplicates.sh` to enforce DRY shell-config ownership in `skel/default/`.
- ♻️ `scripts/verify-release-reproducible.sh` for deterministic tarball reproducibility checks.
- 🧪 Additional integration coverage:
  - `scripts/test-backup-collision.sh` (deterministic backup suffix behavior)
  - `scripts/test-skel-merge-behavior.sh` (merge-missing-only behavior)
  - `tests/installer.bats` BATS suite wrapping installer integration tests.

### Changed 🔧
- 🧩 Directory merge fallback in `install.sh` now uses explicit missing-path copy logic (instead of `cp -n`), reducing cross-platform drift and noisy warnings.
- ✅ CI and release workflows now enforce:
  - package manifest generation checks
  - no duplicate repo-root shell config files
  - expanded installer integration checks + BATS suite
  - reproducible release artifact verification.
- 📦 Release tarball creation switched to deterministic tar flags (`--sort=name`, normalized mtime/owner/group).
- 📚 README updated with lock/reporting flags, package manifest workflow, reproducibility validation, and expanded CI/test notes.

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
- 🌃 Default Starship **Tokyo Night** preset support:
  - `skel/default/.config/starship.toml` includes the official preset.
  - Installer and `scripts/setup-starship.sh` apply `starship preset tokyo-night` when available.
- 📝 Nano tooling support:
  - default git editor set to `nano`
  - nanorc setup (`~/.nano` + `~/.nanorc` include line)
- 🤖 Optional inference tools behind explicit flag:
  - `--install-inference` installs **ollama** and **llmfit** via curl scripts.
  - Default behavior remains off (`install_inference: false`).
- 📦 Expanded package manifests:
  - Brew: includes `curl`, `git`, `ca-certificates`, `ripgrep`, `btop`, `bandwhich`, `dust` (plus core tools)
  - Apt fallback: includes `iftop` and `iotop`
- ✅ CI quality gates and tests:
  - `bash -n` syntax checks
  - `shellcheck -x` linting
  - installer/bootstrap help smoke tests
  - dry-run smoke test
  - idempotency integration test (including `--override` backup assertions)
  - CI matrix on Ubuntu + macOS
- 🤖 Repo guidance and collaboration templates:
  - `.github/copilot-instructions.md`
  - `.github/pull_request_template.md`
- 📌 README badge set expanded to 12 badges (4-per-line layout).
- 🧾 Substantial inline comments added across installer and key operational scripts.

### Changed 🔧
- ♻️ Overwrite behavior now uses `--override` (`--force` alias retained).
- 🛟 `--override` modifications create `.bak.<date>` backups for changed configs.
- 🧹 Moved to zsh-first defaults; legacy `.dot/bootstrap` coupling removed.
- 🧪 Installer logic hardened for portability and reruns:
  - portable argument parsing (no GNU `getopt` dependency)
  - cross-platform file copy/merge behavior for Linux, WSL Ubuntu, and macOS
- 🧰 Bash config kept minimal while zsh remains primary.
- 📜 License standardized to canonical `UNLICENSE`.
- 🗂️ Release notes source changed from `RELEASES.md` to `CHANGELOG.md`.
- 🌐 README bootstrap quick start set to `https://dot.rly.wtf/bootstrap.sh`.
