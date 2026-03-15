sudo nano /etc/modprobe.d/20-nvidia-backlight.conf
options nvidia NVreg_RegistryDwords=EnableBrightnessControl=1

sudo nano /boot/loader/entries/2025-11-22_18-50-43_linux.conf
acpi_backlight=nvidia_wmi_ec
