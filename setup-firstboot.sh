#!/bin/bash
# Run as root on first real boot (systemd running)
set -e

# --- Restore homed signing keys (if preserved from previous install) ---

if [[ -d /home/homed-keys ]]; then
  cp /home/homed-keys/local.private /home/homed-keys/local.public /var/lib/systemd/home/
  chmod 600 /var/lib/systemd/home/local.private
  chmod 644 /var/lib/systemd/home/local.public
  systemctl restart systemd-homed
  sleep 2
  echo "Restored homed signing keys from previous install"
fi

# --- User (encrypted home via systemd-homed) ---

if homectl inspect xxorza &>/dev/null; then
  echo "User xxorza already exists (home preserved from previous install), activating..."
  until homectl activate xxorza; do
    echo "Activation failed, try again."
  done
  homectl update xxorza --shell=/bin/fish --member-of=wheel
else
  until homectl create xxorza --storage=luks --fs-type=btrfs --member-of=wheel --shell=/bin/fish; do
    echo "User creation failed, try again."
  done
fi

# --- Save homed signing keys for future reinstalls ---

mkdir -p /home/homed-keys
cp /var/lib/systemd/home/local.private /var/lib/systemd/home/local.public /home/homed-keys/

# --- Firewall ---

ufw default deny incoming
ufw default allow outgoing
ufw enable
systemctl enable ufw.service

# --- Copy user setup script ---

cp /root/setup-user.sh /home/xxorza/setup-user.sh
chown xxorza:xxorza /home/xxorza/setup-user.sh

# cleanup
rm /root/setup-firstboot.sh /root/setup-user.sh
