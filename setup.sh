

# no password for sudo
echo "xxorza ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/xxorza-nopasswd >/dev/null
sudo chmod 440 /etc/sudoers.d/xxorza-nopasswd

# change shell to zsh
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

# disable build-in intel gpu, also disables audio
sudo tee /etc/modprobe.d/blacklist-intel.conf <<EOF
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF
sudo mkinitcpio -P

# enable systemd-homed for encrypted home directories
sudo systemctl enable --now systemd-homed.service

# choose iwd as wifi backend, disable wpa_supplicant
sudo tee -a /etc/NetworkManager/NetworkManager.conf > /dev/null << 'EOF'
[device]
wifi.backend=iwd
EOF
sudo systemctl stop NetworkManager
sudo systemctl disable wpa_supplicant

# disable FallbackDNS and DNSStubListener
sudo tee -a /etc/systemd/resolved.conf >/dev/null << 'EOF'
FallbackDNS=
DNSStubListener=no
EOF

# enable NetworkManager and avahi-daemon
sudo systemctl enable NetworkManager.service
sudo systemctl enable avahi-daemon.service

# disable baloo file indexing
sudo balooctl6 disable
sudo balooctl6 purge



# cleanup autostart
sudo rm /etc/xdg/autostart/at-spi-dbus-bus.desktop
sudo rm /etc/xdg/autostart/baloo_file.desktop
sudo rm /etc/xdg/autostart/gmenudbusmenuproxy.desktop
sudo rm /etc/xdg/autostart/kaccess.desktop
sudo rm /etc/xdg/autostart/kglobalacceld.desktop
sudo rm /etc/xdg/autostart/org.kde.discover.notifier.desktop
sudo rm /etc/xdg/autostart/org.kde.plasma-fallback-session-restore.desktop
sudo rm /etc/xdg/autostart/xembedsniproxy.desktop


# install flatpak apps
flatpak install flathub com.brave.Browser -y
flatpak install flathub org.telegram.desktop -y
flatpak install flathub org.blender.Blender -y
flatpak install flathub com.prusa3d.PrusaSlicer -y
flatpak install flathub org.kde.isoimagewriter -y
flatpak install flathub org.videolan.VLC -y
flatpak install flathub org.kde.gwenview -y
flatpak install flathub dev.zed.Zed -y
flatpak install flathub org.qbittorrent.qBittorrent -y
flatpak install flathub com.rustdesk.RustDesk -y
flatpak install flathub org.freecad.FreeCAD -y
flatpak install flathub net.nokyan.Resources -y
flatpak install flathub org.gnome.Calculator -y
flatpak install flathub org.gnome.Firmware -y
flatpak install flathub org.libreoffice.LibreOffice -y
