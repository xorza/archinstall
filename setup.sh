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
set -Eeuo pipefail

# TARGET_HOST, not HOSTNAME — bash maintains HOSTNAME itself and it would read as the
# live ISO's name to anyone skimming.
TARGET_HOST=asus-rog-arch
USERNAME=xxorza
TIMEZONE=Europe/Chisinau
LOCALE=en_US.UTF-8
SWAP_SIZE=16G
# ter-u32b is 16x32, the largest console font Terminus ships. On the 7680x2160 G9 that is
# 480x67 cells; the 8x16 default gives 960x135 and is unreadable.
CONSOLE_FONT=ter-u32b

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
  nvidia-open-dkms nvidia-utils nvidia-settings libva-nvidia-driver egl-wayland
  lib32-nvidia-utils lib32-vulkan-icd-loader vulkan-icd-loader libva-utils
  plasma-meta plasma-login-manager plasma-nm
  wayland xorg-xwayland qt5-wayland qt6-wayland
  xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk xdg-utils
  pipewire pipewire-audio pipewire-pulse pipewire-alsa wireplumber
  bluez bluez-utils
  samba smbclient kio-extras avahi
  power-profiles-daemon fwupd smartmontools ddcutil v4l-utils
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

AUR_PACKAGES=(asusctl rog-control-center brave-bin)

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

# Where `install` parks a copy in the target so the later stages have one canonical path.
# /usr/local/sbin is 0755, so the unprivileged `user` stage can execute it too.
SCRIPT_PATH=/usr/local/sbin/arch-setup

# firstboot writes to tty1, and the display manager paints over that screen the moment the
# stage fails, so the reason also goes to the journal.
die() {
  echo "ERROR: $*" >&2
  systemd-cat -t arch-setup -p err <<<"ERROR: $*" 2>/dev/null || true
  exit 1
}
log() { echo; echo "==> $*"; }

enable_multilib() { sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf; }

# set -e alone reports nothing about where it gave up, which is miserable in a 300-line
# installer; -E propagates this into the stage functions.
trap 'die "line $LINENO: $BASH_COMMAND"' ERR

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
  # --age 12 drops mirrors that have not synced today, which --latest alone does not.
  reflector --protocol https --age 12 --sort rate --latest 20 --save /etc/pacman.d/mirrorlist

  # pacstrap resolves against the live system's pacman.conf, so multilib has to be on here
  # for the lib32-* packages.
  enable_multilib

  log "Installing packages"
  pacstrap -K /mnt "${PACKAGES[@]}"
  genfstab -U /mnt >> /mnt/etc/fstab

  install -m 0755 "$SELF" "/mnt$SCRIPT_PATH"
  arch-chroot /mnt "$SCRIPT_PATH" chroot

  # bootctl ran inside the chroot and wrote no EFI boot variable, so nothing in NVRAM names
  # this loader and the firmware falls back to the removable path. The ESP also holds the
  # Windows Boot Manager, so name the loader here, where the variables work.
  if ! efibootmgr | grep -q 'Linux Boot Manager'; then
    efibootmgr --quiet --create --disk "$(readlink -f "$DISK_SYS")" --part 1 \
      --loader '\EFI\systemd\systemd-bootx64.efi' --label 'Linux Boot Manager'
  fi

  log "Set the root password"
  until arch-chroot /mnt passwd </dev/tty; do
    echo "Passwords did not match, try again."
  done

  # Flush before the reboot prompt, so a failing ESP write surfaces here and not at boot.
  sync
  umount -R /mnt || log "note: /mnt is still busy; it will unmount on reboot"

  log "Done — reboot. The rest runs automatically on tty1 and will ask for the ${USERNAME} home password."
}

stage_chroot() {
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc

  sed -i "s/^#\(${LOCALE//./\\.} UTF-8\)/\1/" /etc/locale.gen
  locale-gen
  echo "LANG=$LOCALE" > /etc/locale.conf
  printf 'FONT=%s\nKEYMAP=us\n' "$CONSOLE_FONT" > /etc/vconsole.conf
  echo "$TARGET_HOST" > /etc/hostname

  sed -i 's/^#Color/Color/;s/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
  enable_multilib

  # A drop-in rather than sed on mkinitcpio.conf: the nvidia modules are loaded early so KMS is
  # up before the display manager, and `kms` is dropped so nouveau never enters the initramfs.
  # Early KMS rules out hibernation — this machine uses S3 suspend.
  cat > /etc/mkinitcpio.conf.d/10-nvidia.conf <<'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)
EOF

  echo 'options nvidia NVreg_RegistryDwords=EnableBrightnessControl=1' > /etc/modprobe.d/20-nvidia-backlight.conf
  echo 'blacklist uvcvideo' > /etc/modprobe.d/disable-cam-mic.conf

  log "Installing systemd-boot"
  # This writes the loader onto the ESP. It leaves the EFI boot variables alone, because
  # bootctl reads the chroot as a system that did not boot with EFI. stage_install adds the
  # NVRAM entry afterwards.
  bootctl install
  # timeout 0 boots straight through; hold Space at power-on to reach the menu. The editor
  # stays on: without Secure Boot it blocks nothing a USB boot would not, and it is the only
  # way to fix a bad cmdline from the menu.
  cat > /boot/loader/loader.conf <<'EOF'
default  arch.conf
timeout  0
console-mode max
editor   yes
EOF
  local root_uuid variant
  # blkid exits 0 with empty output on a device it cannot identify, which would silently
  # write `root=UUID=` and leave an unbootable entry.
  root_uuid=$(blkid -s UUID -o value "$PART_ROOT")
  [[ -n $root_uuid ]] || die "could not read a UUID from $PART_ROOT"
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
ConditionPathExists=$SCRIPT_PATH
After=systemd-homed.service network-online.target
Wants=network-online.target
Before=plasmalogin.service
Conflicts=getty@tty1.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/systemctl disable arch-firstboot.service
ExecStart=$SCRIPT_PATH firstboot
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

  # Arch's stock preset builds only the default image, which would leave the fallback loader
  # entry written above pointing at a file that never gets created.
  cat > /etc/mkinitcpio.d/linux.preset <<'EOF'
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux.img"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF

  # A DKMS build that failed back in pacstrap would otherwise only surface as a black screen
  # after the reboot, with no output left to read the error on.
  compgen -G '/usr/lib/modules/*/updates/dkms/nvidia.ko*' > /dev/null \
    || die "DKMS did not build the nvidia modules — 'dkms status' in the chroot will say why"

  # Both MODULES and HOOKS are settled by now.
  mkinitcpio -P
}

stage_firstboot() {
  # The unit owns tty1 and the display manager takes that screen over, so keep a copy on disk.
  exec > >(tee -a /var/log/arch-setup.log) 2>&1

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
  # runuser does not set up a login environment, and makepkg needs a real HOME.
  runuser -u "$USERNAME" -- env HOME="/home/$USERNAME" USER="$USERNAME" LOGNAME="$USERNAME" \
    "$SCRIPT_PATH" user

  # asusd is Type=dbus and has no [Install] section, so it is started, never enabled.
  systemctl start asusd
  asusctl battery limit 50

  rm -f "$SCRIPT_PATH" /etc/systemd/system/arch-firstboot.service
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

STAGE=${1:-install}
case $STAGE in
  install|chroot|firstboot)
    [[ $EUID -eq 0 ]] || die "stage '$STAGE' must run as root"
    ;;
  user)
    [[ $EUID -ne 0 ]] || die "stage 'user' must not run as root — firstboot invokes it via runuser"
    ;;
  *)
    die "unknown stage: $STAGE (install|chroot|firstboot|user)"
    ;;
esac

"stage_$STAGE"
