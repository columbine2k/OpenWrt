#!/bin/bash

mkdir -p files/root
pushd files/root

# Clone oh-my-zsh repository
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh ./.oh-my-zsh

# Install extra plugins
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ./.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ./.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/zsh-users/zsh-completions ./.oh-my-zsh/custom/plugins/zsh-completions

# Get .zshrc dotfile
cp $GITHUB_WORKSPACE/scripts/.zshrc .

popd

# Get vimrc as system-wide vim config
mkdir -p files/usr/share/vim
cp $GITHUB_WORKSPACE/scripts/vimrc files/usr/share/vim/vimrc

# Install vim plugins (vim-tmux-navigator, lightline)
mkdir -p files/usr/share/vim/vim82/plugin files/usr/share/vim/vim82/autoload files/usr/share/vim/vim82/doc
git clone --depth=1 https://github.com/christoomey/vim-tmux-navigator /tmp/vim-tmux-navigator
git clone --depth=1 https://github.com/itchyny/lightline.vim /tmp/lightline.vim
cp /tmp/vim-tmux-navigator/plugin/tmux_navigator.vim files/usr/share/vim/vim82/plugin/
cp /tmp/vim-tmux-navigator/doc/tmux-navigator.txt files/usr/share/vim/vim82/doc/
cp /tmp/lightline.vim/plugin/lightline.vim files/usr/share/vim/vim82/plugin/
cp -r /tmp/lightline.vim/autoload/lightline.vim /tmp/lightline.vim/autoload/lightline files/usr/share/vim/vim82/autoload/
cp /tmp/lightline.vim/doc/lightline.txt files/usr/share/vim/vim82/doc/
rm -rf /tmp/vim-tmux-navigator /tmp/lightline.vim

# Install vim colorschemes (material, one)
mkdir -p files/usr/share/vim/vim82/colors
git clone --depth=1 https://github.com/kaicataldo/material.vim /tmp/material.vim
git clone --depth=1 https://github.com/rakr/vim-one /tmp/vim-one
cp /tmp/material.vim/colors/material.vim files/usr/share/vim/vim82/colors/
cp /tmp/vim-one/colors/one.vim files/usr/share/vim/vim82/colors/
rm -rf /tmp/material.vim /tmp/vim-one
