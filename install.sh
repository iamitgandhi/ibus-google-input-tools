#!/bin/bash
set -e

echo "=== Installing Google Input Tools for Ubuntu (IBus Engine + User Dict Manager) ==="

# Check dependencies
sudo apt update
sudo apt install -y ibus python3-gi gir1.2-ibus-1.0 python3-urllib3

# Create destination directories
sudo mkdir -p /usr/share/ibus-google-input-tools
sudo mkdir -p /usr/share/ibus/component

# Copy files
sudo cp ibus-google-input-tools.py /usr/share/ibus-google-input-tools/
sudo cp user_dict_manager.py /usr/share/ibus-google-input-tools/
sudo chmod +x /usr/share/ibus-google-input-tools/ibus-google-input-tools.py

# Install Dictionary CLI helper
sudo cp ibus-git-dict.py /usr/local/bin/ibus-git-dict
sudo chmod +x /usr/local/bin/ibus-git-dict

# Copy XML configuration
sudo cp google-input-tools-hi.xml /usr/share/ibus/component/

# Restart IBus
ibus restart

echo ""
echo "=== Installation Complete! ==="
echo "To import your custom dictionary (gg.dic):"
echo "  ibus-git-dict --import-dic /path/to/gg.dic"
echo ""
echo "Next steps on Ubuntu:"
echo "1. Open Settings -> Keyboard -> Input Sources -> Add (+)"
echo "2. Select 'Hindi' -> Select 'Google Input Tools (Hindi)'"
echo "3. Press Super+Space to activate Google Input Tools!"
