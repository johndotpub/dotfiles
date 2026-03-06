# ✨A brew-first and zsh-focused toolkit

[![Version](https://img.shields.io/badge/version-v1.0.4-7aa2f7?style=flat-square)](https://github.com/johndotpub/dotfiles/releases/tag/v1.0.4) [![Release](https://img.shields.io/github/v/release/johndotpub/dotfiles?style=flat-square)](https://github.com/johndotpub/dotfiles/releases) [![CI](https://img.shields.io/github/actions/workflow/status/johndotpub/dotfiles/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/johndotpub/dotfiles/actions/workflows/ci.yml) [![UNLICENSE](https://img.shields.io/badge/license-UNLICENSE-blue.svg?style=flat-square)](./UNLICENSE)  
[![Shell Zsh](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square)](https://www.zsh.org/) [![Framework Oh My Zsh](https://img.shields.io/badge/framework-Oh%20My%20Zsh-4fd1c5?style=flat-square)](https://ohmyz.sh/) [![Prompt Starship](https://img.shields.io/badge/prompt-starship-7aa2f7?style=flat-square)](https://starship.rs/) [![Python Pyenv](https://img.shields.io/badge/python-pyenv-3776ab?style=flat-square)](https://github.com/pyenv/pyenv)  
[![Editor Nano](https://img.shields.io/badge/editor-nano-4a90e2?style=flat-square)](https://www.nano-editor.org/) [![Lint ShellCheck](https://img.shields.io/badge/lint-shellcheck-ffd43b?style=flat-square)](https://www.shellcheck.net/) [![Package Manager Homebrew](https://img.shields.io/badge/package%20manager-Homebrew-fbb040?style=flat-square)](https://brew.sh/) [![Platform Linux/WSL](https://img.shields.io/badge/platform-Linux%20%7C%20WSL-1793d1?style=flat-square)](https://learn.microsoft.com/windows/wsl/)

Clean, straightforward dotfiles setup for Linux/WSL:

**Supported OS:** Ubuntu, Ubuntu (WSL), and macOS.
**Focus:** A Homebrew-first, zsh-focused dotfiles toolkit.

- 🍺 Brew-first package install
- 🧾 Release verification (SHA256 + optional GPG on checksum)
- 🧩 Default skel profile deployment
- 🌃 Starship Tokyo Night preset by default
- 📝 Nano syntax highlighting via nanorc
- 🧱 tmux via Homebrew + oh-my-tmux base config
- 🤖 Optional inference tools (`--install-inference`: ollama + llmfit)
- 🧪 Dry-run support
- 🔎 Verbose debug mode when needed
- ♻️ Safe re-runs (preserves existing files by default)
- 🔒 Single-run lock to prevent concurrent installer collisions
- 📋 Optional machine-readable install report (`--report-json`)

## 🚀 Quick start (local)

```bash
chmod +x install.sh
# preview changes first
./install.sh --dry-run --verbose
# run install
./install.sh -y
```

By default, existing files like `~/.zshrc` are kept as-is.
Use `--override` only when you intentionally want to replace files.
When `--override` modifies an existing config, a `.bak.<date>` backup is created.

## 🌐 Quick start (Pages bootstrap)

```bash
# Latest main branch — one-liner, no version required:
curl -fsSL https://dot.rly.wtf/bootstrap.sh | bash

# Pinned to a specific release (recommended for reproducible installs):
curl -fsSL https://dot.rly.wtf/bootstrap.sh | bash -s -- --tag v1.0.4
```

> **Note:** The tagless form downloads the current `main` branch directly. It skips checksum
> verification and may include unreleased changes. Use `--tag` for a verified, reproducible install.

## 🗂️ Project layout

```text
.
├── bootstrap.sh
├── install.sh
├── inventory/
│   └── default.yaml
├── packages/
│   └── packages.yaml
├── scripts/
│   ├── lib/brew-env.sh
│   ├── setup-pyenv.sh
│   ├── setup-starship.sh
│   └── post-install-checks.sh
├── test/
│   ├── root-configs.sh
│   ├── lib/test-shims.sh
│   ├── backup-collision.sh
│   ├── bootstrap-e2e.sh
│   ├── brew-env.sh
│   ├── installer-lock.sh
│   ├── installer-idempotency.sh
│   ├── tmux-oh-my.sh
│   ├── report-json.sh
│   ├── skel-merge.sh
│   ├── ssh-config-migration.sh
│   ├── inference-opt-in.sh
│   ├── nanorc-optional-failure.sh
│   ├── release-reproducible.sh
│   └── suite.bats
└── skel/
    └── default/
        ├── .zshrc
        ├── .tmux.conf.local
        ├── .gitconfig
        ├── .ssh/config
        └── .config/starship.toml
```

## 📣 Output style

- Standard mode: concise stage updates + status emojis
- `--verbose`: extra `🔎` debug lines
- `--dry-run`: commands are printed with `🧪` and not executed
- Post-install checks use traffic lights (`🟢 / 🟡 / 🔴`)

## ⚙️ Installer flags

- `--tag <tag>`
- `--host <host>` (advanced optional profile name; most users can ignore this)
- `--pyver <ver>`
- `--create-home-pyver`
- `--install-inference` (use with `-y` for non-interactive runs)
- `--dry-run`
- `--override` (`--force` alias)
- `--brew-only`
- `--no-apt`
- `--verbose`
- `--from-release` (set internally by bootstrap)
- `--report-json <path>` (writes a JSON phase summary)
- `--no-lock` (advanced/debug; disables install lock guard)

### 🔐 Security env knobs

- `BOOTSTRAP_GPG_FINGERPRINT` to enforce expected checksum signer fingerprint in `bootstrap.sh`

## 📦 Build a release artifact manually

```bash
TAG=v1.0.0
REPO_NAME="$(basename "$PWD")"
mkdir -p dist
tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
  --exclude='.git' --exclude='./dist' -cf - . | gzip -n > "dist/${REPO_NAME}-${TAG}.tar.gz"
(cd dist && sha256sum "${REPO_NAME}-${TAG}.tar.gz" > "${REPO_NAME}-${TAG}.tar.gz.sha256")
```

Verify deterministic archive output:

```bash
./test/release-reproducible.sh "$TAG"
```

> On macOS, install GNU tar first for deterministic-archive verification:
> `brew install gnu-tar`

## 🧰 Package inventory workflow

`packages/packages.yaml` is the single source of truth for package lists
(`brew` and `apt_minimal` sections).
The default brew set includes core tools like `tmux`, `ripgrep`, `fzf`, and `fd`.

## 🤖 Agentic/Copilot standards

Repository AI guidance lives in `.github/copilot-instructions.md` and includes:

- DRY/minimal change expectations
- Idempotency and safe-default requirements
- Ample, purposeful section/function comments in shell scripts and tests

## 🧠 Migration notes

- Existing files in `$HOME` are preserved by default; `--override` is opt-in.
- Existing `~/.ssh/config` is auto-migrated to `~/.ssh/config.local` when local file is absent;
  managed `~/.ssh/config` then includes `~/.ssh/config.local`.

## ✅ CI tests

GitHub Actions runs a CI workflow that checks:

- shell syntax (`bash -n`)
- shellcheck linting
- no duplicate repo-root shell config files
- installer/bootstrap help output
- installer idempotency behavior (including preserving an existing `.zshrc` on reruns)
- backup collision handling for deterministic `.bak.<date>[.<n>]` naming
- skel directory merge behavior (preserve existing files, copy missing files)
- SSH config include migration behavior (`test/ssh-config-migration.sh`)
- oh-my-tmux bootstrap/preserve/override behavior (`test/tmux-oh-my.sh`)
- installer lock contention behavior (`test/installer-lock.sh`)
- report JSON validity/escaping checks (`test/report-json.sh`)
- inference installer opt-in behavior (`test/inference-opt-in.sh`)
- optional nanorc clone failure handling (`test/nanorc-optional-failure.sh`)
- brew environment resolution scenarios (`test/brew-env.sh`)
- bootstrap end-to-end README curl flow (`test/bootstrap-e2e.sh`)
- DRY BATS installer suite (`test/suite.bats`) running all integration checks
- release reproducibility verification (`test/release-reproducible.sh`, tag workflow)

## 📝 Changelog

Release notes live in [CHANGELOG.md](./CHANGELOG.md).

## 📜 License

Released under **UNLICENSE**. See [UNLICENSE](./UNLICENSE).
