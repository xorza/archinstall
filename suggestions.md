# Arch Config Improvement Suggestions

## Issues

### 1. Security: credentials served over HTTP
`archinstall.sh` downloads configs from `cssodessa.com` using plain `curl -O` — no HTTPS enforcement, no checksum verification. The credentials file contains an Argon2id hash, but serving it over potentially unencrypted HTTP is still risky.

**Fix:** Use `https://` explicitly, or better — host on a private GitHub repo/gist with a short-lived token, or just keep the files on a USB stick.

### 2. Missing `set -e` / error handling in scripts
Neither script has `#!/bin/bash` shebangs or `set -e`. If any step fails, the script silently continues, potentially leaving the system in a half-configured state.

### 3. `iwd` is not in the package list
`setup.sh` configures NetworkManager to use iwd as the Wi-Fi backend, but `iwd` is not in the packages list in `user_configuration.json`. This will fail unless iwd is manually installed first.

### 4. Redundant package: `systemd`
`systemd` (line 127 in packages) is part of `base` — no need to list it explicitly.

### 5. Missing `lib32-nvidia-utils` multilib prerequisite
You have `lib32-vulkan-icd-loader` and `lib32-nvidia-utils` but the `[multilib]` repo isn't explicitly enabled in the archinstall config. This may work if archinstall enables it by default, but worth verifying.

### 6. `parallel_downloads: 4` is conservative
With modern connections, `8-10` is usually fine and speeds up the initial install noticeably.

### 7. No `gfx_driver` set in profile_config
`"gfx_driver": null` means archinstall won't configure the Nvidia driver automatically. You install the packages manually, but setting this to `"nvidia-open"` would handle early modesetting and initramfs hooks for you.

## Minor suggestions

- Add `htop` or `btop` — `fastfetch` shows info but not live monitoring.
- Consider `eza` as a modern `ls` replacement (since you're already using fish).
- `plasma-login-manager` is the new replacement for SDDM — make sure you're on a Plasma version that supports it (6.3+).
- Consider putting this in a git repo for version tracking.
