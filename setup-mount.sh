#!/bin/bash
# Mount setup for ASUS ROG (two Samsung NVMe + LVM)
# Run from arch live USB before setup.sh
set -e

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

echo ""
echo "=== Mounted. Now run: ==="
echo "  curl -fsSL https://cssodessa.com/setup.sh | bash"
echo ""
