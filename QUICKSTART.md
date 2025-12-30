# Quick Start Guide - Enhanced Headless Pi MPV Player

**GitHub Repository:** [https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition](https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition)

## 📦 What's Included

This package contains the following enhanced files:

1. **app.py** - Main Flask application with all improvements
2. **mpv_controller.py** - Enhanced MPV controller
3. **install.sh** - Robust installation script
4. **requirements.txt** - Python dependencies with pinned versions
5. **test_app.py** - Comprehensive test suite
6. **run_tests.sh** - Test runner script
7. **IMPROVEMENTS.md** - Detailed documentation of all improvements

## 🚀 Quick Installation

### One-Command Installation (Recommended)

Simply run this command on your Raspberry Pi:

```bash
curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/install.sh | bash
```

This will:
- Download all necessary files from GitHub
- Install dependencies
- Set up the service
- Start the player automatically

### Alternative: Manual Installation

If you prefer to review files before installation:

#### Step 1: Backup Current Installation (if applicable)
```bash
cd ~
if [ -d "headless-mpv-player" ]; then
    mv headless-mpv-player headless-mpv-player.backup
    mv headless-mpv-config.json headless-mpv-config.json.backup 2>/dev/null || true
fi
```

#### Step 2: Download Files from GitHub
```bash
cd ~
git clone https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition.git headless-mpv-player
cd headless-mpv-player
```

#### Step 3: Run Installation
```bash
cd ~/headless-mpv-player
chmod +x install.sh
./install.sh
```

The installer will:
- ✅ Check system requirements
- ✅ Install dependencies
- ✅ Set up Python virtual environment
- ✅ Create configuration file
- ✅ Set up systemd service
- ✅ Start the service

#### Step 4: Verify Installation
```bash
# Check service status
sudo systemctl status headless-mpv-player

# Test health endpoint
curl http://localhost:5000/api/health

# Check logs
tail ~/logs/headless-mpv.log
```

## 🧪 Running Tests (Optional)

```bash
cd ~/headless-mpv-player
./run_tests.sh
```

## 📁 File Locations

After installation:
- **Application**: `~/headless-mpv-player/`
- **Media Files**: `~/videos/`
- **Configuration**: `~/headless-mpv-config.json`
- **Logs**: `~/logs/headless-mpv.log`
- **Install Log**: `~/logs/install.log`

## 🌐 Accessing the Web Interface

After installation, access the player at:
```
http://[your-pi-ip]:5000
```

To find your Pi's IP address:
```bash
hostname -I
```

## 🔧 Service Management

```bash
# Start service
sudo systemctl start headless-mpv-player

# Stop service
sudo systemctl stop headless-mpv-player

# Restart service
sudo systemctl restart headless-mpv-player

# Check status
sudo systemctl status headless-mpv-player

# View live logs
sudo journalctl -u headless-mpv-player -f

# Enable auto-start on boot
sudo systemctl enable headless-mpv-player

# Disable auto-start
sudo systemctl disable headless-mpv-player
```

## 📊 What's Improved?

### ✅ **Input Validation**
- All inputs (volume, seek, skip, filenames) are validated
- Prevents crashes from invalid values
- Clear error messages

### ✅ **Error Handling**
- Comprehensive error handling throughout
- Installation script with rollback capability
- No silent failures

### ✅ **Structured Logging**
- Multi-level logging (DEBUG, INFO, WARNING, ERROR)
- Logs saved to `~/logs/headless-mpv.log`
- Easy debugging

### ✅ **Performance**
- Async file uploads (non-blocking)
- Proper process management
- Memory-efficient operations

### ✅ **Fixed Paths**
- Works for any user (not just 'pi')
- No hard-coded paths
- Dynamic path resolution

### ✅ **Test Suite**
- 40+ test cases
- Coverage reporting
- Easy to verify everything works

## 🐛 Troubleshooting

### Installation Fails
Check the installation log:
```bash
less ~/logs/install.log
```

### Service Won't Start
Check detailed logs:
```bash
sudo journalctl -u headless-mpv-player -n 50
tail -n 100 ~/logs/headless-mpv.log
```

### Can't Access Web Interface
1. Check service is running: `sudo systemctl status headless-mpv-player`
2. Check firewall: `sudo ufw status` (allow port 5000 if needed)
3. Verify IP address: `hostname -I`

### Tests Fail
Ensure dependencies installed:
```bash
cd ~/headless-mpv-player
source venv/bin/activate
pip install -r requirements.txt
```

## 📖 API Endpoints (Quick Reference)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/play` | Play video or resume |
| POST | `/api/pause` | Toggle pause |
| POST | `/api/stop` | Stop playback |
| POST | `/api/skip` | Skip forward/backward |
| POST | `/api/seek` | Seek to position |
| POST | `/api/volume` | Set volume |
| GET | `/api/status` | Get player status |
| GET | `/api/files` | List media files |
| POST | `/api/upload` | Upload video |
| DELETE | `/api/files/{name}` | Delete video |
| GET | `/api/health` | Health check |

## 🎯 Next Steps

1. **Upload some videos** to `~/videos/` directory
2. **Access the web interface** at `http://your-pi-ip:5000`
3. **Run tests** to verify everything works: `./run_tests.sh`
4. **Check logs** to see what's happening: `tail -f ~/logs/headless-mpv.log`

## 💡 Tips

- **Enable debug logging**: Edit `~/headless-mpv-config.json` and set `"log_level": "DEBUG"`
- **Change port**: Edit config and set `"port": 8080` (or any other port)
- **Increase upload limit**: Edit config and change `"max_upload_size"` value
- **View test coverage**: Run `./run_tests.sh` and open `htmlcov/index.html`

## 📞 Support

For issues or questions:
1. Check `~/logs/headless-mpv.log` for application logs
2. Check `~/logs/install.log` for installation issues
3. Run tests to verify functionality: `./run_tests.sh`
4. Review the detailed IMPROVEMENTS.md file

## ✨ Key Features

- ✅ **Headless Operation** - Works without display
- ✅ **Web Interface** - Control from any device
- ✅ **Node-RED Integration** - Full HTTP API
- ✅ **Hardware Acceleration** - Optimized for Pi
- ✅ **Input Validation** - Prevents crashes
- ✅ **Error Handling** - Graceful degradation
- ✅ **Async Uploads** - Non-blocking file uploads
- ✅ **Structured Logging** - Easy debugging
- ✅ **Test Suite** - Verify functionality
- ✅ **Fixed Paths** - Works for any user

Enjoy your enhanced MPV player! 🎉
