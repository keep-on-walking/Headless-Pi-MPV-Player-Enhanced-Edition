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

# Disable console blanking in kernel parameters (persistent)
if [ -f /boot/cmdline.txt ]; then
    if ! grep -q "consoleblank=0" /boot/cmdline.txt; then
        # Backup original
        cp /boot/cmdline.txt /boot/cmdline.txt.backup 2>/dev/null || true
        # Add consoleblank=0 to disable console blanking
        sed -i '1 s/$/ consoleblank=0/' /boot/cmdline.txt 2>/dev/null || true
    fi
fi

# For Raspberry Pi OS Bookworm and later - check for firmware config
if [ -f /boot/firmware/cmdline.txt ]; then
    if ! grep -q "consoleblank=0" /boot/firmware/cmdline.txt; then
        cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.backup 2>/dev/null || true
        sed -i '1 s/$/ consoleblank=0/' /boot/firmware/cmdline.txt 2>/dev/null || true
    fi
fi

# Disable Getty on tty1 to prevent login prompt
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

# Reload systemd to apply changes
systemctl daemon-reload 2>/dev/null || true


