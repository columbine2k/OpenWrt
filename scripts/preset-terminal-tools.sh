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

# Install vim colorscheme (one)
mkdir -p files/usr/share/vim/vim82/colors
git clone --depth=1 https://github.com/rakr/vim-one /tmp/vim-one
cp /tmp/vim-one/colors/one.vim files/usr/share/vim/vim82/colors/
rm -rf /tmp/vim-one
