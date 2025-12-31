# Screen Blanking Troubleshooting Guide

If you see console text/cursor on your display when no video is playing, follow these steps:

## Quick Fix (Immediate)

Run this command to blank the screen right now:
```bash
sudo /usr/local/bin/blank_screen_now.sh
```

This will immediately hide all console text and cursor.

## Permanent Fix (Survives Reboot)

### Option 1: Ensure Service is Running

Check if the blank-screen service is running:
```bash
sudo systemctl status blank-screen.service
```

If it's not running or failed, restart it:
```bash
sudo systemctl restart blank-screen.service
```

Enable it to run on boot:
```bash
sudo systemctl enable blank-screen.service
```

### Option 2: Verify Boot Configuration

The screen blanking script modifies `/boot/cmdline.txt`. Check if it was updated:
```bash
cat /boot/cmdline.txt | grep consoleblank
```

You should see `consoleblank=0` in the output. If not, add it manually:
```bash
sudo nano /boot/cmdline.txt
```

Add `consoleblank=0` to the end of the first line (on the same line as existing parameters), save, and reboot.

### Option 3: Run Script at Boot

If the service isn't working, add the manual script to rc.local:
```bash
sudo nano /etc/rc.local
```

Add this line before `exit 0`:
```bash
/usr/local/bin/blank_screen_now.sh &
```

Save and reboot.

## Testing After Reboot

After making changes:
1. Reboot your Pi: `sudo reboot`
2. Wait for boot to complete
3. Check if screen is black
4. If not, run: `sudo /usr/local/bin/blank_screen_now.sh`

## Why Does Text Appear?

Console text can appear because:
- Getty services are running on TTY consoles
- Kernel messages are being displayed
- Systemd status messages appear during boot
- The framebuffer cursor is visible

The screen blanking scripts address all of these issues.

## Alternative: Disable Getty Login Prompts

If you don't need console login, you can disable Getty entirely:
```bash
sudo systemctl mask getty@tty1.service
sudo systemctl mask serial-getty@ttyS0.service
```

This prevents login prompts from appearing on the screen.

## Verify Everything is Working

Check all screen blanking components:
```bash
# Check if service is active
systemctl is-active blank-screen.service

# Check if scripts exist
ls -la /usr/local/bin/fix_blank_screen.sh
ls -la /usr/local/bin/blank_screen_now.sh

# Check if consoleblank is set
cat /boot/cmdline.txt | grep consoleblank

# Check framebuffer cursor
cat /sys/class/graphics/fbcon/cursor_blink
```

The cursor_blink file should contain `0`.

## Still Having Issues?

If none of the above works:

1. Make sure the HDMI display is connected during boot
2. Try a different HDMI cable
3. Check HDMI mode in `/boot/config.txt`
4. Run the manual blank script after each video stops playing

## Need Help?

Report issues on GitHub:
https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/issues
