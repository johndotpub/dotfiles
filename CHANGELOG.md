# Changelog 📝

All notable changes to this project are documented here.

## [v1.0.7] 🔧

### Changed 🔄
- 📦 **Package management refactored** (closes #13): `packages/packages.yaml` removed. `packages/brew.yaml`
  (organized sections: `base`, `development`, `navigation`, `networking`, `system`, `media`, `security`,
  `inference`, `optional`) and `packages/apt.yaml` (`apt_minimal` section) are now the sources of truth.
  All brew.yaml sections are installed by default; inference tools (ollama, llama.cpp, llmfit) are now
  plain brew packages — no remote curl installers.
- 🔐 **sudo warmup fixed** (closes #15): `sudo -v` warmup now runs for all flows (including `--brew-only`
  and `--no-apt`), since `chsh` and `/etc/shells` registration always require sudo regardless of apt mode.
  Previously, `--no-apt` skipped the warmup, causing a password prompt late in the run.
- 🧹 **DRY-1**: Shared helpers (`info`, `ok`, `warn`, `err`, `debug`, `run`, `format_cmd`, `timestamp`,
  `next_backup_path`, `backup_path`, `backup_copy`) extracted to `scripts/lib/helpers.sh`; sourced by
  `install.sh` and `scripts/setup-starship.sh` instead of being inlined.
- 🧹 **DRY-2**: `copy_item()` removed; all call sites replaced with `run cp -Rp` directly.
- 🧹 **DRY-4**: `write_sudo_shim` is now called inside `setup_common_fake_bin()` so all integration
  tests consistently sandbox sudo without needing individual setup calls.
- 🧹 **DRY-5**: `json_escape()` simplified from a 29-line od/awk loop to a 1-line `sed` + `tr` pipeline
  that escapes backslash and double-quote and strips ASCII control characters (0x00–0x1F).
- 🧹 **DRY-6**: `run_preflight_checks()` trimmed to check only `git` and `curl`; POSIX baseline tools
  (`bash`, `awk`, `cp`, `mv`, `tar`) removed as they are always present. Missing `git`/`curl` are now
  warnings (not fatal) when apt is available to self-bootstrap them; fatal only under `--no-apt`/`--brew-only`.
- 🧹 **DRY-7**: `install_brew_from_yaml()` and `install_apt_from_yaml()` merged into a single
  `install_pkgs_from_yaml(file, section, mgr)` function. Added `list_yaml_sections()` helper.
- 🗑️ `--install-inference` flag deprecated (accepted but warns); `INSTALL_INFERENCE` variable and
  `run_remote_install_script()` function removed from `install.sh`, `bootstrap.sh`, and
  `scripts/lib/install-flags.sh`.
- 🗑️ `install_inference` key removed from `inventory/default.yaml`.

### Added ✨
- 📋 **Round 4 backup accumulation test** (closes #14): `test/backup-accumulation.sh` extended to 4
  rounds, directly validating: 3 runs → 2 `.bak.*` files, 4 runs → 3 `.bak.*` files.
- 🔐 **`test/sudo-single-prompt.sh`**: new integration test asserting `sudo -v` is invoked exactly once
  per installer run, regardless of `--brew-only` / `--no-apt` mode.
- 📦 **`test/brew-package-sections.sh`**: new test asserting all brew.yaml sections are installed on a
  normal run and that apt_minimal packages are skipped when `--brew-only` is set.

### Removed 🗑️
- `packages/packages.yaml` deleted (replaced by `packages/brew.yaml` and `packages/apt.yaml`).
- `test/inference-opt-in.sh` replaced by `test/brew-package-sections.sh`.

## [v1.0.6] 🔀

### Changed 🔄
- 🔀 **`--tag` removed; replaced by `--ref`** in `bootstrap.sh` and `install.sh` — accepts release
  tags and branch names.
- 🔍 **3-way ref resolution** in `bootstrap.sh` replaces the binary tag/main-branch split:
  1. **Branch** — HEAD probe to `refs/heads/{ref}` returns 200 → archive download, checksum skipped.
  2. **Release tag** — HEAD probe to release asset returns 200 → full download + SHA256 + optional GPG.
  3. **Tag archive fallback** — ref not found as branch or release → `refs/tags/{ref}` archive, checksum skipped with warning.
  No string-shape guessing; the server decides the ref type.
- 🔒 **Checksum policy clarified**: SHA256 + GPG verification for release tags only; non-release refs
  emit `⚠️  Skipping checksum verification for non-release ref` and proceed.
- 📋 **`--report-json` field renamed**: `"tag"` → `"ref"` in the JSON phase report.
- 🌐 **`BOOTSTRAP_ARCHIVE_BASE`** env override added for integration tests (parallel to the
  existing `BOOTSTRAP_RELEASE_BASE`), enabling fully offline ref-detection probes.
- 🆕 **`skel/default/.zshenv` added** — minimal environment setup for all zsh modes (PATH, Linuxbrew,
  pyenv). Deployed to `~/.zshenv` via `deploy_skel_profile`; respects `--preserve` and idempotency.
- 🔒 **SSH `config.local` backup safety** — `migrate_ssh_config_include_local` backs up any
  pre-existing `~/.ssh/config.local` before overwriting; `--preserve` skips migration entirely.
- ♻️ **DRY flag registry** — `scripts/lib/install-flags.sh` is the single source of truth for
  `build_install_args`; `bootstrap.sh` sources it from the extracted repo after each download path.

### Fixed 🐛
- 🐛 **`build_install_args` set -e safety** — the function now always exits 0 under
  `set -euo pipefail`, preventing bootstrap from aborting before `./install.sh` is reached
  when no optional flags are set.
- 🐛 **`test/inference-opt-in.sh` stdin hang** — `run_install_no_yes` now passes `< /dev/null`.

### Tests ✅
- 🧪 `bootstrap-e2e.sh`: updated to `--ref`; adds `BOOTSTRAP_ARCHIVE_BASE` for offline branch probe.
- 🧪 `bootstrap-main-fallback.sh`: updated grep check for new `--ref` warning message.
- 🧪 `report-json.sh`: uses `--ref`; validates `"ref"` field in JSON output; renames `TAG_WITH_CONTROLS` → `REF_WITH_CONTROLS`.
- 🧪 All other installer test scripts updated from `--tag` to `--ref`.
- 🧪 New `test/bootstrap-ref-branch.sh`: asserts branch ref resolves to archive URL, skips checksum.
- 🧪 `suite.bats`: added `bootstrap: branch ref resolves to archive` test entry; renamed main-fallback entry.
- 🧪 `installer-idempotency.sh`: extended with `.zshenv` and `.gitconfig` backup + content replacement verification.
- 🧪 `preserve-flag.sh`: extended with `.zshenv` unchanged-content assertion.
- 🧪 `shell-templates.sh`: asserts `~/.zshenv` deployed on fresh install.
- 🧪 `ssh-config-migration.sh`: new Scenario 7 — `--preserve` leaves both `~/.ssh/config` and `~/.ssh/config.local` untouched.
## [v1.0.5] 🛠️

### Fixed 🐛
- 🔄 **Default deploy behaviour flipped** — existing files are now backed up to `.bak.<date>` and replaced with fresh skel copies by default.  Use `--preserve` to keep existing files untouched (the former default behaviour, now explicit).
  - Removes `--override` / `--force` / `-f` flags entirely — no deprecated aliases needed.
  - Adds `--preserve` flag (`PRESERVE=0` by default, set to `1` to opt out of replacement).
  - **Idempotent reruns**: if the deployed file already matches skel exactly, the backup and copy are skipped — no spurious `.bak` files on reruns.
  - All deploy sites updated: `deploy_skel_profile`, `configure_starship_prompt` (via `setup-starship.sh`), `configure_oh_my_tmux`, `configure_nano_syntax`, `migrate_ssh_config_include_local`, `~/.python-version`.
- 🐚 **`bootstrap.sh` no longer silently drops unrecognised flags** — added `--preserve`, `--verbose`, `--create-home-pyver`, `--install-inference`, `--report-json <path>`, `--no-lock` to the bootstrap argument parser and forwarded to `install.sh`.
- 🔒 **Sudo keepalive loop fixed** — replaced `read -r -t 50 _ || true` with `sleep 50` to prevent the keepalive subshell from spinning at 100 % CPU when stdin is closed in a `curl | bash` pipe.

### Changed 🔄
- 🗑️ **`--report-json` field renamed**: `"override"` key renamed to `"preserve"` to match the new flag.
- 🧹 **DRY: `scripts/post-install-checks.sh`** rewritten to match `print_checks` verbatim (traffic-light emoji output, same per-tool conditionals).  `install.sh` delegates to the script instead of duplicating the function.
- 🧹 **DRY: `scripts/setup-starship.sh`** rewritten to match `configure_starship_prompt` exactly, accepting `PRESERVE`, `DRY_RUN`, `VERBOSE`, `SKEL_DIR`, `SKEL_PROFILE` env vars.  `install.sh` delegates to the script.
- 🧹 **DRY: deleted `scripts/setup-pyenv.sh`** — fully redundant with `packages.yaml` brew installs.
- 🧹 **DRY: brew-candidates block extracted** to `skel/default/.config/brew-init.sh`.  Both `.zshrc` and `.bashrc` source it instead of duplicating the ~20-line block.
- 🧹 **DRY: HTTP server helper extracted** — `start_http_server <dir>` added to `test/lib/test-shims.sh`.  Duplicated port-finder + server startup blocks removed from `test/bootstrap-e2e.sh` and `test/bootstrap-main-fallback.sh`.

### Tests ✅
- 🧪 `installer-idempotency.sh`: updated to assert backup-and-replace on first run; content-equality idempotency on rerun; `--preserve` keeps files unchanged.
- 🧪 `tmux-oh-my.sh`: updated to assert default backup-and-replace; `--preserve` keeps existing config.
- 🧪 `backup-semantics.sh`: updated to use default mode (no flag needed) instead of `--override`.
- 🧪 `backup-collision.sh`: updated to use default mode with mutations between runs.
- 🧪 `report-json.sh`: updated required key from `"override"` to `"preserve"`.
- 🧪 `shell-templates.sh`: updated brew candidate checks to point at `skel/default/.config/brew-init.sh`.
- 🧪 New `test/preserve-flag.sh` + `suite.bats` entry: asserts `--preserve` keeps existing files unchanged with no backups created.

## [v1.0.4] 🔐

### Fixed ✅
- 🔐 SSH config migration now backs up any pre-existing `~/.ssh/config.local` before writing migrated content, preventing silent clobbering.
- 🔐 SSH migration sanitizes self-referencing `Include ~/.ssh/config.local` and its preceding comment from migrated content to prevent recursive include loops on rerun.
- 🔐 SSH migration uses an idempotency guard (presence of `Include ~/.ssh/config.local` in `~/.ssh/config`) instead of only checking for `config.local` existence, preventing repeated re-migration on reruns.
- 🐚 Shell change flow now registers the Homebrew-installed zsh path in `/etc/shells` via `sudo` before calling `chsh`, ensuring `chsh` accepts the path on Linux.
- 🐚 Shell change `warn` and help output is now emitted near the end of script output (after the install summary), improving output readability.
- 🔒 `sudo -n` flag is now applied to the `tee -a /etc/shells` call, not only to the guard check, closing a TOCTOU window that could prompt interactively on some systems.
- 🌐 Bootstrap tagless warning now shows `--tag <release-tag>` instead of a hardcoded version, preventing a stale hint after every release.
- 🧪 Portable test: `test/bootstrap-main-fallback.sh` now uses a staging-directory approach instead of GNU-only `tar --transform`, fixing CI on macOS (`bsdtar`).
- 📝 SSH config migration comment updated to accurately describe the create-sanitized-copy-then-remove-original behavior.

### Changed 🔄
- 🔒 `sudo -v` warmup is performed immediately after the installer starts so interactive sudo prompts appear upfront rather than mid-run.
- 🔒 A background `sudo` keepalive loop is spawned for the script lifetime and cleaned up on exit via trap, removing the need for password re-entry on long installs.
- 🔒 Sudo keepalive loop now uses `read -r -t 50` (shell builtin timed wait) instead of `sleep 50`, avoiding orphaned background processes after the keepalive subshell is killed.
- 📦 README version references updated to `v1.0.4` (badge from `v1.0.2`, bootstrap example from `v1.0.3`).

### Tests ✅
- 🧪 New `test/backup-semantics.sh` closes the only gap in backup coverage: `backup_copy` (used by nanorc `--override`) was never exercised.
  - Asserts `backup_path` move semantics: original moved to `.bak.<ts>`, skel replacement deployed, original content preserved in backup.
  - Asserts `backup_copy` keep-in-place semantics: original file stays at its path, `.bak.<ts>` copy is also created, include line is appended.
  - Uses `DOTFILES_TEST_TIMESTAMP` to freeze time for deterministic backup filenames.
- 🧪 Removed duplicate test body from `test/bootstrap-main-fallback.sh` that ran the full bootstrap flow twice.

## [v1.0.2] 🛠️

### Fixed ✅
- 🍺 Homebrew bootstrap initialization now reliably resolves Linuxbrew/macOS paths after installer bootstrap.
- 🧪 `setup_brew_env` now treats failed `brew shellenv` calls as real failures (no false-positive success on `eval`).

### Changed 🔄
- 🧰 Consolidated brew env coverage into one DRY scenario suite (`test/brew-env.sh`) instead of multiple near-duplicate scripts.
- 🗂️ Standardized test filenames to concise, consistent names and switched the BATS entrypoint to `test/suite.bats`.
- 🌐 Reworked bootstrap E2E coverage to mirror README curl usage (`curl .../bootstrap.sh | bash -s -- --tag ...`) against the active PR payload in CI.
- ⚙️ CI trigger behavior now avoids duplicate branch runs by limiting push-triggered CI to `main` while PR validation runs on `pull_request`.

## [v1.0.1] 🎉

### Added ✨
- 🧱 New dotfiles bootstrap/install system with clear repo layout (`install.sh`, `bootstrap.sh`, `packages/`, `inventory/`, `skel/`, `test/`, CI workflows).
- 🍺 Brew-first installer with inventory-driven package selection (`packages/packages.yaml`) and apt fallback support.
- 🧩 Idempotent, preserve-by-default config deployment with explicit `--override` backups (`.bak.<date>[.<n>]`).
- 🔧 Core installer ergonomics:
  - `--dry-run`, `--verbose`, `--report-json`, and installer lock protection
  - preflight checks and traffic-light post-install status output
- 🔐 Verified bootstrap flow:
  - SHA256 artifact verification
  - optional GPG checksum signature verification with optional signer fingerprint pin (`BOOTSTRAP_GPG_FINGERPRINT`)
- 🐚 Zsh-first default environment with Oh My Zsh plugin baseline (`git pyenv python pip tmux`, plus conditional `fzf`/`sudo`).
- 🌃 Prompt/editor/dev UX defaults:
  - Starship Tokyo Night preset
  - Nano as default git editor + nanorc setup (graceful if nanorc clone fails)
  - tmux + oh-my-tmux bootstrap with `~/.tmux.conf.local` overrides
- 🔑 SSH safety migration:
  - managed `~/.ssh/config` includes `~/.ssh/config.local`
  - existing user `~/.ssh/config` auto-migrates to `config.local` when needed
- 🤖 Optional inference tools via explicit opt-in only (`--install-inference` for ollama + llmfit, with interactive confirmation unless `-y`).
- ✅ CI/release quality gates with DRY BATS integration suite covering idempotency, backups, merge behavior, SSH migration, tmux behavior, lock contention, JSON report validity, inference opt-in, nanorc failure handling, and reproducibility checks.
- 📦 Deterministic release artifact creation (`gzip -n` + normalized tar metadata) with checksum/signature publishing.
- 📜 Project standards/docs baseline:
  - canonical `UNLICENSE`
  - consolidated changelog
  - Copilot/agent instructions + PR template
