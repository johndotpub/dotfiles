if [ -f "${HOME}/.bashrc" ]; then
  source "${HOME}/.bashrc"
fi

if [ -f "${HOME}/.environment" ]; then
  source "${HOME}/.environment"
fi

# Legacy compatibility: source old bootstrap if present.
if [ -r "${HOME}/.dot/bootstrap/startup.sh" ]; then
  source "${HOME}/.dot/bootstrap/startup.sh"
fi

export PATH="/usr/local/sbin:${PATH}"
