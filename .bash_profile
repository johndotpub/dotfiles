if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

if [ -f ~/.environment ]; then
   source ~/.environment
fi

export DOTDIR=`cd; pwd`/.dot
source "$DOTDIR/bootstrap/startup.sh"
export PATH="/usr/local/sbin:$PATH"
