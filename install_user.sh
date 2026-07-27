#!/bin/bash
set -e

echo "=== Installing Google Input Tools for Ubuntu ==="

# Check/install system dependencies if missing
if ! python3 -c "import gi; gi.require_version('IBus', '1.0'); from gi.repository import IBus" 2>/dev/null; then
    echo "Installing required system packages (ibus, python3-gi)..."
    apt update || true
    apt install -y ibus python3-gi gir1.2-ibus-1.0 python3-urllib3 || true
fi

# Detect target user home directory
if [ -n "$SUDO_USER" ]; then
    TARGET_HOME="/home/$SUDO_USER"
    TARGET_USER="$SUDO_USER"
elif [ "$(whoami)" = "root" ] && [ -d "/home/amit" ]; then
    TARGET_HOME="/home/amit"
    TARGET_USER="amit"
else
    TARGET_HOME="$HOME"
    TARGET_USER="$(whoami)"
fi

echo "Installing for user: $TARGET_USER ($TARGET_HOME)"

mkdir -p "$TARGET_HOME/.local/share/ibus-google-input-tools"
mkdir -p "$TARGET_HOME/.local/share/ibus/component"
mkdir -p "$TARGET_HOME/.local/bin"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy engine files
cp "$SCRIPT_DIR/ibus-google-input-tools.py" "$TARGET_HOME/.local/share/ibus-google-input-tools/"
cp "$SCRIPT_DIR/user_dict_manager.py" "$TARGET_HOME/.local/share/ibus-google-input-tools/"
chmod +x "$TARGET_HOME/.local/share/ibus-google-input-tools/ibus-google-input-tools.py"

# Copy CLI dict tool
cp "$SCRIPT_DIR/ibus-git-dict.py" "$TARGET_HOME/.local/bin/ibus-git-dict"
chmod +x "$TARGET_HOME/.local/bin/ibus-git-dict"

# Also copy to /usr/local/bin for global access if root
if [ "$(id -u)" -eq 0 ]; then
    cp "$SCRIPT_DIR/ibus-git-dict.py" /usr/local/bin/ibus-git-dict 2>/dev/null || true
    chmod +x /usr/local/bin/ibus-git-dict 2>/dev/null || true
    mkdir -p /usr/share/ibus-google-input-tools 2>/dev/null || true
    cp "$SCRIPT_DIR/ibus-google-input-tools.py" /usr/share/ibus-google-input-tools/ 2>/dev/null || true
    cp "$SCRIPT_DIR/user_dict_manager.py" /usr/share/ibus-google-input-tools/ 2>/dev/null || true
    mkdir -p /usr/share/ibus/component 2>/dev/null || true
    cp "$SCRIPT_DIR/google-input-tools-hi.xml" /usr/share/ibus/component/ 2>/dev/null || true
fi

# Create user component XML
cat << EOF > "$TARGET_HOME/.local/share/ibus/component/google-input-tools-hi.xml"
<?xml version="1.0" encoding="utf-8"?>
<component>
	<name>org.freedesktop.IBus.GoogleInputTools</name>
	<description>Google Input Tools (Hindi) Engine</description>
	<version>1.1</version>
	<license>GPL</license>
	<author>Google Input Tools Ubuntu Wrapper</author>
	<exec>$TARGET_HOME/.local/share/ibus-google-input-tools/ibus-google-input-tools.py</exec>
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

# Ensure file ownership if run under root/sudo
if [ "$(id -u)" -eq 0 ]; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/ibus-google-input-tools" 2>/dev/null || true
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/ibus/component/google-input-tools-hi.xml" 2>/dev/null || true
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/bin/ibus-git-dict" 2>/dev/null || true
fi

echo ""
echo "=== Installation Complete! ==="
echo "Note: If running as root, switch back to your normal user '$TARGET_USER' and run:"
echo "  ibus restart"
echo "  ibus-git-dict --import-dic /path/to/gg.dic"
echo ""
echo "Next steps on Ubuntu Settings:"
echo "1. Open Settings -> Keyboard -> Input Sources -> Click Add (+)"
echo "2. Click 'Other' (3 vertical dots) -> Search for 'Hindi'"
echo "3. Select 'Google Input Tools (Hindi)'"
echo "4. Press Super+Space to switch to Google Input Tools!"
