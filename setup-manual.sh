#!/bin/bash
# Manual Arch Linux install (no archinstall) — replaces setup.sh + user_configuration.json
# curl -fsSL https://cssodessa.com/setup-manual.sh | bash
set -e

BASE_URL="https://cssodessa.com"

# =============================================================================
# Stage 1: Mount + Install (run from arch live USB)
# =============================================================================

# --- Disk layout ---
# nvme0n1: 1G EFI (p1) + 100G root ext4 (p2) + rest LVM PV (p3)
# nvme1n1: entire disk LVM PV
# vg0/home: spans both NVMe drives (ext4, /home)
# User home (/home/xxorza) is encrypted via systemd-homed

timedatectl set-ntp true

# activate LVM
vgchange -ay vg0

# mount existing partitions
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/vg0/home /mnt/home

# --- Mirrors ---

cat > /etc/pacman.d/mirrorlist <<'EOF'
## Moldova
Server = https://mirror.hosthink.net/arch/$repo/os/$arch
Server = https://mirror.ihost.md/archlinux/$repo/os/$arch
Server = https://mirror.mangohost.net/archlinux/$repo/os/$arch

## Poland
Server = https://arch.midov.pl/arch/$repo/os/$arch
Server = https://ftp.icm.edu.pl/pub/Linux/dist/archlinux/$repo/os/$arch
Server = https://mirror.juniorjpdj.pl/archlinux/$repo/os/$arch
Server = https://ftp.psnc.pl/linux/archlinux/$repo/os/$arch
Server = https://arch.sakamoto.pl/$repo/os/$arch
Server = https://mirror.przekichane.pl/archlinux/$repo/os/$arch

## Romania
Server = https://mirrors.pidginhost.com/arch/$repo/os/$arch
Server = https://mirrors.nxthost.com/archlinux/$repo/os/$arch
Server = https://mirror.efect.ro/archlinux/$repo/os/$arch
Server = https://mirrors.chroot.ro/archlinux/$repo/os/$arch
Server = https://mirrors.hostico.ro/archlinux/$repo/os/$arch
Server = https://ro.mirror.flokinet.net/archlinux/$repo/os/$arch
Server = https://mirrors.hosterion.ro/archlinux/$repo/os/$arch
Server = https://ro.arch.niranjan.co/$repo/os/$arch
EOF

# --- Install base system ---

pacstrap -K /mnt \
  base linux linux-headers linux-firmware \
  amd-ucode intel-ucode \
  base-devel git nano fish \
  lvm2 dosfstools ntfs-3g exfatprogs \
  networkmanager openssh \
  nvidia-open-dkms nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland \
  lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader libva-utils \
  plasma-meta plasma-login-manager plasma-nm \
  wayland xorg-xwayland qt5-wayland qt6-wayland \
  xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk xdg-utils \
  pipewire pipewire-audio pipewire-pulse pipewire-alsa wireplumber \
  bluez bluez-utils \
  samba smbclient kio-extras avahi nss-mdns \
  power-profiles-daemon fwupd smartmontools \
  flatpak discover \
  konsole dolphin ark spectacle partitionmanager kwalletmanager kwallet-pam \
  rustup clang llvm mold \
  ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
  eza mc ncdu fastfetch wget rsync \
  wireguard-tools traceroute bind \
  udisks2 gvfs ufw

# --- Generate fstab ---

genfstab -U /mnt >> /mnt/etc/fstab

# =============================================================================
# Stage 2: Chroot config
# =============================================================================

curl -fSL -o /mnt/root/setup-chroot-auto.sh "$BASE_URL/setup-chroot-auto.sh"
curl -fSL -o /mnt/root/setup-chroot-manual.sh "$BASE_URL/setup-chroot-manual.sh"
curl -fSL -o /mnt/root/setup-firstboot.sh "$BASE_URL/setup-firstboot.sh"
curl -fSL -o /mnt/root/setup-user.sh "$BASE_URL/setup-user.sh"

arch-chroot /mnt bash /root/setup-chroot-manual.sh
rm /mnt/root/setup-chroot-auto.sh /mnt/root/setup-chroot-manual.sh

echo ""
echo "=== Done. Reboot into the new install, then run as root: ==="
echo "  bash /root/setup-firstboot.sh"
echo ""
