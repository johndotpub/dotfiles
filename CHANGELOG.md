# Changelog 📝

All notable changes to this project are documented here.

## [Unreleased] 🚧

- 📌 Added v1.0.0-focused badges to README (version, CI, release, UNLICENSE).

## [v1.0.0] 🎉

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
  - Installs/clones `https://github.com/scopatz/nanorc.git` into `~/.nano`.
  - Ensures `~/.nanorc` includes `include ~/.nano/*.nanorc`.
- 🤖 Optional inference tools behind explicit flag:
  - `--install-inference` installs **ollama** and **llmfit** via their curl install scripts.
  - Default behavior does not install inference tools (`install_inference: false`).
- 🤖 Repo-level Copilot guidance via `.github/copilot-instructions.md`.
- 🧪 CI quality gates:
  - `bash -n` syntax checks
  - `shellcheck -x` linting
  - installer help smoke tests
  - idempotency integration test

### Changed 🔧
- ♻️ Overwrite behavior now uses `--override` (with `--force` as alias).
- 🛟 When `--override` modifies existing configs, it creates `.bak.<date>` backups.
- 🧹 Zsh-first configuration kept minimal and aligned with project style.
- 📜 License file standardized to canonical `UNLICENSE`.
- 🗂️ Release notes source changed from `RELEASES.md` to `CHANGELOG.md`.
