# ✨A brew-first and zsh-focused toolkit

[![Release](https://img.shields.io/github/v/release/johndotpub/dotfiles?style=flat-square)](https://github.com/johndotpub/dotfiles/releases) [![CI](https://img.shields.io/github/actions/workflow/status/johndotpub/dotfiles/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/johndotpub/dotfiles/actions/workflows/ci.yml) [![Tests](https://img.shields.io/badge/tests-BATS-4fd1c5?style=flat-square)](https://github.com/bats-core/bats-core) [![UNLICENSE](https://img.shields.io/badge/license-UNLICENSE-blue.svg?style=flat-square)](./UNLICENSE)  
[![Shell Zsh](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square)](https://www.zsh.org/) [![Framework Oh My Zsh](https://img.shields.io/badge/framework-Oh%20My%20Zsh-4fd1c5?style=flat-square)](https://ohmyz.sh/) [![Prompt Starship](https://img.shields.io/badge/prompt-starship-7aa2f7?style=flat-square)](https://starship.rs/) [![Python Pyenv](https://img.shields.io/badge/python-pyenv-3776ab?style=flat-square)](https://github.com/pyenv/pyenv)  
[![Package Manager Homebrew](https://img.shields.io/badge/package%20manager-Homebrew-fbb040?style=flat-square)](https://brew.sh/) [![SHA256 Verified](https://img.shields.io/badge/verified-SHA256-23d18b?style=flat-square)](https://github.com/johndotpub/dotfiles/releases) [![Lint ShellCheck](https://img.shields.io/badge/lint-shellcheck-ffd43b?style=flat-square)](https://www.shellcheck.net/) [![Platform Linux/macOS/WSL](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-1793d1?style=flat-square)](https://github.com/johndotpub/dotfiles/actions/workflows/ci.yml)

Clean, straightforward dotfiles setup for Linux, macOS, and WSL:

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
- ♻️ Safe re-runs (backup-and-replace by default; use `--preserve` to keep existing files)
- 🔒 Single-run lock to prevent concurrent installer collisions
- 🔐 One upfront sudo prompt for privileged install + shell-switch work
- 📋 Optional machine-readable install report (`--report-json`)

## 🚀 Quick start (local)

```bash
chmod +x install.sh
# preview changes first
./install.sh --dry-run --verbose
# run install
./install.sh -y
```

By default, existing files like `~/.zshrc` are backed up to `.bak.<date>` and replaced with fresh skel copies.
If the deployed file already matches skel exactly, the backup and copy are skipped (idempotent reruns).
Use `--preserve` to keep existing files unchanged without any backups.

## 🌐 Quick start (Pages bootstrap)

```bash
# Latest main branch — one-liner, no version required:
curl -fsSL https://dot.rly.wtf/bootstrap.sh | bash

# Pinned to a specific release (recommended for reproducible installs):
curl -fsSL https://dot.rly.wtf/bootstrap.sh | bash -s -- --ref v1.0.7

# Branch (unverified):
curl -fsSL https://dot.rly.wtf/bootstrap.sh | bash -s -- --ref my-branch
```

> **Note:** The refless form downloads the current `main` branch directly. It skips checksum
> verification and may include unreleased changes. Use `--ref` with a release tag for a verified,
> reproducible install. Branches are also supported but skip checksum verification.

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
│   ├── lib/install-flags.sh
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
│   ├── preserve-flag.sh
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
        ├── .zshenv
        ├── .tmux.conf.local
        ├── .gitconfig
        ├── .ssh/config
        └── .config/
            ├── brew-init.sh
            └── starship.toml
```

## 📣 Output style

- Standard mode: concise stage updates + status emojis
- `--verbose`: extra `🔎` debug lines
- `--dry-run`: commands are printed with `🧪` and not executed
- Post-install checks use traffic lights (`🟢 / 🟡 / 🔴`)

## ⚙️ Installer flags

- `--ref <ref>` (release tag or branch; release tags get checksum verification)
- `--host <host>` (advanced optional profile name; most users can ignore this)
- `--pyver <ver>`
- `--create-home-pyver`
- `--install-inference` (use with `-y` for non-interactive runs)
- `--dry-run`
- `--preserve` (keep existing files untouched; opt out of backup-and-replace)
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

## 🤖 Agentic standards

Repository AI guidance lives in [`AGENTS.md`](AGENTS.md) and includes:

- DRY/minimal change expectations
- Idempotency and safe-default requirements
- Ample, purposeful section/function comments in shell scripts and tests

## 🧠 Migration notes

- Existing files in `$HOME` are backed up to `.bak.<date>` and replaced with fresh skel copies by default.
  If the deployed file already matches skel exactly, the backup and copy are skipped.
  Use `--preserve` to keep existing files unchanged.
- `~/.zshenv` is deployed from `skel/default/.zshenv` via the same `deploy_skel_profile` path as
  `.zshrc`; it respects `--preserve` and idempotency in the same way.
- Existing `~/.ssh/config` is auto-migrated to `~/.ssh/config.local` when local file is absent;
  managed `~/.ssh/config` then includes `~/.ssh/config.local`.
  If `~/.ssh/config.local` already exists it is backed up before migration.
  `--preserve` skips the SSH migration entirely, leaving both files untouched.

## ✅ CI tests

GitHub Actions runs a CI workflow that checks:

- shell syntax (`bash -n`)
- shellcheck linting
- no duplicate repo-root shell config files
- installer/bootstrap help output
- installer idempotency behavior (backup-and-replace by default; no new backups when file matches skel)
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
