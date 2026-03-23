#!/bin/bash
# Hardware-specific config for ASUS ROG
# Called inside chroot by setup-chroot.sh
set -e

# --- Hostname ---

echo "asus-rog-arch" > /etc/hostname

# --- GPU: blacklist Intel, nvidia early KMS ---

cat > /etc/modprobe.d/blacklist-intel.conf <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF

sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

# --- Nvidia backlight: allow nvidia driver to control brightness ---

echo 'options nvidia NVreg_RegistryDwords=EnableBrightnessControl=1' > /etc/modprobe.d/20-nvidia-backlight.conf

# --- Battery charge limit ---

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
