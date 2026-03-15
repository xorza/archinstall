#!/bin/bash
# Run inside arch-chroot (no running systemd) — manual install only
set -e

# --- Timezone ---

ln -sf /usr/share/zoneinfo/Europe/Chisinau /etc/localtime
hwclock --systohc

# --- Locale ---

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- Hostname ---

echo "asus-rog-arch" > /etc/hostname

# --- pacman: multilib + parallel downloads ---

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
pacman -Sy --noconfirm

# --- Bootloader (systemd-boot) ---

bootctl install

cat > /boot/loader/loader.conf <<EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/nvme0n1p2 rw
EOF

# --- mkinitcpio HOOKS (lvm2 between block and filesystems) ---

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)/' /etc/mkinitcpio.conf

# --- Swapfile ---

mkswap -U clear --size 16G --file /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# --- Services ---

systemctl enable NetworkManager bluetooth sshd avahi-daemon systemd-homed

# --- Common config (GPU, battery, sudoers) ---

bash /root/setup-chroot-auto.sh

# --- Root password ---

echo "Set root password:"
passwd
