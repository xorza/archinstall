# Arch Config Improvement Suggestions

## Issues

### 1. Missing ASUS ROG specific tools
You're on an ASUS ROG laptop (`asus-rog-arch`) but missing the dedicated ASUS Linux tools. The `asus-armoury` kernel driver is in mainline since 6.19 (your kernel), so no custom kernel is needed.

Install `asusctl` (AUR) for:
- Fan curve control
- Keyboard LED/aura control
- Power profile switching
- Battery charge threshold (replaces your manual systemd service)

**Note:** `supergfxctl` is being phased out — skip it unless you need GPU switching or vfio. Since you blacklist the Intel GPU entirely, you don't need it.

### 2. No firewall configured
Your setup has no firewall. For a laptop connecting to various networks, this is a security gap.

**Fix:** Add `ufw` to the package list and to setup.sh:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw.service
```

### 3. No Btrfs snapshots configured
You're using Btrfs but `snapshot_config` is null. Btrfs snapshots are one of the biggest advantages of the filesystem and can save you from broken updates.

**Fix:** Install `snapper` and `snap-pac` (auto-snapshots on pacman transactions):
```bash
sudo snapper -c root create-config /
sudo systemctl enable snapper-timeline.timer
sudo systemctl enable snapper-cleanup.timer
```
Consider `grub-btrfs` or `systemd-boot` integration for booting from snapshots. Note: snapshots are NOT backups — use `btrfs send` to external media for that.

## Minor suggestions

- Add `btop` to packages — `fastfetch` shows info but not live monitoring.
- Consider putting this in a git repo for version tracking.
- Consider adding `pacman-contrib` for useful tools like `paccache` (clean old package cache) and `checkupdates`.
- Both `amd-ucode` and `intel-ucode` are listed — if this is strictly an Intel+Nvidia machine, `amd-ucode` is unnecessary (harmless but adds clutter).

## Sources

- [NVIDIA - ArchWiki](https://wiki.archlinux.org/title/NVIDIA)
- [Plasma/Wayland/Nvidia - KDE Community Wiki](https://community.kde.org/Plasma/Wayland/Nvidia)
- [ASUS Linux - ArchWiki](https://wiki.archlinux.org/title/ASUS_Linux)
- [asusctl - ArchWiki](https://wiki.archlinux.org/title/Asusctl)
- [Linux for ROG Notebooks](https://asus-linux.org/guides/arch-guide/)
- [Snapper - ArchWiki](https://wiki.archlinux.org/title/Snapper)
- [Btrfs - ArchWiki](https://wiki.archlinux.org/title/Btrfs)
- [Uncomplicated Firewall - ArchWiki](https://wiki.archlinux.org/title/Uncomplicated_Firewall)
- [systemd-homed - ArchWiki](https://wiki.archlinux.org/title/Systemd-homed)
