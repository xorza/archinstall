# Arch Config Improvement Suggestions

## Issues

### 1. Security: credentials served over HTTP
`archinstall.sh` downloads configs from `cssodessa.com` using plain `curl -O` — no HTTPS enforcement, no checksum verification. The credentials file contains an Argon2id hash, but serving it over potentially unencrypted HTTP is still risky.

**Fix:** Use `https://` explicitly, or better — host on a private GitHub repo/gist with a short-lived token, or just keep the files on a USB stick.

### 2. Missing `set -e` / error handling in scripts
Neither script has `#!/bin/bash` shebangs or `set -e`. If any step fails, the script silently continues, potentially leaving the system in a half-configured state.

### 3. Redundant package: `systemd`
`systemd` (line 127 in packages) is part of `base` — no need to list it explicitly.

### 4. Missing `lib32-nvidia-utils` multilib prerequisite
You have `lib32-vulkan-icd-loader` and `lib32-nvidia-utils` but the `[multilib]` repo isn't explicitly enabled in the archinstall config (`optional_repositories` is empty). Multilib is NOT enabled by default — these packages will fail to install. Add `"optional_repositories": ["multilib"]` to your config.

### 5. `parallel_downloads: 4` is conservative
With modern connections, `8-10` is usually fine and speeds up the initial install noticeably.

### 6. No `gfx_driver` set in profile_config
`"gfx_driver": null` means archinstall won't configure the Nvidia driver automatically. You install the packages manually, but setting this to `"nvidia-open"` would handle early modesetting and initramfs hooks for you.

### 7. Missing Nvidia kernel parameters for Wayland
For Nvidia + Wayland to work properly, you need kernel parameters that aren't set anywhere in your config:
- `nvidia_drm.modeset=1` — required for Wayland compositors (enabled by default since nvidia-utils 560.35, but explicit is safer)
- `nvidia_drm.fbdev=1` — **required on kernel 6.11+** (you're on 6.19)

Add these to your boot entry options or via modprobe config:
```bash
echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia_drm.conf
```
Also add `nvidia nvidia_modeset nvidia_uvm nvidia_drm` to the MODULES array in `/etc/mkinitcpio.conf` for early KMS loading.

### 8. Missing ASUS ROG specific tools
You're on an ASUS ROG laptop (`asus-rog-arch`) but missing the dedicated ASUS Linux tools. The `asus-armoury` kernel driver is in mainline since 6.19 (your kernel), so no custom kernel is needed.

Install `asusctl` (AUR) for:
- Fan curve control
- Keyboard LED/aura control
- Power profile switching
- Battery charge threshold (replaces your manual systemd service)

**Note:** `supergfxctl` is being phased out — skip it unless you need GPU switching or vfio. Since you blacklist the Intel GPU entirely, you don't need it.

### 9. No firewall configured
Your setup has no firewall. For a laptop connecting to various networks, this is a security gap.

**Fix:** Add `ufw` to the package list and to setup.sh:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw.service
```

### 10. No Btrfs snapshots configured
You're using Btrfs but `snapshot_config` is null. Btrfs snapshots are one of the biggest advantages of the filesystem and can save you from broken updates.

**Fix:** Install `snapper` and `snap-pac` (auto-snapshots on pacman transactions):
```bash
sudo snapper -c root create-config /
sudo systemctl enable snapper-timeline.timer
sudo systemctl enable snapper-cleanup.timer
```
Consider `grub-btrfs` or `systemd-boot` integration for booting from snapshots. Note: snapshots are NOT backups — use `btrfs send` to external media for that.

### 11. `services` field is empty in archinstall config
`"services": []` means archinstall won't enable any services. You manually enable them in setup.sh, but NetworkManager, bluetooth, and sshd could be listed here to start working immediately after first boot:
```json
"services": ["NetworkManager", "bluetooth", "sshd"]
```

## Minor suggestions

- Add `btop` to packages — `fastfetch` shows info but not live monitoring.
- Consider `eza` as a modern `ls` replacement (since you're already using fish).
- `plasma-login-manager` is the new replacement for SDDM — make sure you're on Plasma 6.3+.
- Consider putting this in a git repo for version tracking.
- Add `qt6-wayland` alongside `qt5-wayland` — Plasma 6 is Qt6-based, and Qt6 Wayland support ensures native rendering for Qt6 apps.
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
