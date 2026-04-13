#!/bin/bash
# Run as xxorza after first login
set -e

# --- AUR helper (yay) ---

git clone https://aur.archlinux.org/yay.git /tmp/yay
(cd /tmp/yay && makepkg -si --noconfirm)
rm -rf /tmp/yay

# --- ASUS ROG control ---

LIBCLANG_PATH=/usr/lib yay -S --noconfirm asusctl rog-control-center brave-bin
asusctl battery limit 50

# --- KDE cleanup ---

balooctl6 disable
balooctl6 purge
systemctl --user mask plasma-baloorunner.service

mkdir -p ~/.config/autostart
for f in at-spi-dbus-bus baloo_file gmenudbusmenuproxy kaccess kglobalacceld \
         org.kde.discover.notifier org.kde.plasma-fallback-session-restore xembedsniproxy; do
  cat > ~/.config/autostart/$f.desktop <<EOF2
[Desktop Entry]
Hidden=true
EOF2
done

# --- Flatpak apps ---

flatpak install flathub -y \
  org.telegram.desktop \
  org.blender.Blender \
  com.prusa3d.PrusaSlicer \
  org.kde.isoimagewriter \
  org.videolan.VLC \
  org.kde.gwenview \
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
