# Minimal bash compatibility.
# Primary shell/configuration target for this repo is zsh.

case $- in
  *i*) ;;
  *) return ;;
esac

if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi
