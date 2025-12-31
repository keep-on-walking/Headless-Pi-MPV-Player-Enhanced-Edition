#!/bin/bash
# One-liner to fix screen blanking and disable Getty login prompt
# Usage: curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/quick_blank_fix.sh | sudo bash

echo "Fixing screen blanking..."

# Disable Getty on tty1
systemctl stop getty@tty1.service
systemctl mask getty@tty1.service

# Blank all consoles
for i in {0..6}; do
    if [ -e "/dev/tty$i" ]; then
        setterm -blank 0 -cursor off > /dev/tty$i 2>/dev/null
        clear > /dev/tty$i 2>/dev/null
    fi
done

# Hide framebuffer cursor
echo 0 > /sys/class/graphics/fbcon/cursor_blink 2>/dev/null

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

systemctl daemon-reload

echo ""
echo "✓ Screen blanking fixed!"
echo "✓ Getty login prompt disabled"
echo "✓ Screen should stay black even after reboot"
echo ""
echo "Reboot now to test: sudo reboot"
