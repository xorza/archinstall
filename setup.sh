#!/bin/bash
# Arch Linux install for ASUS ROG Strix SCAR 18 (G834JY): KDE Plasma on Wayland,
# NVIDIA dGPU-only, encrypted home via systemd-homed.
#
# From the Arch ISO, as root:
#   curl -fsSLO https://raw.githubusercontent.com/xorza/archinstall/main/setup.sh
#   bash setup.sh
#
# The later stages re-invoke this same file: `chroot` from inside arch-chroot, then
# `firstboot` from a self-disabling unit on the first real boot, which in turn runs
# `user` as xxorza. Reboot once when told to; nothing else is run by hand.
set -euo pipefail

HOSTNAME=asus-rog-arch
USERNAME=xxorza
TIMEZONE=Europe/Chisinau
LOCALE=en_US.UTF-8
SWAP_SIZE=16G
# The Neo G9 console is unreadable at the default 8x16.
CONSOLE_FONT=ter-132b

# /boot and / live on the PM9A1; /home is a whole-disk ext4 on the 980 PRO and is
# never formatted. Partitions must already exist — this script does not touch the GPT.
DISK_SYS=/dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S676NX0T612072
DISK_HOME=/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_2TB_S6B0NL0T940435H
PART_ESP="$DISK_SYS-part1"
PART_ROOT="$DISK_SYS-part2"
PART_HOME="$DISK_HOME-part1"

# pcie_aspm=off                          – prevents the NVMe RxErr storm that hard-locks the box
# nvme_core.default_ps_max_latency_us=0  – no NVMe power-state transitions (random freezes)
# mem_sleep_default=deep                 – S3; s2idle is broken with NVIDIA here
# acpi_backlight=native                  – eDP brightness in dGPU-only MUX mode
# transparent_hugepage=madvise           – no THP compaction latency spikes on a desktop
# NVreg_PreserveVideoMemoryAllocations is deliberately absent: 595+ drivers replaced it with
# NVreg_UseKernelSuspendNotifiers, already set in /usr/lib/modprobe.d/nvidia-sleep.conf.
CMDLINE="pcie_aspm=off nvme_core.default_ps_max_latency_us=0 mem_sleep_default=deep acpi_backlight=native transparent_hugepage=madvise"

PACKAGES=(
  base linux linux-headers linux-firmware intel-ucode
  base-devel git nano fish
  btrfs-progs dosfstools ntfs-3g exfatprogs
  networkmanager openssh
  nvidia-open nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland
  lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader libva-utils
  plasma-meta plasma-login-manager plasma-nm
  wayland xorg-xwayland qt5-wayland qt6-wayland
  xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk xdg-utils
  pipewire pipewire-audio pipewire-pulse pipewire-alsa wireplumber
  bluez bluez-utils
  samba smbclient kio-extras avahi
  power-profiles-daemon fwupd smartmontools ddcutil
  flatpak discover
  konsole dolphin ark spectacle partitionmanager kwalletmanager kwallet-pam
  rustup clang llvm mold
  ttf-jetbrains-mono ttf-jetbrains-mono-nerd terminus-font
  eza mc ncdu fastfetch wget rsync reflector pacman-contrib
  man-db man-pages texinfo
  nmap net-tools inetutils openbsd-netcat tcpdump whois iperf3
  wireguard-tools traceroute bind restic
  udisks2 gvfs ufw zed steam kicad
)

AUR_PACKAGES=(asusctl rog-control-center brave-bin edid-decode)

FLATPAKS=(
  org.telegram.desktop org.blender.Blender com.prusa3d.PrusaSlicer
  org.kde.isoimagewriter org.videolan.VLC org.kde.gwenview
  org.qbittorrent.qBittorrent com.rustdesk.RustDesk org.freecad.FreeCAD
  net.nokyan.Resources org.gnome.Calculator org.gnome.Firmware
  org.libreoffice.LibreOffice app.zen_browser.zen com.obsproject.Studio
  org.gimp.GIMP org.raspberrypi.rpi-imager
)

# Plasma services that cost startup time and are never used here.
DISABLED_AUTOSTART=(
  at-spi-dbus-bus baloo_file gmenudbusmenuproxy kaccess kglobalacceld
  org.kde.discover.notifier org.kde.plasma-fallback-session-restore xembedsniproxy
)

SELF=$(readlink -f "${BASH_SOURCE[0]}")

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo; echo "==> $*"; }

stage_install() {
  [[ -f $SELF ]] || die "run this as a file (curl -fsSLO ... && bash setup.sh), not piped into bash"
  [[ -d /sys/firmware/efi ]] || die "not booted in UEFI mode — reboot the USB in UEFI mode"
  curl -fsS --max-time 5 -o /dev/null https://archlinux.org/ || die "no network — connect first"
  for part in "$PART_ESP" "$PART_ROOT" "$PART_HOME"; do
    [[ -b $part ]] || die "missing partition: $part"
  done

  timedatectl set-ntp true
  umount -R /mnt 2>/dev/null || true

  log "Partitions to be written"
  echo "  ESP:  $PART_ESP -> /boot (kept; only the Arch entries are replaced)"
  echo "  Root: $PART_ROOT -> /     (ERASED, mkfs.ext4)"
  echo "  Home: $PART_HOME -> /home (kept)"
  echo
  lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
  echo
  read -rp "Erase root and install? [y/N] " answer </dev/tty
  [[ $answer =~ ^[Yy]$ ]] || die "aborted"

  log "Formatting and mounting"
  mkfs.ext4 -F "$PART_ROOT"
  mount -o noatime "$PART_ROOT" /mnt
  mount --mkdir -o noatime,fmask=0077,dmask=0077 "$PART_ESP" /mnt/boot
  mount --mkdir -o noatime "$PART_HOME" /mnt/home
  # The ESP is shared with the Windows bootloader, so it is never reformatted —
  # clear only what this install owns.
  rm -f /mnt/boot/loader/entries/arch*.conf /mnt/boot/vmlinuz-linux /mnt/boot/initramfs-linux*.img

  log "Ranking mirrors"
  reflector --protocol https --sort rate --latest 20 --save /etc/pacman.d/mirrorlist

  # pacstrap resolves against the live system's pacman.conf, so multilib has to be on here
  # for the lib32-* packages.
  enable_multilib /etc/pacman.conf

  log "Installing packages"
  pacstrap -K /mnt "${PACKAGES[@]}"
  genfstab -U /mnt >> /mnt/etc/fstab

  install -m 0755 "$SELF" /mnt/root/setup.sh
  arch-chroot /mnt /root/setup.sh chroot

  log "Set the root password"
  until arch-chroot /mnt passwd </dev/tty; do
    echo "Passwords did not match, try again."
  done

  log "Done — reboot. The rest runs automatically on tty1 and will ask for the ${USERNAME} home password."
}

stage_chroot() {
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc

  sed -i "s/^#\(${LOCALE//./\\.} UTF-8\)/\1/" /etc/locale.gen
  locale-gen
  echo "LANG=$LOCALE" > /etc/locale.conf
  echo "FONT=$CONSOLE_FONT" > /etc/vconsole.conf
  echo "$HOSTNAME" > /etc/hostname

  sed -i 's/^#Color/Color/;s/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
  enable_multilib /etc/pacman.conf

  # A drop-in rather than sed on mkinitcpio.conf: the nvidia modules are loaded early so KMS is
  # up before the display manager, and `kms` is dropped so nouveau never enters the initramfs.
  # Early KMS rules out hibernation — this machine uses S3 suspend.
  cat > /etc/mkinitcpio.conf.d/10-nvidia.conf <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)
EOF

  cat > /etc/modprobe.d/blacklist-intel.conf <<'EOF'
install i915 /usr/bin/false
install intel_agp /usr/bin/false
EOF
  echo 'options nvidia NVreg_RegistryDwords=EnableBrightnessControl=1' > /etc/modprobe.d/20-nvidia-backlight.conf

  log "Installing systemd-boot"
  bootctl install
  cat > /boot/loader/loader.conf <<'EOF'
default  arch.conf
timeout  0
console-mode max
editor   no
EOF
  # timeout 0 boots straight through; hold Space at power-on to reach the fallback entry.
  local root_uuid variant
  root_uuid=$(blkid -s UUID -o value "$PART_ROOT")
  for variant in "" "-fallback"; do
    cat > "/boot/loader/entries/arch${variant}.conf" <<EOF
title   Arch Linux${variant:+ (fallback)}
linux   /vmlinuz-linux
initrd  /initramfs-linux${variant}.img
options root=UUID=$root_uuid rw $CMDLINE
EOF
  done

  [[ -f /swapfile ]] || mkswap -U clear --size "$SWAP_SIZE" --file /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap defaults 0 0' >> /etc/fstab

  # 64 GB of RAM: keep pressure off swap and let dirty pages flush sooner.
  cat > /etc/sysctl.d/99-vm-tuning.conf <<'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
EOF

  install -d /etc/systemd/journald.conf.d
  cat > /etc/systemd/journald.conf.d/retention.conf <<'EOF'
[Journal]
MaxRetentionSec=10day
SystemMaxUse=200M
EOF

  local sudoers=/etc/sudoers.d/10-$USERNAME
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$USERNAME" > "$sudoers"
  chmod 0440 "$sudoers"
  visudo -cqf "$sudoers" || { rm -f "$sudoers"; die "generated sudoers file is invalid"; }

  # Interactive because homectl prompts for the home password; ordered ahead of the display
  # manager so it owns tty1, and disabled before it runs so a failure cannot loop.
  cat > /etc/systemd/system/arch-firstboot.service <<EOF
[Unit]
Description=First boot setup
ConditionPathExists=/root/setup.sh
After=systemd-homed.service network-online.target
Wants=network-online.target
Before=plasmalogin.service
Conflicts=getty@tty1.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/systemctl disable arch-firstboot.service
ExecStart=/root/setup.sh firstboot
StandardInput=tty
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable \
    NetworkManager bluetooth sshd avahi-daemon systemd-homed systemd-resolved \
    plasmalogin fstrim.timer systemd-oomd ufw arch-firstboot.service

  # Both MODULES and HOOKS are settled by now.
  mkinitcpio -P
}

stage_firstboot() {
  # arch-chroot bind-mounts /etc/resolv.conf, so this cannot be done in the chroot stage.
  ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  # Reusing the signing key keeps user records from a previous install valid.
  if [[ -f /home/homed-keys/local.private ]]; then
    log "Restoring homed signing key from the previous install"
    install -m 0600 /home/homed-keys/local.private /var/lib/systemd/home/
    install -m 0644 /home/homed-keys/local.public /var/lib/systemd/home/
    systemctl restart systemd-homed
  fi

  log "Setting up $USERNAME"
  if homectl inspect "$USERNAME" &>/dev/null; then
    homectl update "$USERNAME" --shell=/bin/fish --member-of=wheel
  else
    homectl create "$USERNAME" --storage=luks --fs-type=btrfs --member-of=wheel --shell=/bin/fish
  fi
  mountpoint -q "/home/$USERNAME" || homectl activate "$USERNAME"

  # The key signs user records, so it stays root-only on the unencrypted /home.
  install -d -m 0700 /home/homed-keys
  install -m 0600 /var/lib/systemd/home/local.private /home/homed-keys/
  install -m 0644 /var/lib/systemd/home/local.public /home/homed-keys/

  log "Firewall"
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw --force enable

  log "Flatpaks"
  # Installed as root so no polkit agent is needed this early.
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y --noninteractive flathub "${FLATPAKS[@]}"

  log "Building AUR packages as $USERNAME"
  local user_script=/tmp/arch-setup-user.sh
  install -m 0755 "$SELF" "$user_script"
  runuser -u "$USERNAME" -- env HOME="/home/$USERNAME" USER="$USERNAME" LOGNAME="$USERNAME" \
    "$user_script" user
  rm -f "$user_script"

  # asusd is Type=dbus and has no [Install] section, so it is started, never enabled.
  systemctl start asusd
  asusctl battery limit 50

  rm -f /root/setup.sh /etc/systemd/system/arch-firstboot.service
  systemctl daemon-reload
  log "Setup complete."
}

stage_user() {
  if ! command -v yay &>/dev/null; then
    log "Building yay"
    rm -rf /tmp/yay
    git clone --depth 1 https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
  fi

  # asusctl links against libclang, which is not on the default search path.
  LIBCLANG_PATH=/usr/lib yay -S --noconfirm "${AUR_PACKAGES[@]}"

  # Written as config rather than balooctl6/systemctl --user, which both need a session bus
  # that does not exist yet at first boot.
  install -d ~/.config/systemd/user
  printf '[Basic Settings]\nIndexing-Enabled=false\n' > ~/.config/baloofilerc
  ln -sf /dev/null ~/.config/systemd/user/plasma-baloorunner.service

  install -d ~/.config/autostart
  local unit
  for unit in "${DISABLED_AUTOSTART[@]}"; do
    printf '[Desktop Entry]\nHidden=true\n' > ~/.config/autostart/"$unit".desktop
  done
}

enable_multilib() {
  sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$1"
}

case "${1:-install}" in
  install)   stage_install ;;
  chroot)    stage_chroot ;;
  firstboot) stage_firstboot ;;
  user)      stage_user ;;
  *)         die "unknown stage: $1 (install|chroot|firstboot|user)" ;;
esac
