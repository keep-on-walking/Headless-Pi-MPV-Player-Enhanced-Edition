#!/bin/bash
# One-liner to fix screen blanking and disable Getty login prompt
# Usage: curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/quick_blank_fix.sh | sudo bash

echo "Fixing screen blanking and boot messages..."

# Disable Getty on tty1
systemctl stop getty@tty1.service 2>/dev/null
systemctl mask getty@tty1.service 2>/dev/null

# Blank all consoles
for i in {0..6}; do
    if [ -e "/dev/tty$i" ]; then
        setterm -blank 0 -cursor off > /dev/tty$i 2>/dev/null
        clear > /dev/tty$i 2>/dev/null
    fi
done

# Hide framebuffer cursor
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null

# Disable kernel messages
dmesg -n 1

# Configure Getty override
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf <<EOF
[Service]
TTYVTDisallocate=no
StandardInput=null
StandardOutput=null
StandardError=null
ExecStart=
ExecStart=-/bin/sh -c 'setterm -blank 0 -cursor off > /dev/tty1; clear > /dev/tty1; sleep infinity'
EOF

# Function to update cmdline
update_cmdline() {
    local cmdline_file=$1
    
    if [ -f "$cmdline_file" ]; then
        cp "$cmdline_file" "${cmdline_file}.backup" 2>/dev/null
        
        local current=$(cat "$cmdline_file")
        local modified="$current"
        
        [[ ! "$modified" =~ "consoleblank=0" ]] && modified="$modified consoleblank=0"
        [[ ! "$modified" =~ "logo.nologo" ]] && modified="$modified logo.nologo"
        [[ ! "$modified" =~ "quiet" ]] && modified="$modified quiet"
        [[ ! "$modified" =~ "loglevel=0" ]] && modified="$modified loglevel=0"
        [[ ! "$modified" =~ "vt.global_cursor_default=0" ]] && modified="$modified vt.global_cursor_default=0"
        [[ ! "$modified" =~ "plymouth.enable=0" ]] && modified="$modified plymouth.enable=0"
        [[ ! "$modified" =~ "console=tty3" ]] && modified="$modified console=tty3"
        [[ ! "$modified" =~ "systemd.show_status=false" ]] && modified="$modified systemd.show_status=false"
        
        if [ "$current" != "$modified" ]; then
            echo "$modified" > "$cmdline_file"
            echo "✓ Updated $cmdline_file"
        fi
    fi
}

# Update both possible locations
update_cmdline "/boot/cmdline.txt"
update_cmdline "/boot/firmware/cmdline.txt"

# Disable boot splash in config.txt
for config_file in /boot/config.txt /boot/firmware/config.txt; do
    if [ -f "$config_file" ]; then
        cp "$config_file" "${config_file}.backup" 2>/dev/null
        
        if grep -q "^disable_splash=" "$config_file"; then
            sed -i 's/^disable_splash=.*/disable_splash=1/' "$config_file"
        else
            echo "disable_splash=1" >> "$config_file"
        fi
        
        if grep -q "^avoid_warnings=" "$config_file"; then
            sed -i 's/^avoid_warnings=.*/avoid_warnings=1/' "$config_file"
        else
            echo "avoid_warnings=1" >> "$config_file"
        fi
        
        echo "✓ Updated $config_file"
    fi
done

# Configure systemd to not show status on console
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/no-console-output.conf <<EOF
[Manager]
ShowStatus=no
LogLevel=err
LogTarget=journal
EOF
echo "✓ Configured systemd for quiet boot"

# Mask unnecessary console services
systemctl mask systemd-vconsole-setup.service 2>/dev/null

systemctl daemon-reload

echo ""
echo "✓ Screen blanking fixed!"
echo "✓ Getty login prompt disabled"
echo "✓ Boot messages suppressed"
echo "✓ Kernel parameters updated"
echo ""
echo "🔄 REBOOT REQUIRED for all changes to take effect"
echo "   Run: sudo reboot"
echo ""
