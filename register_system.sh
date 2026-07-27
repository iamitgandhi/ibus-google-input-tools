#!/bin/bash
set -e

echo "=== Updating Engine with D-Bus Name Request & Resetting IBus ==="

# Create directories
sudo mkdir -p /usr/share/ibus-google-input-tools
sudo mkdir -p /usr/share/ibus/component
mkdir -p ~/.local/share/ibus-google-input-tools
mkdir -p ~/.local/share/ibus/component

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy engine script & user dict manager to system and local paths
sudo cp "$SCRIPT_DIR/ibus-google-input-tools.py" /usr/share/ibus-google-input-tools/
sudo cp "$SCRIPT_DIR/user_dict_manager.py" /usr/share/ibus-google-input-tools/
sudo chmod +x /usr/share/ibus-google-input-tools/ibus-google-input-tools.py

cp "$SCRIPT_DIR/ibus-google-input-tools.py" ~/.local/share/ibus-google-input-tools/
cp "$SCRIPT_DIR/user_dict_manager.py" ~/.local/share/ibus-google-input-tools/
chmod +x ~/.local/share/ibus-google-input-tools/ibus-google-input-tools.py

# Write system component XML
cat << 'EOF' | sudo tee /usr/share/ibus/component/google-input-tools-hi.xml > /dev/null
<?xml version="1.0" encoding="utf-8"?>
<component>
	<name>org.freedesktop.IBus.GoogleInputTools</name>
	<description>Google Input Tools (Hindi) Engine</description>
	<version>1.1</version>
	<license>GPL</license>
	<author>Google Input Tools Ubuntu Wrapper</author>
	<exec>/usr/share/ibus-google-input-tools/ibus-google-input-tools.py --ibus</exec>
	<textdomain>ibus-google-input-tools</textdomain>
	<engines>
		<engine>
			<name>google-input-tools-hi</name>
			<language>hi</language>
			<license>GPL</license>
			<author>Google Input Tools</author>
			<icon>google-input-tools</icon>
			<layout>us</layout>
			<longname>Google Input Tools (Hindi)</longname>
			<description>Google Transliteration for Hindi with User Dictionary</description>
			<rank>99</rank>
		</engine>
	</engines>
</component>
EOF

# Reset IBus
> /tmp/ibus-git.log 2>/dev/null || true
pkill -f ibus-google-input-tools || true
ibus restart || ibus-daemon -d -x

echo "=== System Update Complete! ==="
