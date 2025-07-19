#!/bin/bash
set -e

# Синхронизация времени"
timedatectl set-ntp true

# Очистка диска /dev/vda
wipefs --all /dev/vda

# Разметка GPT через sgdisk
/usr/bin/sgdisk -Z /dev/vda
/usr/bin/sgdisk -n 1:0:+512MiB -t 1:ef00 /dev/vda  # EFI
/usr/bin/sgdisk -n 2:0:+5632MiB -t 2:8200 /dev/vda # Swap
/usr/bin/sgdisk -n 3:0:+25600MiB -t 3:8300 /dev/vda # /
/usr/bin/sgdisk -n 4:0:0 -t 4:8300 /dev/vda         # /home

# Форматирование
mkfs.vfat /dev/vda1
mkswap /dev/vda2
swapon /dev/vda2
mkfs.ext4 /dev/vda3
mkfs.ext4 /dev/vda4

# Монтирование
mount /dev/vda3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/vda1 /mnt/boot/efi
mkdir /mnt/home
mount /dev/vda4 /mnt/home

# Ускоряем загрузку
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 15/' /mnt/etc/pacman.conf

# Установка базовой системы
pacstrap -K /mnt base base-devel linux linux-firmware networkmanager sudo vim git grub efibootmgr wget

# Генерация fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Копирование in-chroot.sh
cat > /mnt/in-chroot.sh <<"EOF"

#!/bin/bash
set -e

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
127.0.0.1	localhost
::1		localhost
127.0.1.1	computer.localdomain	computer
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

# Включение служб
systemctl enable NetworkManager
systemctl enable dbus-broker
systemctl enable systemd-timesyncd

EOF

chmod +x /mnt/in-chroot.sh

# Переход в chroot и запуск post-install
arch-chroot /mnt /in-chroot.sh
rm /mnt/in-chroot.sh

# Загрузка скрипта установки окружения
#wget https://raw.githubusercontent.com/Steepok/script-install/refs/heads/main/hyprland-install.sh
#chmod +x hyprland-install.sh

# Автоматическое размонтирование
umount -R /mnt

# Автоматическая перезагрузка
reboot      
