#!/bin/bash
set -e

# --- Disk layout ---
# nvme0n1: 1G EFI + 100G root (ext4) + rest LVM PV
# nvme1n1: entire disk LVM PV
# vg0/home: spans both NVMe drives (ext4, /home)
# User home (/home/xxorza) is encrypted via systemd-homed (configured in setup.sh)

# activate LVM
vgchange -ay vg0

# mount existing partitions
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/vg0/home /mnt/home

# --- Install ---
pacman -Syu archinstall --noconfirm
curl -O https://cssodessa.com/user_configuration.json
archinstall --config user_configuration.json --mountpoint /mnt
