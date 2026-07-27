#!/bin/bash
set -e

echo "=== Redirecting System Component to User Engine ==="

# Update system component XML to execute user engine script directly
sudo sed -i 's|/usr/share/ibus-google-input-tools/ibus-google-input-tools.py|/home/amit/.local/share/ibus-google-input-tools/ibus-google-input-tools.py|g' /usr/share/ibus/component/google-input-tools-hi.xml

# Ensure local engine script has proper execute permissions
chmod +x /home/amit/.local/share/ibus-google-input-tools/ibus-google-input-tools.py

# Restart IBus daemon
pkill -f ibus-google-input-tools || true
ibus restart || ibus-daemon -d -x

# Set active engine to google-input-tools-hi
sleep 1
ibus engine google-input-tools-hi

echo "=== DONE! Current Active Engine: $(ibus engine) ==="
