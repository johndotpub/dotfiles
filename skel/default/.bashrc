# ~/.bashrc: executed by bash for interactive non-login shells.

TERM=screen-256color

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

PATH="${PATH}:${HOME}/.local/bin:${HOME}/bin"
export PATH

# Homebrew environment (Linux + macOS)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

########
# SSH
########

SSH_ENV="${HOME}/.ssh/environment"

start_agent() {
  echo "Initialising new SSH agent..."
  /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
  chmod 600 "${SSH_ENV}"
  . "${SSH_ENV}" >/dev/null
  /usr/bin/ssh-add
}

if [ -f "${SSH_ENV}" ]; then
  . "${SSH_ENV}" >/dev/null
  if ! ps -ef | grep "${SSH_AGENT_PID:-0}" | grep -q "ssh-agent$"; then
    start_agent
  fi
else
  start_agent
fi

########
# EDITOR
########

export EDITOR=nano
export GIT_EDITOR=nano

########
# PATH / LIBS
########

export PATH="${HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:/usr/local/lib"

########
# RUBY
########

export PATH="${HOME}/.rbenv/bin:${PATH}"
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

########
# NODE
########

export PATH="${HOME}/.nodenv/bin:${PATH}"
if command -v nodenv >/dev/null 2>&1; then
  eval "$(nodenv init -)"
fi

########
# ALIASES
########

export PROJECTS="$(if [ -d "${HOME}/source/" ]; then cd "${HOME}/source/" && ls -d */ | cut -f1 -d'/'; fi)"

alias pull-all='
for P in `echo $PROJECTS`;
  do echo ""; echo "[INFO] ~/source/$P :: git pull origin master";
    cd ~/source/$P && git pull origin master && cd - > /dev/null;
done;
'

alias co-master-all='
for P in `echo $PROJECTS`;
  do echo ""; echo "[INFO] ~/source/$P :: git stash && git checkout master";
    cd ~/source/$P && git stash && git checkout master && cd - > /dev/null;
done;
'

alias p-master-all='
for P in `echo $PROJECTS`;
  do echo ""; echo "[INFO] ~/source/$P :: git stash && git checkout master && git pull";
    cd ~/source/$P && git stash && git checkout master && git pull && cd - > /dev/null;
done;
'

if [ -f "${HOME}/.bash_aliases" ]; then
  . "${HOME}/.bash_aliases"
fi

########
# INTERACTIVE SETTINGS
########

case $- in
  *i*) ;;
  *) return ;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1024000
HISTFILESIZE=1024000
shopt -s checkwinsize

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
