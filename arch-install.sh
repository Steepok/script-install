#!/bin/bash
set -e

# Увеличиваем кол-во одновременных загрузок
sed -i 's/^ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf

# Синхронизация времени
timedatectl set-ntp true

# Разметка GPT через sgdisk
/usr/bin/sgdisk -Z /dev/vda
/usr/bin/sgdisk -n 1:0:+512MiB -t 1:ef00 /dev/nvme0n1    # EFI - 0,5GB
/usr/bin/sgdisk -n 2:0:+16384MiB -t 2:8200 /dev/nvme0n1   # Swap - 16GB
/usr/bin/sgdisk -n 3:0:+102400MiB -t 3:8300 /dev/nvme0n1  # / - 100GB
/usr/bin/sgdisk -n 4:0:0 -t 4:8300 /dev/nvme0n1          # /home - ~350GB

# Форматирование
mkfs.vfat -F32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
swapon /dev/nvme0n1p2
mkfs.ext4 /dev/nvme0n1p3
mkfs.ext4 /dev/nvme0n1p4

# Монтирование
mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
mkdir /mnt/home
mount /dev/nvme0n1p4 /mnt/home

# Установка базовой системы
pacstrap -K /mnt base base-devel linux linux-headers linux-firmware networkmanager sudo nvim git grub efibootmgr wget curl

# Генерация fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Копирование in-chroot.sh
cat > /mnt/in-chroot.sh <<"EOF"

#!/bin/bash
set -e


###################################################
############### БАЗОВАЯ СИСТЕМА ###################
###################################################


# Увеличиваем кол-во одновременных загрузок
sed -i 's/^ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf

# Консольная русская раскладка
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

# Локализация
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Часовой пояс, время
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Hostname и hosts
echo "computer" > /etc/hostname
cat >> /etc/hosts <<EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   computer.localdomain	computer
EOL

# Пользователь и пароли
useradd -mG wheel user
echo "user:123099" | chpasswd
echo "root:1234567825" | chpasswd

# Разрешение sudo для группы wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Установка GRUB (EFI в /efi)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg


###################################################
############# ДОПОЛНИТЕЛЬНЫЕ ПАКЕТЫ ###############
###################################################

# Обновление системы
pacman -Syu --noconfirm

# Пакеты
pacman -S --noconfirm \
  kitty firefox hyprland htop \
  xdg-user-dirs xdg-utils man man-db zip unzip openssh blueman rsync \
  pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber pipewire-jack bluez bluez-utils \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-hack-nerd \
  mesa seatd waybar reflector dbus-broker polkit \
  vulkan-radeon libva-mesa-driver

# Создание директорий пользователя
runuser -l user -c xdg-user-dirs-update

# Включение служб
systemctl enable reflector.timer
systemctl enable seatd
systemctl enable NetworkManager
systemctl enable dbus-broker
systemctl enable systemd-timesyncd
systemctl enable bluetooth

EOF

chmod +x /mnt/in-chroot.sh

# Переход в chroot и запуск post-install
arch-chroot /mnt /in-chroot.sh
rm /mnt/in-chroot.sh

# Автоматическое размонтирование
umount -R /mnt

# Автоматическая перезагрузка
reboot
