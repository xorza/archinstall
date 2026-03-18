#!/bin/bash
# Run inside arch-chroot (no running systemd)
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
pacman -Syu --noconfirm

# --- Bootloader (systemd-boot) ---

bootctl install

cat > /boot/loader/loader.conf <<EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
EOF

cat > /boot/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options root=UUID=$ROOT_UUID rw
EOF

# --- mkinitcpio HOOKS (lvm2 between block and filesystems) ---

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)/' /etc/mkinitcpio.conf

# --- Swapfile ---

mkswap -U clear --size 16G --file /swapfile
grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# --- Services ---

systemctl enable NetworkManager bluetooth sshd avahi-daemon systemd-homed plasmalogin

# --- Shell ---

chsh -s /bin/fish root

# --- GPU ---

cat > /etc/modprobe.d/blacklist-intel.conf <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF

# nvidia early KMS
sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

# --- Battery charge limit ---

cat > /etc/systemd/system/battery-limit.service <<EOF
[Unit]
Description=Set battery charge threshold
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 50 > /sys/class/power_supply/BAT0/charge_control_end_threshold'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable battery-limit.service

# --- Sudoers ---

echo "xxorza ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/xxorza-nopasswd
chmod 440 /etc/sudoers.d/xxorza-nopasswd

# --- Rebuild initramfs (after HOOKS + MODULES are both set) ---

mkinitcpio -P

# --- Root password set after chroot exits ---
