#!/bin/bash
set -e

# =============================================================================
# Run as root right after archinstall (filesystems still mounted at /mnt)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# copy scripts into the new install for first-boot
cp "$SCRIPT_DIR/setup-chroot.sh" /mnt/root/setup-chroot.sh
cp "$SCRIPT_DIR/setup-firstboot.sh" /mnt/root/setup-firstboot.sh
cp "$SCRIPT_DIR/setup-user.sh" /mnt/root/setup-user.sh

# run chroot tasks (config files, enable services — no running systemd needed)
arch-chroot /mnt bash /root/setup-chroot.sh

echo ""
echo "=== Done. Reboot into the new install, then run as root: ==="
echo "  bash /root/setup-firstboot.sh"
echo ""
