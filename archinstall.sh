#!/bin/bash
set -e

pacman -Syu archinstall --noconfirm
curl -O https://cssodessa.com/user_configuration.json
curl -O https://cssodessa.com/user_credentials.json
archinstall --config user_configuration.json --creds user_credentials.json
