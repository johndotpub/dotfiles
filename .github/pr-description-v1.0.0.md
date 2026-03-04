## 🚀 Summary

This PR delivers **v1.0.0** of the dotfiles system with a brew-first installer, secure bootstrap, zsh-first configuration, and strong idempotency guarantees.

It focuses on clean defaults, safe reruns, and maintainable standards across scripts, docs, and CI.

## ✨ Highlights

- [x] 🌃 Starship Tokyo Night preset behavior covered
- [x] 📝 Nano + nanorc behavior covered
- [x] ♻️ Idempotency/rerun safety preserved
- [x] 🔧 Existing configs preserved by default

## 📦 v1.0.0 features (from CHANGELOG)

### Added ✨
- 🍺 Brew-first installer with apt fallback controls.
- 🌐 Release-verifying bootstrap (`SHA256`, optional GPG checksum signature).
- 🧩 Idempotent skel deployment with preserve-by-default behavior.
- 🔎 Verbose mode and 🧪 dry-run mode.
- 🚦 Post-install traffic-light checks.
- 🌃 Default Starship **Tokyo Night** preset support:
  - `skel/default/.config/starship.toml` includes the official preset.
  - Installer and `scripts/setup-starship.sh` apply `starship preset tokyo-night` when available.
- 📝 Nano syntax highlighting support (nanorc):
  - Clones `https://github.com/scopatz/nanorc.git` into `~/.nano`.
  - Ensures `~/.nanorc` includes `include ~/.nano/*.nanorc`.
- 🤖 Optional inference tools behind explicit flag:
  - `--install-inference` installs **ollama** and **llmfit** via curl scripts.
  - Default behavior remains off (`install_inference: false`).
- 🤖 Repo-level Copilot guidance via `.github/copilot-instructions.md`.
- 🧪 CI quality gates:
  - `bash -n` syntax checks
  - `shellcheck -x` linting
  - installer help smoke tests
  - idempotency integration test

### Changed 🔧
- ♻️ Overwrite behavior uses `--override` (`--force` alias retained).
- 🛟 `--override` modifications create `.bak.<date>` backups.
- 🧹 Zsh-first configuration kept minimal and aligned with project style.
- 📜 License standardized to canonical `UNLICENSE`.
- 🗂️ Release notes source changed from `RELEASES.md` to `CHANGELOG.md`.

## 🧪 Validation

- [x] `bash -n install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh`
- [x] `shellcheck -x install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh`
- [x] `./install.sh --help`
- [x] `./bootstrap.sh --help`
- [x] `./install.sh --dry-run --no-apt --brew-only --yes --verbose`
- [x] `./scripts/test-installer-idempotency.sh`

## 📚 Docs / Changelog

- [x] README updated (feature summary, override/backups, inference tools)
- [x] CHANGELOG updated with full v1.0.0 scope
- [x] Copilot instructions added/updated

## ⚠️ Risks / Notes

- Inference tools are intentionally opt-in only (`--install-inference`).
- Existing configs are preserved by default; overwrite requires explicit `--override`.
- Starship preset command is used when available, with fallback config when not.

## ✅ Checklist

- [x] Code is minimal and DRY
- [x] No nonstandard shell assumptions added
- [x] Override behavior creates `.bak.<date>` backups
- [x] Existing configs are preserved by default
