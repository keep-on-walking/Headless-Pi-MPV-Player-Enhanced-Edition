# Screen Blanking Troubleshooting Guide

If you see console text/cursor on your display when no video is playing, follow these steps:

## Understanding the Issue

The login prompt you see is from the **Getty service** running on tty1 (the console connected to your HDMI display). Even if the screen is blanked, Getty re-clears the screen and shows a login prompt.

**The solution**: Disable Getty on tty1 since you don't need console login when using the web interface.

## Quick Fix (Immediate)

Run this command to blank the screen AND disable the login prompt:
```bash
sudo /usr/local/bin/blank_screen_now.sh
```

This will:
- Immediately blank all consoles
- Disable the Getty login service on tty1
- Configure the system to stay blank after reboot

Then reboot to test:
```bash
sudo reboot
```

## Verify Getty is Disabled

After running the fix, check that Getty is masked:
```bash
systemctl status getty@tty1.service
```

You should see:
```
● getty@tty1.service
     Loaded: masked (Reason: Unit getty@tty1.service is masked.)
     Active: inactive (dead)
```

If it shows "Active: active (running)", the service is still running and needs to be disabled.

## Permanent Fix (Survives Reboot)

### Option 1: Disable Getty Manually

If the automatic script didn't work, manually disable Getty:

```bash
# Stop the Getty service
sudo systemctl stop getty@tty1.service

# Mask it so it never starts again
sudo systemctl mask getty@tty1.service

# Blank the screen now
sudo /usr/local/bin/blank_screen_now.sh

# Reboot to test
sudo reboot
```

### Option 2: Ensure Service is Running

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

The main culprit is **Getty** - the service that provides login prompts on TTY consoles.

Console text can appear because:
- **Getty services** are running on TTY consoles (most common)
- Kernel messages are being displayed
- Systemd status messages appear during boot
- The framebuffer cursor is visible

**The fix**: Disable Getty on tty1 (the HDMI console) since you access the player via web interface.

## How to Permanently Disable Getty

The improved scripts automatically disable Getty, but you can also do it manually:

```bash
# Disable and mask Getty on tty1
sudo systemctl stop getty@tty1.service
sudo systemctl mask getty@tty1.service

# Verify it's masked
systemctl status getty@tty1.service

# Should show: "Loaded: masked"
```

After disabling Getty, the screen will stay black even after reboots.

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
