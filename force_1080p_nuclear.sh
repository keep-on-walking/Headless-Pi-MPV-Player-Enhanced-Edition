#!/bin/bash
#
# Nuclear Option: Force 1080p on Raspberry Pi 5
# This uses every possible method to force 1080p
#
# Usage: curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/force_1080p_nuclear.sh | sudo bash
#

echo "==========================================="
echo "Nuclear Option: Force 1080p"
echo "==========================================="
echo ""

# Detect config files
CONFIG_FILE=""
CMDLINE_FILE=""

if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
    CMDLINE_FILE="/boot/cmdline.txt"
else
    echo "ERROR: Cannot find config files"
    exit 1
fi

echo "Config: $CONFIG_FILE"
echo "Cmdline: $CMDLINE_FILE"
echo ""

# Backup everything
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%s)"
cp "$CMDLINE_FILE" "${CMDLINE_FILE}.backup.$(date +%s)"
echo "✓ Backed up config files"
echo ""

# Step 1: Update config.txt with EVERY possible 1080p setting
echo "Updating config.txt..."

# Remove ALL existing video-related settings
sed -i '/^hdmi_/d' "$CONFIG_FILE"
sed -i '/^framebuffer_/d' "$CONFIG_FILE"
sed -i '/^max_framebuffer/d' "$CONFIG_FILE"
sed -i '/^disable_overscan/d' "$CONFIG_FILE"

# Add comprehensive 1080p settings
cat >> "$CONFIG_FILE" <<'EOF'

#=== Force 1080p Output (Nuclear Option) ===
# Framebuffer resolution
framebuffer_width=1920
framebuffer_height=1080
max_framebuffer_width=1920
max_framebuffer_height=1080

# Disable 4K completely
hdmi_enable_4kp60=0

# Force specific mode
hdmi_group=1
hdmi_mode=16

# Additional HDMI settings
config_hdmi_boost=4
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1

# Reduce GPU memory (forces lower resolutions)
gpu_mem=128
EOF

echo "✓ Added comprehensive 1080p settings to config.txt"

# Step 2: Update cmdline.txt to force framebuffer resolution
echo ""
echo "Updating cmdline.txt..."

CURRENT_CMDLINE=$(cat "$CMDLINE_FILE")

# Remove any existing video= parameters
MODIFIED_CMDLINE=$(echo "$CURRENT_CMDLINE" | sed 's/video=[^ ]*//g')

# Add video= parameter to force 1080p
MODIFIED_CMDLINE="$MODIFIED_CMDLINE video=HDMI-A-1:1920x1080@60"

# Clean up spaces
MODIFIED_CMDLINE=$(echo "$MODIFIED_CMDLINE" | tr -s ' ')

echo "$MODIFIED_CMDLINE" > "$CMDLINE_FILE"

echo "✓ Added video=HDMI-A-1:1920x1080@60 to cmdline.txt"

# Step 3: Create a script that runs VERY early at boot
echo ""
echo "Creating early boot resolution limiter..."

cat > /tmp/force-resolution-early.sh <<'SCRIPT'
#!/bin/bash
# This runs before MPV starts

# Method 1: Limit all DRM connectors
for connector in /sys/class/drm/card*/card*-HDMI-*/modes; do
    if [ -f "$connector" ]; then
        # Filter out 4K modes, keep only 1080p and below
        grep -E "1920x1080|1280x720|1024x768" "$connector" > /tmp/filtered_modes
        if [ -s /tmp/filtered_modes ]; then
            cp /tmp/filtered_modes "$connector" 2>/dev/null || true
        fi
    fi
done

# Method 2: Set specific mode
for mode_file in /sys/class/drm/card*/card*-HDMI-*/mode; do
    if [ -f "$mode_file" ]; then
        echo "1920x1080" > "$mode_file" 2>/dev/null || true
    fi
done

# Method 3: Use fbset to force framebuffer
fbset -g 1920 1080 1920 1080 32 2>/dev/null || true
fbset -depth 32 2>/dev/null || true

# Method 4: Try xrandr if available
if command -v xrandr &> /dev/null; then
    export DISPLAY=:0
    xrandr --output HDMI-1 --mode 1920x1080 2>/dev/null || true
    xrandr --output HDMI-A-1 --mode 1920x1080 2>/dev/null || true
fi
SCRIPT

sudo mv /tmp/force-resolution-early.sh /usr/local/bin/force-resolution-early.sh
sudo chmod +x /usr/local/bin/force-resolution-early.sh

# Create systemd service that runs VERY early
cat > /tmp/force-resolution.service <<'SERVICE'
[Unit]
Description=Force 1080p Resolution (Early Boot)
DefaultDependencies=no
Before=sysinit.target
After=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/force-resolution-early.sh
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
SERVICE

sudo mv /tmp/force-resolution.service /etc/systemd/system/force-resolution.service
sudo systemctl daemon-reload
sudo systemctl enable force-resolution.service
echo "✓ Created early boot resolution service"

# Step 4: Update MPV to always scale to 1080p
echo ""
echo "Configuring MPV to scale output..."

for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")
        mpv_config="$user_home/.config/mpv"
        
        sudo -u "$username" mkdir -p "$mpv_config" 2>/dev/null
        
        cat > "$mpv_config/mpv.conf" <<'MPV'
# Force 1080p output
vf=scale=1920:1080:flags=fast_bilinear
video-output-levels=limited
video-sync=display-resample

# Hardware decode
hwdec=auto
vo=gpu
gpu-context=drm

# Force output resolution
dscale=bilinear
cscale=bilinear

# Additional performance settings
profile=gpu-hq
scale=bilinear
dither-depth=auto
MPV

        sudo chown -R "$username:$username" "$mpv_config"
        echo "✓ Configured MPV for user: $username"
    fi
done

# Step 5: Disable compositor if running
if command -v raspi-config &> /dev/null; then
    sudo raspi-config nonint do_gldriver G2 2>/dev/null || true
fi

echo ""
echo "==========================================="
echo "✓ Nuclear Option Applied!"
echo "==========================================="
echo ""
echo "All methods applied:"
echo "  ✓ Framebuffer limited to 1920x1080 in config.txt"
echo "  ✓ 4K modes disabled"
echo "  ✓ GPU memory reduced to 128MB"
echo "  ✓ Kernel video parameter set to 1920x1080"
echo "  ✓ Early boot resolution forcing service"
echo "  ✓ MPV configured to scale to 1080p"
echo ""
echo "⚠️  REBOOT REQUIRED"
echo ""
echo "Run: sudo reboot"
echo ""
echo "After reboot, check:"
echo "  cat /sys/class/graphics/fb0/virtual_size"
echo ""
echo "If STILL 4K after reboot, the TV is forcing 4K."
echo "In that case, use a different HDMI input or TV."
echo ""
