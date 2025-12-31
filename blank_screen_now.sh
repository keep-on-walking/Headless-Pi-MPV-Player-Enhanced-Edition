#!/bin/bash
#
# Manual Screen Blanking Script
# Run this if the screen is not blank after boot
#
# Usage: sudo /usr/local/bin/blank_screen_now.sh
#

echo "Blanking screen..."

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

echo ""
echo "Screen blanking applied. The screen should now be black."
echo "If text reappears after video playback, run this script again."
