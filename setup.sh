#!/bin/bash
set -e

# =============================================================================
# Run as root after first boot
# =============================================================================

# --- User (encrypted home via systemd-homed) ---

homectl create xxorza --storage=luks --fs-type=btrfs --member-of=wheel
echo "xxorza ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/xxorza-nopasswd >/dev/null
chmod 440 /etc/sudoers.d/xxorza-nopasswd
chsh -s /bin/fish root
homectl update xxorza --shell=/bin/fish

# --- GPU ---

echo 'options nvidia_drm modeset=1 fbdev=1' | tee /etc/modprobe.d/nvidia_drm.conf

tee /etc/modprobe.d/blacklist-intel.conf > /dev/null <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF
mkinitcpio -P

# --- System services ---

tee /etc/systemd/system/battery-limit.service > /dev/null <<'EOF'
[Unit]
Description=Set battery charge threshold
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 50 > /sys/class/power_supply/BAT0/charge_control_end_threshold'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now battery-limit.service

# --- Network ---

tee -a /etc/systemd/resolved.conf > /dev/null <<'EOF'
FallbackDNS=
DNSStubListener=no
EOF

# --- Firewall ---

ufw default deny incoming
ufw default allow outgoing
ufw enable
systemctl enable ufw.service

