#!/bin/bash
set -e

# curl -fsSL https://cssodessa.com/setup-auto.sh | bash


BASE_URL="https://cssodessa.com"

# =============================================================================
# Stage 1: Mount + Install (run from arch live USB)
# =============================================================================

# --- Disk layout ---
# nvme0n1: 1G EFI + 100G root (ext4) + rest LVM PV
# nvme1n1: entire disk LVM PV
# vg0/home: spans both NVMe drives (ext4, /home)
# User home (/home/xxorza) is encrypted via systemd-homed

# activate LVM
vgchange -ay vg0

# mount existing partitions
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/vg0/home /mnt/home

# install
pacman -Syu archinstall --noconfirm
curl -fSL -o /tmp/user_configuration.json "$BASE_URL/user_configuration.json"
archinstall --config /tmp/user_configuration.json --mountpoint /mnt

# =============================================================================
# Stage 2: Chroot config (no running systemd)
# =============================================================================

curl -fSL -o /mnt/root/setup-chroot-auto.sh "$BASE_URL/setup-chroot-auto.sh"
curl -fSL -o /mnt/root/setup-firstboot.sh "$BASE_URL/setup-firstboot.sh"
curl -fSL -o /mnt/root/setup-user.sh "$BASE_URL/setup-user.sh"

arch-chroot /mnt bash /root/setup-chroot-auto.sh
rm /mnt/root/setup-chroot-auto.sh

echo ""
echo "=== Done. Reboot into the new install, then run as root: ==="
echo "  bash /root/setup-firstboot.sh"
echo ""
