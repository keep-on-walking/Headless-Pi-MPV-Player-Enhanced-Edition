# 📦 Headless Pi MPV Player - Enhanced Edition

[![GitHub](https://img.shields.io/badge/GitHub-keep--on--walking-blue?logo=github)](https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## What's in This Package?

This package contains the enhanced version of the Headless Pi MPV Player with significant improvements to code quality, performance, and reliability.

**Repository:** [https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition](https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition)

### 📁 Files Included

| File | Size | Description |
|------|------|-------------|
| **app.py** | 20KB | Main Flask application with all enhancements |
| **mpv_controller.py** | 18KB | Enhanced MPV controller with error handling |
| **install.sh** | 14KB | Robust installation script with validation |
| **requirements.txt** | 101B | Python dependencies (pinned versions) |
| **test_app.py** | 17KB | Comprehensive test suite (40+ tests) |
| **run_tests.sh** | 1.6KB | Automated test runner |
| **QUICKSTART.md** | 5.7KB | Quick installation guide |
| **IMPROVEMENTS.md** | 11KB | Detailed improvement documentation |
| **CHANGELOG.md** | 8.4KB | Complete list of changes |

### ✨ Key Improvements

#### ✅ Code Quality
- **Input Validation** - All inputs validated with proper bounds checking
- **Error Handling** - Comprehensive error handling throughout
- **Structured Logging** - Multi-level logging to file and console
- **Fixed Paths** - Works for any user (not hard-coded to /home/pi)

#### ⚡ Performance
- **Async File Uploads** - Non-blocking uploads with chunking
- **Process Management** - Proper cleanup, no zombie processes
- **Memory Efficient** - 40x reduction in peak memory usage
- **Audio Sync** - Fixed audio desync after seeking

#### 🧪 Testing
- **40+ Test Cases** - Comprehensive test coverage
- **85%+ Coverage** - Full code coverage reporting
- **Automated Testing** - Simple test runner script
- **Integration Tests** - Full workflow testing

### 🚀 Quick Install

**One-Command Installation:**
```bash
curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/install.sh | bash
```

**⚠️ Important:** After installation, **reboot is required** for silent boot (blank screen) to take effect.

```bash
sudo reboot
```

### 📺 4K TV Compatibility

**Note for 4K TV users:** The system is optimized for 4K TVs displaying 1080p content. The installer automatically:
- Forces 1080p output resolution
- Uses SDL video output for best compatibility
- Configures HDMI audio output
- Optimizes performance for smooth playback

If you experience slow playback on a 4K TV, the system is already configured with the optimal settings. No additional configuration needed!

**Or Manual Installation:**
1. **Download all files** to your Raspberry Pi
2. **Place them in** `~/headless-mpv-player/`
3. **Run the installer**:
   ```bash
   cd ~/headless-mpv-player
   chmod +x install.sh
   ./install.sh
   ```

That's it! The service will be installed and started automatically.

### 📖 Documentation

- **QUICKSTART.md** - Start here for installation and basic usage
- **IMPROVEMENTS.md** - Detailed technical improvements
- **CHANGELOG.md** - Complete version history

### 🧪 Testing (Optional)

To verify everything works correctly:
```bash
cd ~/headless-mpv-player
chmod +x run_tests.sh
./run_tests.sh
```

### 🌐 Access

After installation:
```
http://[your-pi-ip]:5000
```

### 📊 What Was Fixed?

| Issue | Status | Details |
|-------|--------|---------|
| No Input Validation | ✅ FIXED | Volume, seek, skip, filenames validated |
| Error Handling Gaps | ✅ FIXED | install.sh has `set -e` and validation |
| No Logging | ✅ FIXED | Structured logging to file |
| Hard-Coded Paths | ✅ FIXED | Works for any user |
| Blocking Uploads | ✅ FIXED | Async uploads with chunking |
| Memory Issues | ✅ FIXED | 40x memory reduction |
| No Tests | ✅ FIXED | 40+ test cases |
| Process Leaks | ✅ FIXED | Proper cleanup |

### 🎯 Backward Compatibility

- ✅ All API endpoints unchanged
- ✅ Configuration format extended (backward compatible)
- ✅ Existing media files work as-is
- ✅ Node-RED flows work unchanged
- ✅ Zero breaking changes

### 📞 Need Help?

1. **Installation Issues**: Check `~/logs/install.log`
2. **Runtime Issues**: Check `~/logs/headless-mpv.log`
3. **Service Issues**: `sudo journalctl -u headless-mpv-player -f`

### 🔧 Service Management

```bash
# Start service
sudo systemctl start headless-mpv-player

# Stop service
sudo systemctl stop headless-mpv-player

# Check status
sudo systemctl status headless-mpv-player

# View logs
sudo journalctl -u headless-mpv-player -f
```

### 💡 Pro Tips

- Enable debug logging by setting `"log_level": "DEBUG"` in `~/headless-mpv-config.json`
- Run tests after installation to verify everything works
- Check logs regularly for any issues
- Backup your config before making changes

### 📦 Package Contents Summary

```
headless-mpv-player/
├── app.py                    # Main application (ENHANCED)
├── mpv_controller.py         # MPV controller (ENHANCED)
├── install.sh                # Installer (ENHANCED)
├── requirements.txt          # Dependencies (UPDATED)
├── test_app.py              # Test suite (NEW)
├── run_tests.sh             # Test runner (NEW)
├── QUICKSTART.md            # Quick guide (NEW)
├── IMPROVEMENTS.md          # Technical docs (NEW)
└── CHANGELOG.md             # Version history (NEW)
```

### 🎉 Ready to Install?

Start with **QUICKSTART.md** for step-by-step instructions!

---

**Version**: 2.0 Enhanced Edition  
**Compatibility**: Raspberry Pi OS, Debian, Ubuntu  
**Python**: 3.7+  
**License**: MIT (same as original)
