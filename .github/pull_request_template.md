## 🚀 Summary

<!-- What changed and why? Keep it concise. -->

## ✨ Highlights

- [ ] 🌃 Starship Tokyo Night preset behavior covered
- [ ] 📝 Nano + nanorc behavior covered
- [ ] ♻️ Idempotency/rerun safety preserved
- [ ] 🔧 Existing configs preserved by default

## 🧪 Validation

<!-- Paste command outputs or check all that apply -->

- [ ] `bash -n install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh`
- [ ] `shellcheck -x install.sh bootstrap.sh scripts/*.sh scripts/lib/*.sh`
- [ ] `./install.sh --help`
- [ ] `./bootstrap.sh --help`
- [ ] `./install.sh --dry-run --no-apt --brew-only --yes --verbose`
- [ ] `./scripts/test-installer-idempotency.sh`

## 📚 Docs / Changelog

- [ ] README updated (if behavior changed)
- [ ] CHANGELOG updated
- [ ] Copilot instructions reviewed/updated if needed

## ⚠️ Risks / Notes

<!-- Anything reviewers should pay special attention to -->

## ✅ Checklist

- [ ] Code is minimal and DRY
- [ ] No nonstandard shell assumptions added
- [ ] Override behavior creates `.bak.<date>` backups
- [ ] Existing configs are preserved by default
