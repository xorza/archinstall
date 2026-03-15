#!/bin/bash
set -e

# Enable Nvidia backlight control
echo 'options nvidia NVreg_RegistryDwords=EnableBrightnessControl=1' | sudo tee /etc/modprobe.d/20-nvidia-backlight.conf

# Add acpi_backlight=nvidia_wmi_ec to your boot entry's options line
echo "NOTE: Manually add 'acpi_backlight=nvidia_wmi_ec' to your boot entry options in /boot/loader/entries/*.conf"
