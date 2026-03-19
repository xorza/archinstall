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
# 1. Partition & mount (edit for your drives)
curl -fsSL https://raw.githubusercontent.com/xorza/archinstall/main/setup-mount.sh | bash

# 2. Install base system
curl -fsSL https://raw.githubusercontent.com/xorza/archinstall/main/setup.sh | bash

# 3. Reboot, then as root:
bash /root/setup-firstboot.sh

# 4. Log in as xxorza, then:
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
| `setup-mount.sh` | Partition and mount dual NVMe drives with LVM |
| `setup.sh` | Install base system and packages via pacstrap |
| `setup-chroot.sh` | Bootloader, locale, services, swap (runs in chroot) |
| `setup-hardware.sh` | ASUS ROG specific: hostname, Nvidia, battery limit |
| `setup-firstboot.sh` | User creation (systemd-homed), firewall |
| `setup-user.sh` | KDE tweaks, flatpak apps (runs as user) |
| `nvidia-backlight-setup.sh` | Nvidia backlight control helper |
