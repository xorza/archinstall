#!/bin/bash
# Arch Linux install
# Assumes partitions are already mounted at /mnt (run setup-mount.sh first)
# curl -fsSL https://cssodessa.com/setup.sh | bash
set -e

BASE_URL="https://cssodessa.com"

# --- Verify mounts ---

if ! mountpoint -q /mnt; then
  echo "ERROR: /mnt is not mounted. Run setup-mount.sh first."
  exit 1
fi

# --- Mirrors (auto-rank by speed) ---

reflector --protocol https --sort rate --latest 20 --save /etc/pacman.d/mirrorlist

# --- Enable multilib (needed for lib32 packages in pacstrap) ---

sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
pacman -Sy

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
  udisks2 gvfs ufw zed steam

# --- Generate fstab ---

genfstab -U /mnt > /mnt/etc/fstab

# --- Chroot config ---

curl -fSL -o /mnt/root/setup-chroot.sh "$BASE_URL/setup-chroot.sh"
curl -fSL -o /mnt/root/setup-hardware.sh "$BASE_URL/setup-hardware.sh"
curl -fSL -o /mnt/root/setup-firstboot.sh "$BASE_URL/setup-firstboot.sh"
curl -fSL -o /mnt/root/setup-user.sh "$BASE_URL/setup-user.sh"
chmod +x /mnt/root/setup-*.sh

arch-chroot /mnt bash /root/setup-chroot.sh
rm /mnt/root/setup-chroot.sh /mnt/root/setup-hardware.sh

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
