#!/bin/bash
#
# Force 1080p HDMI Output
# Prevents 4K performance issues on Raspberry Pi
#
# Usage: curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/force_1080p.sh | sudo bash
#

echo "==========================================="
echo "Force 1080p HDMI Output"
echo "==========================================="
echo ""

# Detect which config.txt to use
CONFIG_FILE=""
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
else
    echo "ERROR: Cannot find config.txt"
    exit 1
fi

echo "Found config: $CONFIG_FILE"
echo ""

# Backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%s)"
echo "✓ Backed up config.txt"

# Remove any existing hdmi_mode/hdmi_group settings
sed -i '/^hdmi_mode=/d' "$CONFIG_FILE"
sed -i '/^hdmi_group=/d' "$CONFIG_FILE"
sed -i '/^hdmi_drive=/d' "$CONFIG_FILE"

# Add 1080p 60Hz settings at the end
cat >> "$CONFIG_FILE" <<'EOF'

# Force 1080p 60Hz output (prevents 4K performance issues)
hdmi_group=1
hdmi_mode=16
hdmi_drive=2
EOF

echo "✓ Added 1080p settings to config.txt"
echo ""

echo "Settings added:"
echo "  hdmi_group=1   (CEA - TV modes)"
echo "  hdmi_mode=16   (1920x1080 @ 60Hz)"
echo "  hdmi_drive=2   (Force HDMI audio)"
echo ""

# Also update MPV configuration if headless-mpv-config.json exists
if [ -f ~/headless-mpv-config.json ]; then
    echo "Updating MPV configuration..."
    
    # Check if it's valid JSON first
    if python3 -c "import json; json.load(open('${HOME}/headless-mpv-config.json'))" 2>/dev/null; then
        python3 << 'PYTHON_SCRIPT'
import json
import os

config_file = os.path.expanduser('~/headless-mpv-config.json')
with open(config_file, 'r') as f:
    config = json.load(f)

# Add/update resolution hint
if 'hdmi_output' not in config:
    config['hdmi_output'] = 'auto'

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✓ Updated MPV config")
PYTHON_SCRIPT
    else
        echo "⚠ Config file exists but is invalid JSON, skipping"
    fi
fi

echo ""
echo "==========================================="
echo "✓ 1080p Output Configured!"
echo "==========================================="
echo ""
echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo ""
echo "Run: sudo reboot"
echo ""
echo "After reboot, display will be forced to 1920x1080 @ 60Hz"
echo "This will significantly improve video playback performance."
echo ""
