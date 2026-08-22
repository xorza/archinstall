# archinstall

Opinionated Arch Linux install for KDE Plasma on an ASUS ROG Strix SCAR 18 (G834JY) with Nvidia.

## What you get

- KDE Plasma (Wayland) with systemd-boot
- Nvidia (open, via DKMS) with early KMS, dGPU-only MUX mode (the iGPU drives no outputs)
- Encrypted home via systemd-homed (LUKS + btrfs)
- Swapfile, pipewire, bluetooth, samba, avahi
- UFW firewall (SSH allowed), WireGuard, common net tools
- AUR via yay: asusctl, rog-control-center, brave-bin
- Flatpak apps (Zen, VLC, OBS, Blender, FreeCAD, etc.)

## Usage

Boot the Arch ISO in UEFI mode, connect to the network, then as root:

```bash
curl -fsSLO https://raw.githubusercontent.com/xorza/archinstall/main/setup.sh
bash setup.sh
```

Reboot when it finishes. The rest runs automatically on tty1 before the display
manager starts. Three prompts total: confirm the disk wipe, set the root password,
set the `xxorza` home password.

## Disk layout

Partitions must already exist — `setup.sh` formats but never repartitions.

| Partition | Mount | Action |
|---|---|---|
| `nvme-SAMSUNG_MZVL21T0HCLR-...612072-part1` | `/boot` | kept (shared ESP — Windows Boot Manager lives here) |
| `nvme-SAMSUNG_MZVL21T0HCLR-...612072-part2` | `/` | **erased**, ext4 |
| `nvme-Samsung_SSD_980_PRO_2TB_...435H-part1` | `/home` | kept |

`/home/xxorza` is a LUKS+btrfs image managed by systemd-homed, so it survives a
reinstall. The homed signing key is stashed at `/home/homed-keys` (root-only) and
restored on the next run, which is what keeps the existing user record valid.

## Stages

`setup.sh` re-invokes itself; you only ever run the first one.

| Stage | Runs | Does |
|---|---|---|
| `install` | live ISO | mount, mirrors, pacstrap, fstab, root password |
| `chroot` | `arch-chroot` | bootloader, locale, mkinitcpio, sysctl, services, sudoers |
| `firstboot` | self-disabling unit on first boot | homed user, firewall, flatpaks |
| `user` | `runuser` from `firstboot` | yay, AUR packages, KDE tweaks |

## Post-install

Enable mDNS for `.local` hostname resolution (e.g. `smb://nas.local/`):

```bash
nmcli connection modify "<connection-name>" connection.mdns yes
```

## Kernel upgrades

The Nvidia modules are rebuilt locally by DKMS against whichever kernel is
installed, so `linux` and the driver cannot drift apart the way they can with the
prebuilt `nvidia-open` package — that one is pinned to a single kernel build by
module vermagic, and a `linux` pkgrel bump released ahead of its rebuild is enough
to leave the dGPU with no driver.

The cost is that a *failed* build looks identical to a missing one: in dGPU-only
MUX mode every display connector hangs off the Nvidia GPU, so there is nothing to
fall back to and the machine boots to a black screen on both the external and the
internal panel. Confirm the build before rebooting into a new kernel:

```bash
dkms status   # nvidia/<ver>, <kernel>, x86_64: installed
```

If it did not build, stay on the running kernel while you fix it — the modules for
it are still in place.
