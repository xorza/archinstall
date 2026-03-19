#!/bin/bash
# Run as xxorza after first login
set -e

# --- KDE cleanup ---

balooctl6 disable
balooctl6 purge

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
  com.brave.Browser \
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
