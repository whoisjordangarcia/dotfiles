#!/usr/bin/env bash
#
# bootstrap installs things.

set -e

echo ''

info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

user () {
  printf "\r  [ \033[0;33m??\033[0m ] $1\n"
}

success () {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

fail () {
  printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit
}

 
git config --global user.email "arickho@gmail.com"
git config --global user.name "Jordan Garcia"

# If we're on a Mac, let's install and setup homebrew.
if [ "$(uname -s)" == "Darwin" ]
then
  info "On Mac 👾 - installing dependencies"

  ./script/mac_installation.sh


  else 
    info "On Linux 👾 - Install dependencies "

    ./script/linux_installation.sh

fi

 success "dependencies installed"

 echo ''
echo '  All installed! ✨'