#!/bin/bash
set -e

#sudo EDITOR=vim visudo
#123099 #Пароль
#%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman

# Обновление системы
sudo pacman -Syu --noconfirm

# # Включение служб
sudo systemctl enable --now reflector.timer
sudo systemctl --user enable --now pipewire.socket
sudo systemctl --user enable --now pipewire-pulse.socket
sudo systemctl --user enable --now wireplumber.service

# Репозиторий AUR и yay
cd
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd
rm yay-bin


tar -xvf "${FILENAME}"
rm "${FILENAME}"

# Обновление системы
sudo pacman -Syu --noconfirm
yay

# Службы для obs-studio
yay -S --noconfirm obs-vkcapture obs-pipewire-audio-capture obs-move-transition obs-backgroundremoval
