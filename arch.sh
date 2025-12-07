#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Простая конфигурация. Измени при необходимости перед запуском.
###############################################################################
DEVICE="/dev/vda"          # Твой диск (у меня NVMe). ЗАМЕНИТЕ ЕСЛИ НУЖНО.
EFI_SIZE="+512M"
SWAP_SIZE="+5G"
ROOT_SIZE="+30G"              # если хочешь другой — измени
USERNAME="user"
PASSWORD="1234567825"       # рекомендуется изменить перед запуском
HOSTNAME="computer"

###############################################################################
# Подготовка — синхронизация времени, mirrors (опционально)
###############################################################################
timedatectl set-ntp true

# Увеличим parallel downloads локально в live-окружении (не критично)
sed -i 's/^ParallelDownloads = .*$/ParallelDownloads = 10/' /etc/pacman.conf || true

###############################################################################
# Разметка диска (GPT): EFI | swap | root | home
###############################################################################
sgdisk --zap-all "${DEVICE}"
sgdisk -n 1:0:${EFI_SIZE}   -t 1:ef00 "${DEVICE}"   # EFI
sgdisk -n 2:0:${SWAP_SIZE}  -t 2:8200 "${DEVICE}"   # swap
sgdisk -n 3:0:${ROOT_SIZE}  -t 3:8300 "${DEVICE}"   # / (root)
sgdisk -n 4:0:0            -t 4:8300 "${DEVICE}"   # /home (оставшееся)

# Форматирование
mkfs.vfat -F32 "${DEVICE}1"
mkswap "${DEVICE}2"
swapon "${DEVICE}2"
mkfs.ext4 -F "${DEVICE}3"
mkfs.ext4 -F "${DEVICE}4"

# Монтирование
mount "${DEVICE}3" /mnt
mkdir -p /mnt/boot/efi
mount "${DEVICE}1" /mnt/boot/efi
mkdir -p /mnt/home
mount "${DEVICE}4" /mnt/home

###############################################################################
# Установка базовой системы и пакетов (включая Hyprland и зависимости)
# Основные пакеты: base, linux, grub, NetworkManager, hyprland, mesa, pipewire ...
###############################################################################
pacstrap -K /mnt base base-devel linux linux-firmware \
  linux-headers vim sudo git networkmanager \
  grub efibootmgr wget curl \
  mesa vulkan-radeon libva-mesa-driver \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  hyprland hyprpaper waybar kitty firefox polkit seatd \
  openbsd-netcat reflector os-prober

# Примечание: пакеты hyprland и xdg-desktop-portal-hyprland доступны в официальных репозиториях Arch. :contentReference[oaicite:1]{index=1}

###############################################################################
# fstab
###############################################################################
genfstab -U /mnt >> /mnt/etc/fstab

###############################################################################
# Копируем in-chroot скрипт и chroot'имся
###############################################################################
cat > /mnt/in-chroot.sh <<"EOF"
#!/usr/bin/env bash
set -euo pipefail

# Переменные внутри chroot (при необходимости менять)
HOSTNAME="__HOSTNAME__"
USERNAME="__USERNAME__"
PASSWORD="__PASSWORD__"

# Локали
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

sed -i 's/^#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen || true
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Консоль
cat > /etc/vconsole.conf <<VCON
KEYMAP=ru
FONT=cyr-sun16
VCON

# Hostname и hosts
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# Пароли и пользователь
echo "root:${PASSWORD}" | chpasswd
useradd -m -G wheel,audio,video -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Разрешаем sudo для wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# mkinitcpio
if command -v mkinitcpio >/dev/null 2>&1; then
  mkinitcpio -P
fi

# Установка и конфигурация GRUB (UEFI)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch || true
grub-mkconfig -o /boot/grub/grub.cfg

# Службы
systemctl enable NetworkManager
systemctl enable seatd
systemctl enable systemd-timesyncd
# bluetooth включай если нужно:
systemctl enable bluetooth

# Обновление пакетов
pacman -Syu --noconfirm

# Настройка xdg-user-dirs для пользователя
export USERHOME="/home/${USERNAME}"
runuser -l ${USERNAME} -c 'xdg-user-dirs-update || true'

# Установка flatpak (опционально) и добавление flathub
pacman -S --noconfirm flatpak
runuser -l ${USERNAME} -c 'flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true'

# Настройка polkit (минимально) — убедись, что polkit установлен
cat > /etc/polkit-1/rules.d/49-wheel-all.rules <<POL
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POL

# Очистка
echo "Установка внутри chroot завершена."
EOF

# Подставим реальные переменные
sed -i "s|__HOSTNAME__|${HOSTNAME}|g" /mnt/in-chroot.sh
sed -i "s|__USERNAME__|${USERNAME}|g" /mnt/in-chroot.sh
# Экранируем слэши в пароле
ESC_PASS=$(printf '%s\n' "${PASSWORD}" | sed -e 's/[\/&]/\\&/g')
sed -i "s|__PASSWORD__|${ESC_PASS}|g" /mnt/in-chroot.sh

chmod +x /mnt/in-chroot.sh

# Входим в chroot и выполняем
arch-chroot /mnt /in-chroot.sh

# Удаляем скрипт
rm /mnt/in-chroot.sh

# Отмонтирование и перезагрузка
umount -R /mnt
swapoff -a || true

echo "Установка завершена. Система будет перезагружена."
reboot
