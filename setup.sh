#!/bin/bash
# Arch Linux install
# curl -fsSL https://cssodessa.com/setup.sh | bash
set -e

BASE_URL="https://cssodessa.com"

# =============================================================================
# Stage 1: Mount + Install (run from arch live USB)
# =============================================================================

# --- Disk layout ---
# DISK0 (S676NX0T612072): 1G EFI (p1) + 100G root ext4 (p2) + rest LVM PV (p3)
# DISK1 (S676NX0T612065): entire disk LVM PV
# vg0/home: spans both NVMe drives (ext4, /home)
# User home (/home/xxorza) is encrypted via systemd-homed

DISK0=/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NX0T612072
DISK1=/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NX0T612065

# verify UEFI mode
if [[ ! -d /sys/firmware/efi ]]; then
  echo "ERROR: Not booted in UEFI mode. Reboot the USB in UEFI mode."
  exit 1
fi

timedatectl set-ntp true

# unmount if re-running
umount -R /mnt 2>/dev/null || true

# activate LVM
vgchange -ay vg0

# format partitions
mkfs.ext4 -F "${DISK0}-part2"
mkfs.fat -F 32 "${DISK0}-part1"

# mount
mount "${DISK0}-part2" /mnt
mkdir -p /mnt/boot /mnt/home
mount "${DISK0}-part1" /mnt/boot
mount /dev/vg0/home /mnt/home

# --- Enable multilib (needed for lib32 packages in pacstrap) ---

sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
pacman -Sy

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
  lvm2 btrfs-progs dosfstools ntfs-3g exfatprogs \
  networkmanager openssh \
  nvidia-open nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland \
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
  wireguard-tools traceroute bind restic \
  udisks2 gvfs ufw

# --- Generate fstab ---

genfstab -U /mnt > /mnt/etc/fstab

# =============================================================================
# Stage 2: Chroot config
# =============================================================================

curl -fSL -o /mnt/root/setup-chroot.sh "$BASE_URL/setup-chroot.sh"
curl -fSL -o /mnt/root/setup-firstboot.sh "$BASE_URL/setup-firstboot.sh"
curl -fSL -o /mnt/root/setup-user.sh "$BASE_URL/setup-user.sh"
chmod +x /mnt/root/setup-*.sh

arch-chroot /mnt bash /root/setup-chroot.sh "$DISK0"
rm /mnt/root/setup-chroot.sh

echo ""
echo "Set root password:"
until arch-chroot /mnt passwd </dev/tty; do
  echo "Passwords did not match, try again."
done

echo ""
echo "=== Done. Reboot into the new install, then run as root: ==="
echo "  bash /root/setup-firstboot.sh"
echo ""
echo "After first login as xxorza, run:"
echo "  ~/setup-user.sh"
echo ""
