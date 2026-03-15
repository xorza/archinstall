#!/bin/bash
set -e

# no password for sudo
echo "xxorza ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/xxorza-nopasswd >/dev/null
sudo chmod 440 /etc/sudoers.d/xxorza-nopasswd

# change shell to fish
chsh -s /bin/fish
sudo chsh -s /bin/fish

# set battery charge threshold
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

# nvidia drm modesetting (required for Wayland, fbdev=1 required on kernel 6.11+)
echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia_drm.conf

# disable build-in intel gpu, also disables audio
sudo tee /etc/modprobe.d/blacklist-intel.conf <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF
sudo mkinitcpio -P

# enable systemd-homed for encrypted home directories
sudo systemctl enable --now systemd-homed.service

# disable FallbackDNS and DNSStubListener
sudo tee -a /etc/systemd/resolved.conf >/dev/null << 'EOF'
FallbackDNS=
DNSStubListener=no
EOF


# configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw.service

# disable baloo file indexing
balooctl6 disable
balooctl6 purge



# cleanup autostart (per-user override so package updates don't restore them)
mkdir -p ~/.config/autostart
for f in at-spi-dbus-bus baloo_file gmenudbusmenuproxy kaccess kglobalacceld \
         org.kde.discover.notifier org.kde.plasma-fallback-session-restore xembedsniproxy; do
  cp /etc/xdg/autostart/$f.desktop ~/.config/autostart/$f.desktop 2>/dev/null
  echo "Hidden=true" >> ~/.config/autostart/$f.desktop
done


# install flatpak apps
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
  org.libreoffice.LibreOffice
