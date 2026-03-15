#!/bin/bash
# Run as root on first real boot (systemd running)
set -e

# --- User (encrypted home via systemd-homed) ---

homectl create xxorza --storage=luks --fs-type=btrfs --member-of=wheel
homectl update xxorza --shell=/bin/fish

# --- Firewall ---

ufw default deny incoming
ufw default allow outgoing
ufw enable
systemctl enable ufw.service

# --- User setup (KDE cleanup, flatpak apps) ---

su xxorza -c "bash /root/setup-user.sh"

# cleanup
rm /root/setup-chroot.sh /root/setup-firstboot.sh /root/setup-user.sh
