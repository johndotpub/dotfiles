# .bashrc

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

TERM=screen-256color

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment and startup programs

WHOAMI=`whoami`

PATH=$PATH:$HOME/.local/bin:$HOME/bin
PATH="/usr/local/heroku/bin:$PATH"
export PATH

########
# SSH
########

SSH_ENV="$HOME/.ssh/environment"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo succeeded
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add;
}

# Source SSH settings, if applicable
if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    # ps ${SSH_AGENT_PID} doesn't work under cywgin
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi

########
# EDITOR
########

export EDITOR=nano
export GIT_EDITOR=nano

########
# PATH
########

export PATH="$HOME/bin:$PATH"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

########
# RUBY
########

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

########
# NODE
########

export PATH="$HOME/.nodenv/bin:$PATH"
eval "$(nodenv init -)"

########
# ALIAS
########

export PROJECTS="$(if [ -d ~/source/ ]; then cd ~/source/; ls -d */ | cut -f1 -d'/'; fi)"

alias pull-all='
 for P in `echo $PROJECTS`;
   do echo ''; echo "[INFO] ~/source/$P :: git pull origin master";
     cd ~/source/$P && git pull origin master && cd - > /dev/null;
 done;
'

alias co-master-all='
 for P in `echo $PROJECTS`;
   do echo ''; echo "[INFO] ~/source/$P :: git stash && git checkout master";
     cd ~/source/$P && git stash && git checkout master && cd - > /dev/null;
 done;
'

alias p-master-all='
 for P in `echo $PROJECTS`;
   do echo ''; echo "[INFO] ~/source/$P :: git stash && git checkout master && git pull";
     cd ~/source/$P && git stash && git checkout master && git pull && cd - > /dev/null;
 done;
'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

########
# MISC
########

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1024000
HISTFILESIZE=1024000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    screen-256color) color_prompt=yes;;
esac

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
