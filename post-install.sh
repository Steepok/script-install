#!/bin/bash
set -e

#sudo EDITOR=vim visudo
#123099 #Пароль
#%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman

# Обновление системы
sudo pacman -Syu --noconfirm

# Репозиторий AUR и yay
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si
cd

# Устаеовка tor-browser
wget https://www.torproject.org/dist/torbrowser/14.5.4/tor-browser-linux-x86_64-14.5.4.tar.xz
tar -xvf tor-browser-linux-x86_64-14.5.4.tar.xz
rm tor-browser-linux-x86_64-14.5.4.tar.xz

