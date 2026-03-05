# Canonical zsh configuration lives in skel/default/.zshrc.
# Keep this repo-root file as a thin delegator to avoid config drift.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  _dotfiles_root="${${(%):-%N}:A:h}"
  _canonical_zshrc="${_dotfiles_root}/skel/default/.zshrc"
  if [[ -f "$_canonical_zshrc" ]]; then
    source "$_canonical_zshrc"
  fi
  unset _dotfiles_root _canonical_zshrc
fi
