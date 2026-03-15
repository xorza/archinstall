#!/bin/bash
set -e

# --- User (encrypted home via systemd-homed) ---

# create user with LUKS-encrypted btrfs home (will prompt for password)
sudo homectl create xxorza --storage=luks --fs-type=btrfs --member-of=wheel

echo "xxorza ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/xxorza-nopasswd >/dev/null
sudo chmod 440 /etc/sudoers.d/xxorza-nopasswd
sudo chsh -s /bin/fish root
sudo homectl update xxorza --shell=/bin/fish

# --- GPU ---

# nvidia drm modesetting (required for Wayland, fbdev=1 required on kernel 6.11+)
echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia_drm.conf

# disable intel gpu (also disables intel audio)
sudo tee /etc/modprobe.d/blacklist-intel.conf > /dev/null <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF
sudo mkinitcpio -P

# --- System services ---

# battery charge threshold (50%)
sudo tee /etc/systemd/system/battery-limit.service > /dev/null <<'EOF'
[Unit]
Description=Set battery charge threshold
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 50 > /sys/class/power_supply/BAT0/charge_control_end_threshold'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now battery-limit.service

# --- Network ---

sudo tee -a /etc/systemd/resolved.conf > /dev/null <<'EOF'
FallbackDNS=
DNSStubListener=no
EOF

# --- Firewall ---

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw.service

# --- KDE cleanup ---

balooctl6 disable
balooctl6 purge

mkdir -p ~/.config/autostart
for f in at-spi-dbus-bus baloo_file gmenudbusmenuproxy kaccess kglobalacceld \
         org.kde.discover.notifier org.kde.plasma-fallback-session-restore xembedsniproxy; do
  cp /etc/xdg/autostart/$f.desktop ~/.config/autostart/$f.desktop 2>/dev/null
  echo "Hidden=true" >> ~/.config/autostart/$f.desktop
done

# --- Flatpak apps ---

flatpak install flathub -y \
  com.brave.Browser \
  org.telegram.desktop \
  org.blender.Blender \
  com.prusa3d.PrusaSlicer \
  org.kde.isoimagewriter \
  org.videolan.VLC \
  org.kde.gwenview \
  dev.zed.Zed \
  org.qbittorrent.qBittorrent \
  com.rustdesk.RustDesk \
  org.freecad.FreeCAD \
  net.nokyan.Resources \
  org.gnome.Calculator \
  org.gnome.Firmware \
  org.libreoffice.LibreOffice \
  app.zen_browser.zen \
  com.obsproject.Studio \
  org.gimp.GIMP \
  org.raspberrypi.rpi-imager
