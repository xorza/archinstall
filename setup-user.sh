#!/bin/bash
# Run as xxorza after first login
set -e

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
