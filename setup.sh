#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
curl -O https://cssodessa.com/user_configuration.json
archinstall --config user_configuration.json --mountpoint /mnt

# =============================================================================
# Stage 2: Chroot config (no running systemd)
# =============================================================================

cp "$SCRIPT_DIR/setup-firstboot.sh" /mnt/root/setup-firstboot.sh
cp "$SCRIPT_DIR/setup-user.sh" /mnt/root/setup-user.sh
cp "$SCRIPT_DIR/setup-chroot.sh" /mnt/root/setup-chroot.sh

arch-chroot /mnt bash /root/setup-chroot.sh
rm /mnt/root/setup-chroot.sh

echo ""
echo "=== Done. Reboot into the new install, then run as root: ==="
echo "  bash /root/setup-firstboot.sh"
echo ""
