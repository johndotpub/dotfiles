# ✨ dotfiles (brew-first bootstrap)

Clean, straightforward dotfiles setup for Linux/WSL:

- 🍺 Brew-first package install
- 🧾 Release verification (SHA256 + optional GPG on checksum)
- 🧩 Default skel profile deployment
- 🧪 Dry-run support
- 🔎 Verbose debug mode when needed
- ♻️ Safe re-runs (preserves existing files by default)

## 🚀 Quick start (local)

```bash
chmod +x install.sh
./install.sh --dry-run --verbose
./install.sh -y
```

By default, existing files like `~/.zshrc` are kept as-is.
Use `--force` only when you intentionally want to replace files.

## 🌐 Quick start (Pages bootstrap)

```bash
curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.0.0
```

Optional if you add extra host overlays later:

```bash
curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.0.0 --host <name>
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
- `--host <host>` (optional; only if `inventory/hosts/<host>.yaml` exists)
- `--pyver <ver>`
- `--create-home-pyver`
- `--install-inference`
- `--dry-run`
- `--force`
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
- Existing files in `$HOME` are preserved by default; `--force` is opt-in.

## ✅ CI tests

GitHub Actions runs a CI workflow that checks:

- shell syntax (`bash -n`)
- installer/bootstrap help output
- installer idempotency behavior (including preserving an existing `.zshrc` on reruns)

## 📜 License

Released under the **Unlicense**. See [LICENSE](./LICENSE).
