#!/bin/bash
set -e

# Обновление системы
sudo pacman -Syu --noconfirm

# Установка служб и утилит
sudo pacman -S --noconfirm \
  bluez bluez-utils blueman \
  pipewire pipewire-audio pipewire-pulse pipewire-alsa pipewire-jack wireplumber pavucontrol \
  wl-clipboard grim slurp swappy \
  xdg-user-dirs \
  dbus xdg-desktop-portal xdg-desktop-portal-hyprland \
  thunar thunar-archive-plugin file-roller \
  kitty firefox \
  qt5-wayland qt6-wayland \
  papirus-icon-theme ttf-jetbrains-mono ttf-font-awesome \
  htop curl wget zip unzip man-db man-pages \
  libvirt qemu-guest-agent \
  swww \
  wayland-utils \
  noto-fonts noto-fonts-cjk noto-fonts-emoji \
  brightnessctl playerctl

# Установка Hyprland
sudo pacman -S --noconfirm \
  hyprland hyprpaper hyprlock waybar wofi rofi

# Включение служб
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now dbus-broker
sudo systemctl enable --now bluetooth
sudo systemctl enable --now qemu-guest-agent
sudo systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

# Создание директорий пользователя
xdg-user-dirs-update

echo "==> Установка завершена"
