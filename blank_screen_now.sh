#!/bin/bash
#
# Manual Screen Blanking Script
# Run this if the screen is not blank after boot
#
# Usage: sudo /usr/local/bin/blank_screen_now.sh
#

echo "Blanking screen and disabling login prompt..."

# Disable Getty on tty1 (prevents login prompt)
echo "Disabling Getty service on tty1..."
systemctl stop getty@tty1.service 2>/dev/null
systemctl mask getty@tty1.service 2>/dev/null
echo "Getty disabled"

# Blank all TTY consoles
for i in {0..6}; do
    if [ -e "/dev/tty$i" ]; then
        setterm -blank 0 -powersave off -powerdown 0 > /dev/tty$i 2>/dev/null
        setterm -cursor off > /dev/tty$i 2>/dev/null
        clear > /dev/tty$i 2>/dev/null
        echo -en "\033[40m\033[2J\033[H" > /dev/tty$i 2>/dev/null
        echo "Blanked tty$i"
    fi
done

# Hide framebuffer cursor
if [ -f /sys/class/graphics/fbcon/cursor_blink ]; then
    echo 0 > /sys/class/graphics/fbcon/cursor_blink
    echo "Disabled framebuffer cursor"
fi

# Disable kernel messages
dmesg -n 1 2>/dev/null
echo "Disabled kernel messages to console"

# Create Getty override to keep screen blank
mkdir -p /etc/systemd/system/getty@tty1.service.d/ 2>/dev/null
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf <<EOF
[Service]
TTYVTDisallocate=no
StandardInput=null
StandardOutput=null
StandardError=null
ExecStart=
ExecStart=-/bin/sh -c 'setterm -blank 0 -cursor off > /dev/tty1; clear > /dev/tty1; sleep infinity'
EOF

systemctl daemon-reload 2>/dev/null
echo "Getty service configured to maintain blank screen"

echo ""
echo "Screen blanking applied successfully!"
echo "The screen should remain black even after reboot."
echo ""
echo "To verify Getty is disabled:"
echo "  systemctl status getty@tty1.service"
echo ""
