#!/bin/bash
#
# Screen Blanking Script for Raspberry Pi
# Ensures black screen when no video is playing
#
# GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
# Author: keep-on-walking
#

# Disable screen blanking timeout
setterm -blank 0 -powersave off -powerdown 0 2>/dev/null || true

# Disable console cursor blinking
setterm -cursor off 2>/dev/null || true

# Clear screen to black
clear

# Set console to black background
if [ -t 0 ]; then
    echo -en "\033[40m\033[2J\033[H"
fi

# Disable console messages
dmesg -n 1 2>/dev/null || true
