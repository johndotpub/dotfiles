# ✨ dotfiles (brew-first bootstrap)

Clean, straightforward dotfiles setup for Linux/WSL:

- 🍺 Brew-first package install
- 🧾 Release verification (SHA256 + optional GPG on checksum)
- 🧩 Default skel profile deployment
- 🌃 Starship Tokyo Night preset by default
- 📝 Nano syntax highlighting via nanorc
- 🤖 Optional inference tools (`--install-inference`: ollama + llmfit)
- 🧪 Dry-run support
- 🔎 Verbose debug mode when needed
- ♻️ Safe re-runs (preserves existing files by default)

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
curl -fsSL https://dot.rly.wtf/bootstrap.sh | bash -s -- --tag v1.0.0
```

## 🗂️ Project layout

```text
.
├── bootstrap.sh
├── install.sh
├── inventory/
│   └── default.yaml
├── packages/
│   ├── brew-packages.txt
│   └── apt-minimal.txt
├── scripts/
│   ├── lib/brew-env.sh
│   ├── setup-pyenv.sh
│   ├── setup-starship.sh
│   └── post-install-checks.sh
└── skel/
    └── default/
        ├── .zshrc
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
- `--install-inference`
- `--dry-run`
- `--override` (`--force` alias)
- `--brew-only`
- `--no-apt`
- `--verbose`
- `--from-release` (set internally by bootstrap)

## 📦 Build a release artifact manually

```bash
TAG=v1.0.0
REPO_NAME="$(basename "$PWD")"
mkdir -p dist
tar -czf "dist/${REPO_NAME}-${TAG}.tar.gz" --exclude='.git' .
(cd dist && sha256sum "${REPO_NAME}-${TAG}.tar.gz" > "${REPO_NAME}-${TAG}.tar.gz.sha256")
```

## 🧠 Migration notes

- `.dot/bootstrap` references have been removed.
- This repo is intentionally zsh-first and keeps Bash config minimal.
- Existing files in `$HOME` are preserved by default; `--override` is opt-in.

## ✅ CI tests

GitHub Actions runs a CI workflow that checks:

- shell syntax (`bash -n`)
- shellcheck linting
- installer/bootstrap help output
- installer idempotency behavior (including preserving an existing `.zshrc` on reruns)

## 📝 Changelog

Release notes live in [CHANGELOG.md](./CHANGELOG.md).

## 📜 License

Released under **UNLICENSE**. See [UNLICENSE](./UNLICENSE).
