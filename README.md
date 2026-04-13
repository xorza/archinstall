# archinstall

Opinionated Arch Linux install scripts for KDE Plasma on ASUS ROG with Nvidia.

## What you get

- KDE Plasma (Wayland) with systemd-boot
- Nvidia (open) with early KMS
- Encrypted home via systemd-homed (LUKS + btrfs)
- LVM, swap, pipewire, bluetooth, samba, avahi
- UFW firewall, WireGuard, common net tools
- Flatpak apps (Firefox, VLC, OBS, etc.)

## Usage

Boot from Arch ISO, then:

```bash
# 1. Install (mounts, formats, installs — confirms partitions before formatting)
curl -fsSL https://raw.githubusercontent.com/xorza/archinstall/main/setup.sh | bash

# 2. Reboot, then as root:
bash /root/setup-firstboot.sh

# 3. Log in as xxorza, then:
~/setup-user.sh
```

## Post-install

Enable mDNS for `.local` hostname resolution (e.g. `smb://nas.local/`):

```bash
nmcli connection modify "<connection-name>" connection.mdns yes
```

## Scripts

| Script | Description |
|---|---|
| `setup.sh` | Entry point: mounts, installs base system via pacstrap |
| `setup-mount.sh` | Partition and mount dual NVMe drives with LVM (called by setup.sh) |
| `setup-chroot.sh` | Bootloader, locale, services, swap (runs in chroot) |
| `setup-hardware.sh` | ASUS ROG specific: hostname, Nvidia (runs in chroot) |
| `setup-firstboot.sh` | User creation (systemd-homed), firewall |
| `setup-user.sh` | yay, asusctl, KDE tweaks, flatpak apps (runs as user) |
