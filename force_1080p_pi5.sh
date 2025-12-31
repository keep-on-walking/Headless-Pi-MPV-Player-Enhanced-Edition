#!/bin/bash
#
# Force 1080p on Raspberry Pi 5 (and Pi 4 with KMS)
# Pi 5 uses KMS/DRM instead of legacy firmware video modes
#
# Usage: curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/force_1080p_pi5.sh | sudo bash
#

echo "==========================================="
echo "Force 1080p for Raspberry Pi 5"
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

# Remove old hdmi settings that don't work on Pi 5
sed -i '/^hdmi_mode=/d' "$CONFIG_FILE"
sed -i '/^hdmi_group=/d' "$CONFIG_FILE"
sed -i '/^hdmi_drive=/d' "$CONFIG_FILE"
sed -i '/^hdmi_force_hotplug=/d' "$CONFIG_FILE"

# Remove any existing hdmi_timings or video mode settings
sed -i '/^hdmi_timings=/d' "$CONFIG_FILE"
sed -i '/^hdmi_cvt=/d' "$CONFIG_FILE"

# For Pi 5, we need to use KMS mode settings
# Check if dtoverlay for vc4-kms-v3d is present
if ! grep -q "^dtoverlay=vc4-kms-v3d" "$CONFIG_FILE"; then
    echo "dtoverlay=vc4-kms-v3d" >> "$CONFIG_FILE"
    echo "✓ Added vc4-kms-v3d overlay"
fi

# Add framebuffer resolution forcing
cat >> "$CONFIG_FILE" <<'EOF'

# Force 1080p output for Pi 5 (KMS mode)
# This limits the framebuffer to 1080p
framebuffer_width=1920
framebuffer_height=1080

# Disable 4K modes
hdmi_enable_4kp60=0
EOF

echo "✓ Added 1080p framebuffer settings"
echo ""

# Also create a boot script to set the mode via KMS
echo "Creating boot-time mode setting script..."

# Create a systemd service to force the mode at boot
cat > /tmp/force-1080p.sh <<'SCRIPT'
#!/bin/bash
# Force 1080p mode using KMS

# Wait for DRM to be ready
sleep 2

# Try to set mode using xrandr if X is running, or direct KMS
if command -v xrandr &> /dev/null; then
    export DISPLAY=:0
    xrandr --output HDMI-1 --mode 1920x1080 --rate 60 2>/dev/null || true
    xrandr --output HDMI-2 --mode 1920x1080 --rate 60 2>/dev/null || true
fi

# Set via KMS directly
if [ -e /sys/class/drm/card1-HDMI-A-1/mode ]; then
    echo "1920x1080@60" > /sys/class/drm/card1-HDMI-A-1/mode 2>/dev/null || true
fi

if [ -e /sys/class/drm/card1-HDMI-A-2/mode ]; then
    echo "1920x1080@60" > /sys/class/drm/card1-HDMI-A-2/mode 2>/dev/null || true
fi

# Also update framebuffer
fbset -g 1920 1080 1920 1080 32 2>/dev/null || true
SCRIPT

sudo mv /tmp/force-1080p.sh /usr/local/bin/force-1080p.sh
sudo chmod +x /usr/local/bin/force-1080p.sh

# Create systemd service
cat > /tmp/force-1080p.service <<'SERVICE'
[Unit]
Description=Force 1080p HDMI Output
After=sysinit.target
Before=headless-mpv-player.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/force-1080p.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

sudo mv /tmp/force-1080p.service /etc/systemd/system/force-1080p.service
sudo systemctl daemon-reload
sudo systemctl enable force-1080p.service
echo "✓ Created boot-time mode forcing service"

# Also update the MPV player config to force 1080p in software
MPV_CONFIG_DIR="/home/${SUDO_USER:-$USER}/.config/mpv"
mkdir -p "$MPV_CONFIG_DIR"

cat > "$MPV_CONFIG_DIR/mpv.conf" <<'MPV_CONF'
# Force 1080p output
vf=scale=1920:1080
video-output-levels=limited
video-sync=display-resample

# Hardware acceleration for Pi 5
hwdec=auto
gpu-context=drm
vo=gpu

# Limit to 1080p
dscale=bilinear
cscale=bilinear
MPV_CONF

chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$MPV_CONFIG_DIR"
echo "✓ Created MPV config to force 1080p scaling"

echo ""
echo "==========================================="
echo "✓ Pi 5 1080p Configuration Complete!"
echo "==========================================="
echo ""
echo "Changes made:"
echo "  1. Framebuffer forced to 1920x1080"
echo "  2. 4K modes disabled"
echo "  3. Boot-time mode forcing service created"
echo "  4. MPV configured to scale to 1080p"
echo ""
echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo ""
echo "Run: sudo reboot"
echo ""
echo "After reboot, check with:"
echo "  cat /sys/class/graphics/fb0/virtual_size"
echo "  (should show: 1920,1080)"
echo ""
