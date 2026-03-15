# Arch Config Improvement Suggestions

## Issues

### 1. Security: credentials served over HTTP
`archinstall.sh` downloads configs from `cssodessa.com` using plain `curl -O` — no HTTPS enforcement, no checksum verification. The credentials file contains an Argon2id hash, but serving it over potentially unencrypted HTTP is still risky.

**Fix:** Use `https://` explicitly, or better — host on a private GitHub repo/gist with a short-lived token, or just keep the files on a USB stick.

### 2. `build-in monitor brightness.sh` is just notes, not a script
It contains `sudo nano ...` commands — these are manual instructions, not an executable script. The filename also has a typo ("build-in" → "built-in") and spaces make it annoying to use from the command line.

**Fix:** Convert to an actual script:
```bash
#!/bin/bash
echo 'options nvidia NVreg_RegistryDwords=EnableBrightnessControl=1' | sudo tee /etc/modprobe.d/20-nvidia-backlight.conf
# Add acpi_backlight=nvidia_wmi_ec to your boot entry's options line
```
Rename to `nvidia-backlight-setup.sh`.

### 3. Comment says "zsh" but sets fish (setup.sh:8)
```bash
# change shell to zsh   ← wrong comment
chsh -s /bin/fish
```

### 4. `balooctl6` runs as sudo but should run as user
Baloo is per-user. `sudo balooctl6 disable/purge` affects root's index, not yours.

**Fix:** Drop `sudo` on lines 56-57.

### 5. Deleting autostart files is fragile
`sudo rm /etc/xdg/autostart/*.desktop` will break on updates — packages will recreate them.

**Fix:** Override per-user instead:
```bash
for f in at-spi-dbus-bus baloo_file gmenudbusmenuproxy kaccess kglobalacceld \
         org.kde.discover.notifier org.kde.plasma-fallback-session-restore xembedsniproxy; do
  cp /etc/xdg/autostart/$f.desktop ~/.config/autostart/$f.desktop 2>/dev/null
  echo "Hidden=true" >> ~/.config/autostart/$f.desktop
done
```

### 6. Flatpak installs could be batched
Each `flatpak install` is a separate transaction. Batch them:
```bash
flatpak install flathub -y \
  com.brave.Browser \
  org.telegram.desktop \
  org.blender.Blender \
  ...
```
Faster, fewer prompts.

### 7. Missing `set -e` / error handling in scripts
Neither script has `#!/bin/bash` shebangs or `set -e`. If any step fails, the script silently continues, potentially leaving the system in a half-configured state.

### 8. `iwd` is not in the package list
`setup.sh` configures NetworkManager to use iwd as the Wi-Fi backend, but `iwd` is not in the packages list in `user_configuration.json`. This will fail unless iwd is manually installed first.

### 9. Redundant package: `systemd`
`systemd` (line 127 in packages) is part of `base` — no need to list it explicitly.

### 10. Missing `lib32-nvidia-utils` multilib prerequisite
You have `lib32-vulkan-icd-loader` and `lib32-nvidia-utils` but the `[multilib]` repo isn't explicitly enabled in the archinstall config. This may work if archinstall enables it by default, but worth verifying.

### 11. `parallel_downloads: 4` is conservative
With modern connections, `8-10` is usually fine and speeds up the initial install noticeably.

### 12. No `gfx_driver` set in profile_config
`"gfx_driver": null` means archinstall won't configure the Nvidia driver automatically. You install the packages manually, but setting this to `"nvidia-open"` would handle early modesetting and initramfs hooks for you.

## Minor suggestions

- Add `htop` or `btop` — `fastfetch` shows info but not live monitoring.
- Consider `eza` as a modern `ls` replacement (since you're already using fish).
- `plasma-login-manager` is the new replacement for SDDM — make sure you're on a Plasma version that supports it (6.3+).
- Consider putting this in a git repo for version tracking.
