#!/bin/bash
set -e

echo "=== Syncing Engine Code to System Path & Resetting IBus ==="

# Copy the updated local engine code to system path
sudo cp /home/amit/.local/share/ibus-google-input-tools/ibus-google-input-tools.py /usr/share/ibus-google-input-tools/ibus-google-input-tools.py
sudo cp /home/amit/.local/share/ibus-google-input-tools/user_dict_manager.py /usr/share/ibus-google-input-tools/user_dict_manager.py
sudo chmod +x /usr/share/ibus-google-input-tools/ibus-google-input-tools.py

# Restart IBus daemon
> /tmp/ibus-git.log 2>/dev/null || true
pkill -f ibus-google-input-tools || true
ibus restart || ibus-daemon -d -x

echo "=== Update Successful! ==="
