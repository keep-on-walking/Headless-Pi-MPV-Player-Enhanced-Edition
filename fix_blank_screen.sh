#!/bin/bash
#
# Screen Blanking Script for Raspberry Pi
# Ensures black screen when no video is playing
#
# GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
# Author: keep-on-walking
#

# Function to blank a specific console
blank_console() {
    local tty=$1
    
    if [ -e "$tty" ]; then
        # Disable screen blanking timeout
        setterm -blank 0 -powersave off -powerdown 0 > "$tty" 2>/dev/null || true
        
        # Disable console cursor blinking
        setterm -cursor off > "$tty" 2>/dev/null || true
        
        # Clear screen to black
        clear > "$tty" 2>/dev/null || true
        
        # Set console to black background
        echo -en "\033[40m\033[2J\033[H" > "$tty" 2>/dev/null || true
    fi
}

# Blank all virtual consoles
for i in {0..6}; do
    blank_console "/dev/tty$i"
done

# Also blank the current console
blank_console "$(tty 2>/dev/null || echo /dev/tty1)"

# Disable kernel messages to console
dmesg -n 1 2>/dev/null || true

# Hide cursor on framebuffer console
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null || true

# Function to update cmdline file
update_cmdline() {
    local cmdline_file=$1
    
    if [ -f "$cmdline_file" ]; then
        # Backup original
        cp "$cmdline_file" "${cmdline_file}.backup" 2>/dev/null || true
        
        local current=$(cat "$cmdline_file")
        local modified="$current"
        
        # Add parameters if not present
        [[ ! "$modified" =~ "consoleblank=0" ]] && modified="$modified consoleblank=0"
        [[ ! "$modified" =~ "logo.nologo" ]] && modified="$modified logo.nologo"
        [[ ! "$modified" =~ "quiet" ]] && modified="$modified quiet"
        [[ ! "$modified" =~ "loglevel=0" ]] && modified="$modified loglevel=0"
        [[ ! "$modified" =~ "vt.global_cursor_default=0" ]] && modified="$modified vt.global_cursor_default=0"
        [[ ! "$modified" =~ "plymouth.enable=0" ]] && modified="$modified plymouth.enable=0"
        [[ ! "$modified" =~ "console=tty3" ]] && modified="$modified console=tty3"
        [[ ! "$modified" =~ "systemd.show_status=false" ]] && modified="$modified systemd.show_status=false"
        
        # Write back if changed
        if [ "$current" != "$modified" ]; then
            echo "$modified" > "$cmdline_file"
        fi
    fi
}

# Update cmdline for older Pi OS (Bullseye and earlier)
update_cmdline "/boot/cmdline.txt"

# Update cmdline for newer Pi OS (Bookworm and later)
update_cmdline "/boot/firmware/cmdline.txt"

# Disable Getty on tty1 to prevent login prompt
systemctl stop getty@tty1.service 2>/dev/null || true
systemctl mask getty@tty1.service 2>/dev/null || true

# Create override directory for getty service
mkdir -p /etc/systemd/system/getty@tty1.service.d/ 2>/dev/null || true

# Configure Getty to not clear screen and not show login
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf <<EOF
[Service]
TTYVTDisallocate=no
StandardInput=null
StandardOutput=null
StandardError=null
ExecStart=
ExecStart=-/bin/sh -c 'setterm -blank 0 -cursor off > /dev/tty1; clear > /dev/tty1; sleep infinity'
EOF

# Disable boot splash and messages
if [ -f /boot/config.txt ]; then
    # Backup config.txt
    cp /boot/config.txt /boot/config.txt.backup 2>/dev/null || true
    
    # Add/update disable_splash
    if grep -q "^disable_splash=" /boot/config.txt; then
        sed -i 's/^disable_splash=.*/disable_splash=1/' /boot/config.txt
    else
        echo "disable_splash=1" >> /boot/config.txt
    fi
    
    # Add/update avoid_warnings
    if grep -q "^avoid_warnings=" /boot/config.txt; then
        sed -i 's/^avoid_warnings=.*/avoid_warnings=1/' /boot/config.txt
    else
        echo "avoid_warnings=1" >> /boot/config.txt
    fi
fi

# Same for newer firmware location
if [ -f /boot/firmware/config.txt ]; then
    cp /boot/firmware/config.txt /boot/firmware/config.txt.backup 2>/dev/null || true
    
    if grep -q "^disable_splash=" /boot/firmware/config.txt; then
        sed -i 's/^disable_splash=.*/disable_splash=1/' /boot/firmware/config.txt
    else
        echo "disable_splash=1" >> /boot/firmware/config.txt
    fi
    
    if grep -q "^avoid_warnings=" /boot/firmware/config.txt; then
        sed -i 's/^avoid_warnings=.*/avoid_warnings=1/' /boot/firmware/config.txt
    else
        echo "avoid_warnings=1" >> /boot/firmware/config.txt
    fi
fi

# Mask systemd services that output to console
systemctl mask systemd-vconsole-setup.service 2>/dev/null || true

# Configure systemd to not show status on console
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/no-console-output.conf <<EOF
[Manager]
ShowStatus=no
LogLevel=err
LogTarget=journal
EOF

# Reload systemd to apply changes
systemctl daemon-reload 2>/dev/null || true




