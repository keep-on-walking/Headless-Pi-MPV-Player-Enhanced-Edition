#!/bin/bash
#
# Ultimate Screen Blanking Fix
# This will definitely suppress all boot messages
#
# Usage: curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/ultimate_blank_fix.sh | sudo bash
#

echo "==========================================="
echo "Ultimate Screen Blanking Fix"
echo "==========================================="
echo ""

# Detect which cmdline.txt to use
CMDLINE_FILE=""
if [ -f /boot/firmware/cmdline.txt ]; then
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
elif [ -f /boot/cmdline.txt ]; then
    CMDLINE_FILE="/boot/cmdline.txt"
else
    echo "ERROR: Cannot find cmdline.txt"
    exit 1
fi

echo "Found cmdline: $CMDLINE_FILE"
echo ""

# Backup
cp "$CMDLINE_FILE" "${CMDLINE_FILE}.backup.$(date +%s)"

# Read current cmdline
CURRENT=$(cat "$CMDLINE_FILE")

# Remove any existing console= parameters first
MODIFIED=$(echo "$CURRENT" | sed 's/console=[^ ]*//g')

# Build new parameters
NEW_PARAMS="console=null"  # This is the nuclear option - no console output at all
NEW_PARAMS="$NEW_PARAMS quiet"
NEW_PARAMS="$NEW_PARAMS loglevel=0"
NEW_PARAMS="$NEW_PARAMS logo.nologo"
NEW_PARAMS="$NEW_PARAMS vt.global_cursor_default=0"
NEW_PARAMS="$NEW_PARAMS consoleblank=0"
NEW_PARAMS="$NEW_PARAMS systemd.show_status=false"
NEW_PARAMS="$NEW_PARAMS plymouth.enable=0"

# Add each parameter if not already present
for param in $NEW_PARAMS; do
    if [[ ! "$MODIFIED" =~ "${param%=*}" ]]; then
        MODIFIED="$MODIFIED $param"
    fi
done

# Clean up extra spaces
MODIFIED=$(echo "$MODIFIED" | tr -s ' ')

# Write new cmdline
echo "$MODIFIED" > "$CMDLINE_FILE"

echo "✓ Updated kernel command line"
echo ""
echo "New cmdline.txt:"
cat "$CMDLINE_FILE"
echo ""

# Disable Getty completely
echo "Disabling Getty on tty1..."
systemctl stop getty@tty1.service 2>/dev/null
systemctl disable getty@tty1.service 2>/dev/null
systemctl mask getty@tty1.service 2>/dev/null
echo "✓ Getty disabled"
echo ""

# Configure systemd
echo "Configuring systemd..."
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/no-console-output.conf <<'EOF'
[Manager]
ShowStatus=no
LogLevel=err
LogTarget=journal
DefaultStandardOutput=null
DefaultStandardError=null
EOF

mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<'EOF'
[Unit]
ConditionPathExists=!/dev/null

[Service]
ExecStart=
StandardInput=null
StandardOutput=null
StandardError=null
EOF

systemctl daemon-reload
echo "✓ Systemd configured"
echo ""

# Disable config.txt messages
CONFIG_FILE=""
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_FILE="/boot/config.txt"
fi

if [ -n "$CONFIG_FILE" ]; then
    echo "Updating config.txt..."
    
    # Backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%s)"
    
    # Add or update settings
    for setting in "disable_splash=1" "avoid_warnings=1"; do
        key="${setting%=*}"
        if grep -q "^${key}=" "$CONFIG_FILE"; then
            sed -i "s/^${key}=.*/${setting}/" "$CONFIG_FILE"
        else
            echo "$setting" >> "$CONFIG_FILE"
        fi
    done
    
    echo "✓ config.txt updated"
    echo ""
fi

# Blank screen immediately
echo "Blanking screen now..."
for i in {0..6}; do
    if [ -e "/dev/tty$i" ]; then
        setterm -blank 0 -cursor off > /dev/tty$i 2>/dev/null
        clear > /dev/tty$i 2>/dev/null
        echo -en "\033[40m\033[2J\033[H" > /dev/tty$i 2>/dev/null
    fi
done

# Hide framebuffer cursor
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null

# Disable kernel messages
dmesg -n 1

echo "✓ Screen blanked"
echo ""
echo "==========================================="
echo "✓ All fixes applied successfully!"
echo "==========================================="
echo ""
echo "IMPORTANT: You MUST reboot for changes to take effect"
echo ""
echo "Run: sudo reboot"
echo ""
echo "After reboot, the screen should be completely black"
echo "from power-on through the entire boot process."
echo ""
