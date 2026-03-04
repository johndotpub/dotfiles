# dotfiles (brew-first bootstrap)

This repo contains a brew-first, idempotent bootstrap for Linux/WSL with:

- A release-verifying `bootstrap.sh`
- An installer with dry-run/force/profile flags
- Inventory + skel profiles
- Package manifests for brew and minimal apt fallback

## Layout

```text
.
├── bootstrap.sh
├── install.sh
├── inventory/
│   ├── default.yaml
│   └── hosts/laptop.yaml
├── packages/
│   ├── brew-packages.txt
│   └── apt-minimal.txt
├── scripts/
│   ├── setup-pyenv.sh
│   ├── setup-starship.sh
│   └── post-install-checks.sh
└── skel/
    └── default/
        ├── .bash_profile
        ├── .bashrc
        ├── .zshrc
        ├── .profile
        ├── .gitconfig
        ├── .ssh/config
        └── .config/starship.toml
```

## Local install

```bash
chmod +x install.sh
./install.sh --host laptop --pyver 3.12.12 --dry-run
./install.sh --host laptop --pyver 3.12.12 -y
```

## Release-verified bootstrap

```bash
curl -fsSL https://your.domain.example/bootstrap.sh | bash -s -- --tag v1.0.0 --host laptop
```

`bootstrap.sh` downloads release assets, verifies SHA256, optionally verifies GPG signature for the checksum file, then runs `install.sh`.

## Installer flags

- `--tag <tag>`
- `--host <host>`
- `--pyver <ver>`
- `--create-home-pyver`
- `--install-inference`
- `--dry-run`
- `--force`
- `--brew-only`
- `--no-apt`
- `--verbose`
- `--from-release` (set internally by bootstrap)

## Build a release artifact manually

```bash
TAG=v1.0.0
REPO_NAME="$(basename "$PWD")"
mkdir -p dist
tar -czf "dist/${REPO_NAME}-${TAG}.tar.gz" --exclude='.git' .
(cd dist && sha256sum "${REPO_NAME}-${TAG}.tar.gz" > "${REPO_NAME}-${TAG}.tar.gz.sha256")
```

## Notes on migration from old `.skel`

- Legacy Bash startup behavior is preserved under `skel/default/.bashrc` and `.bash_profile`.
- Optional old bootstrap handoff is still supported if `~/.dot/bootstrap/startup.sh` exists.
- Existing files in `$HOME` are backed up by default as `*.bak.<timestamp>`.
