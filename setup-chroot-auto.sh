#!/bin/bash
# Run inside arch-chroot (no running systemd)
set -e

# --- Shell ---

chsh -s /bin/fish root

# --- GPU ---

cat > /etc/modprobe.d/blacklist-intel.conf <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF

# nvidia early KMS
sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
mkinitcpio -P

# --- System services ---

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
