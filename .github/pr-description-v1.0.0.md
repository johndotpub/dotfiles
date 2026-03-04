## 🚀 Summary

This PR delivers **v1.0.0** of the dotfiles system with a brew-first installer, secure bootstrap, zsh-first configuration, and strong idempotency guarantees across Ubuntu, WSL Ubuntu, and macOS.

It focuses on clean defaults, safe reruns, and maintainable standards across scripts, docs, and CI.

## ✨ Highlights

- [x] 🌃 Starship Tokyo Night preset behavior covered
- [x] 📝 Nano + nanorc behavior covered
- [x] ♻️ Idempotency/rerun safety preserved
- [x] 🔧 Existing configs preserved by default, override with backups

## 📦 v1.0.0 features (from CHANGELOG)

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
  - Clones `https://github.com/scopatz/nanorc.git` into `~/.nano`.
  - Ensures `~/.nanorc` includes `include ~/.nano/*.nanorc`.
- 🤖 Optional inference tools behind explicit flag:
  - `--install-inference` installs **ollama** and **llmfit** via curl scripts.
  - Default behavior remains off (`install_inference: false` in inventory).
- 📦 Expanded package manifests:
  - Brew includes `curl`, `git`, `ca-certificates`, `ripgrep`, `btop`, `bandwhich`, `dust` (plus core tooling)
  - Apt fallback includes `iftop` and `iotop`
- ✅ CI quality gates and tests:
  - `bash -n` syntax checks
  - `shellcheck -x` linting
  - installer help smoke tests
  - dry-run smoke test
  - idempotency integration test (including `--override` backup assertions)
  - CI matrix on Ubuntu + macOS
- 🤖 Repo-level Copilot guidance via `.github/copilot-instructions.md`.
- 📋 PR quality template via `.github/pull_request_template.md`.
- 📌 README badge set expanded to 12 badges (4-per-line layout).
- 🧾 Substantial inline comments added across installer and key scripts.

### Changed 🔧
- ♻️ Overwrite behavior now uses `--override` (`--force` alias retained).
- 🛟 `--override` modifications create `.bak.<date>` backups.
- 🧹 Moved to zsh-first defaults; legacy `.dot/bootstrap` coupling removed.
- 🧪 Installer hardened for cross-platform portability:
  - portable arg parsing (no GNU `getopt` dependency)
  - cross-platform copy/merge behavior for Linux + macOS
- 📜 License standardized to canonical `UNLICENSE`.
- 🗂️ Release notes source changed from `RELEASES.md` to `CHANGELOG.md`.
- 🌐 README bootstrap quick start set to `https://dot.rly.wtf/bootstrap.sh`.

## 🧪 Validation

- [x] `bash -n install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh`
- [x] `shellcheck -x install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh`
- [x] `./install.sh --help`
- [x] `./bootstrap.sh --help`
- [x] `./install.sh --dry-run --no-apt --brew-only --yes --verbose`
- [x] `./scripts/test-installer-idempotency.sh`

## 📚 Docs / Changelog

- [x] README updated (OS support, quick start, features, badges)
- [x] CHANGELOG updated with full v1.0.0 scope
- [x] Copilot instructions added/updated

## ⚠️ Risks / Notes

- Inference tools are intentionally opt-in only (`--install-inference`).
- Existing configs are preserved by default; overwrite requires explicit `--override`.
- Starship preset command is used when available, with fallback config when not.
- Supported target environments: Ubuntu, WSL Ubuntu, macOS.

## ✅ Checklist

- [x] Code is minimal and DRY
- [x] No nonstandard shell assumptions added
- [x] Override behavior creates `.bak.<date>` backups
- [x] Existing configs are preserved by default
