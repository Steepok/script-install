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
/usr/bin/sgdisk -n 4:0:0 -t 4:8300 /dev/vda         # /home (всё остальное)

# Форматирование
mkfs.vfat /dev/vda1
mkswap /dev/vda2
swapon /dev/vda2
mkfs.ext4 /dev/vda3
mkfs.ext4 /dev/vda4

# Монтирование
mount /dev/vda3 /mnt
mkdir /mnt/efi
mount /dev/vda1 /mnt/efi
mkdir /mnt/home
mount /dev/vda4 /mnt/home

# Установка базовой системы
pacstrap -K /mnt base linux linux-firmware networkmanager sudo vim git grub efibootmgr

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

# Пользователь
useradd -mG wheel user
echo "Задай пароль для root:"
passwd
echo "Задай пароль для user:"
passwd user

# Разрешение sudo для группы wheel
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Установка GRUB (EFI в /efi)
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch
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

# Автоматическое размонтирование
umount -R /mnt

# Автоматическая перезагрузка
reboot      
