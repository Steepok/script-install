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
FILEID="1R5ojcF9MGElNC3W9R1NrLdI816wfefRi"
FILENAME="tor-browser-linux-x86_64-14.5.5.tar.xz"
wget --save-cookies cookies.txt 'https://docs.google.com/uc?export=download&id='$FILEID -O- \
  | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p' \
  | xargs -I{} wget --load-cookies cookies.txt "https://docs.google.com/uc?export=download&confirm={}&id=$FILEID" -O $FILENAME
rm -f cookies.txt

tar -xvf "${FILENAME}"
rm "${FILENAME}"

# Обновление системы
sudo pacman -Syu --noconfirm
yay
