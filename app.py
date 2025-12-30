#!/usr/bin/env python3
"""
Headless Pi MPV Player - Main Flask Application
Enhanced with input validation, async operations, and structured logging

GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
Author: keep-on-walking
License: MIT
"""

import os
import sys
import json
import logging
import asyncio
from pathlib import Path
from datetime import datetime
from functools import wraps
from typing import Optional, Dict, Any, Tuple

from flask import Flask, render_template, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
from werkzeug.exceptions import RequestEntityTooLarge
import aiofiles

from mpv_controller import MPVController

# ============================================================================
# CONFIGURATION
# ============================================================================

# Get user's home directory dynamically instead of hard-coding /home/pi
USER_HOME = Path.home()
DEFAULT_CONFIG_PATH = USER_HOME / "headless-mpv-config.json"
DEFAULT_MEDIA_DIR = USER_HOME / "videos"

# Allowed file extensions
ALLOWED_EXTENSIONS = {
    '.mp4', '.avi', '.mkv', '.mov', '.wmv', 
    '.flv', '.webm', '.m4v', '.mpg', '.mpeg', 
    '.3gp', '.ogv'
}

# Input validation bounds
VOLUME_MIN = 0
VOLUME_MAX = 150  # MPV can go above 100
SEEK_MIN = 0
SEEK_MAX = 86400  # 24 hours max
SKIP_MIN = -3600  # 1 hour backwards
SKIP_MAX = 3600   # 1 hour forwards

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

def setup_logging(log_level: str = "INFO") -> logging.Logger:
    """Configure structured logging with rotation"""
    
    log_dir = USER_HOME / "logs"
    log_dir.mkdir(exist_ok=True)
    
    # Create logger
    logger = logging.getLogger("headless-mpv")
    logger.setLevel(getattr(logging, log_level.upper()))
    
    # Prevent duplicate handlers
    if logger.handlers:
        return logger
    
    # Console handler with formatting
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    console_handler.setFormatter(console_formatter)
    
    # File handler with rotation (manual rotation to avoid external deps)
    log_file = log_dir / "headless-mpv.log"
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.DEBUG)
    file_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    file_handler.setFormatter(file_formatter)
    
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    
    return logger

logger = setup_logging()

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

class Config:
    """Configuration manager with validation"""
    
    DEFAULT_CONFIG = {
        "media_dir": str(DEFAULT_MEDIA_DIR),
        "max_upload_size": 2147483648,  # 2GB
        "volume": 100,
        "loop": False,
        "hardware_accel": True,
        "hdmi_output": "auto",
        "audio_in_headless": True,
        "port": 5000,
        "log_level": "INFO"
    }
    
    def __init__(self, config_path: Path = DEFAULT_CONFIG_PATH):
        self.config_path = config_path
        self.config = self.load_config()
        
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file or create default"""
        try:
            if self.config_path.exists():
                with open(self.config_path, 'r') as f:
                    user_config = json.load(f)
                    # Merge with defaults
                    config = self.DEFAULT_CONFIG.copy()
                    config.update(user_config)
                    logger.info(f"Configuration loaded from {self.config_path}")
                    return config
            else:
                logger.info("No config file found, creating default")
                self.save_config(self.DEFAULT_CONFIG)
                return self.DEFAULT_CONFIG.copy()
        except Exception as e:
            logger.error(f"Error loading config: {e}, using defaults")
            return self.DEFAULT_CONFIG.copy()
    
    def save_config(self, config: Dict[str, Any]) -> bool:
        """Save configuration to file"""
        try:
            with open(self.config_path, 'w') as f:
                json.dump(config, f, indent=2)
            logger.info(f"Configuration saved to {self.config_path}")
            return True
        except Exception as e:
            logger.error(f"Error saving config: {e}")
            return False
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value"""
        return self.config.get(key, default)
    
    def set(self, key: str, value: Any) -> bool:
        """Set configuration value and save"""
        self.config[key] = value
        return self.save_config(self.config)

# ============================================================================
# INPUT VALIDATION
# ============================================================================

class ValidationError(Exception):
    """Custom validation error"""
    pass

def validate_volume(volume: Any) -> int:
    """Validate volume level"""
    try:
        vol = int(volume)
        if not VOLUME_MIN <= vol <= VOLUME_MAX:
            raise ValidationError(
                f"Volume must be between {VOLUME_MIN} and {VOLUME_MAX}, got {vol}"
            )
        return vol
    except (TypeError, ValueError) as e:
        raise ValidationError(f"Invalid volume value: {volume}") from e

def validate_seek_position(position: Any) -> float:
    """Validate seek position"""
    try:
        pos = float(position)
        if not SEEK_MIN <= pos <= SEEK_MAX:
            raise ValidationError(
                f"Seek position must be between {SEEK_MIN} and {SEEK_MAX}, got {pos}"
            )
        return pos
    except (TypeError, ValueError) as e:
        raise ValidationError(f"Invalid seek position: {position}") from e

def validate_skip_duration(seconds: Any) -> float:
    """Validate skip duration"""
    try:
        skip = float(seconds)
        if not SKIP_MIN <= skip <= SKIP_MAX:
            raise ValidationError(
                f"Skip duration must be between {SKIP_MIN} and {SKIP_MAX}, got {skip}"
            )
        return skip
    except (TypeError, ValueError) as e:
        raise ValidationError(f"Invalid skip duration: {seconds}") from e

def validate_filename(filename: str, media_dir: Path) -> Path:
    """Validate filename is safe and within media directory"""
    if not filename:
        raise ValidationError("Filename cannot be empty")
    
    # Secure the filename
    safe_name = secure_filename(filename)
    if not safe_name:
        raise ValidationError(f"Invalid filename: {filename}")
    
    # Check extension
    ext = Path(safe_name).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise ValidationError(
            f"File type {ext} not allowed. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Construct full path and verify it's within media directory
    full_path = (media_dir / safe_name).resolve()
    
    try:
        full_path.relative_to(media_dir.resolve())
    except ValueError:
        raise ValidationError("Path traversal attempt detected")
    
    return full_path

def validate_hdmi_output(output: str) -> str:
    """Validate HDMI output selection"""
    valid_outputs = ["auto", "HDMI-A-1", "HDMI-A-2"]
    if output not in valid_outputs:
        raise ValidationError(
            f"Invalid HDMI output: {output}. Must be one of {valid_outputs}"
        )
    return output

# ============================================================================
# FLASK APPLICATION
# ============================================================================

# Initialize configuration
config = Config()

# Create Flask app
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = config.get('max_upload_size')
app.config['UPLOAD_FOLDER'] = config.get('media_dir')

# Ensure media directory exists
media_dir = Path(config.get('media_dir'))
media_dir.mkdir(parents=True, exist_ok=True)
logger.info(f"Media directory: {media_dir}")

# Initialize MPV controller
mpv = MPVController(
    media_dir=media_dir,
    hardware_accel=config.get('hardware_accel'),
    hdmi_output=config.get('hdmi_output'),
    audio_in_headless=config.get('audio_in_headless'),
    logger=logger
)

# ============================================================================
# DECORATORS
# ============================================================================

def handle_errors(f):
    """Decorator to handle errors consistently"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except ValidationError as e:
            logger.warning(f"Validation error: {e}")
            return jsonify({"success": False, "error": str(e)}), 400
        except Exception as e:
            logger.error(f"Unexpected error in {f.__name__}: {e}", exc_info=True)
            return jsonify({"success": False, "error": "Internal server error"}), 500
    return decorated_function

# ============================================================================
# ROUTES - WEB INTERFACE
# ============================================================================

@app.route('/')
def index():
    """Serve main web interface"""
    return render_template('index.html')

@app.route('/static/<path:filename>')
def serve_static(filename):
    """Serve static files"""
    return send_from_directory('static', filename)

# ============================================================================
# ROUTES - PLAYBACK CONTROL
# ============================================================================

@app.route('/api/play', methods=['POST'])
@handle_errors
def play():
    """Play video file or resume playback"""
    data = request.get_json() or {}
    filename = data.get('file')
    
    if filename:
        # Validate and play specific file
        file_path = validate_filename(filename, media_dir)
        
        if not file_path.exists():
            return jsonify({
                "success": False, 
                "error": f"File not found: {filename}"
            }), 404
        
        success = mpv.play(str(file_path))
        logger.info(f"Play request: {filename} - {'success' if success else 'failed'}")
    else:
        # Resume playback
        success = mpv.resume()
        logger.info(f"Resume request - {'success' if success else 'failed'}")
    
    return jsonify({"success": success})

@app.route('/api/pause', methods=['POST'])
@handle_errors
def pause():
    """Toggle pause/resume"""
    success = mpv.pause()
    logger.info(f"Pause toggle - {'success' if success else 'failed'}")
    return jsonify({"success": success})

@app.route('/api/stop', methods=['POST'])
@handle_errors
def stop():
    """Stop playback"""
    success = mpv.stop()
    logger.info("Stop request")
    return jsonify({"success": success})

@app.route('/api/skip', methods=['POST'])
@handle_errors
def skip():
    """Skip forward or backward"""
    data = request.get_json()
    if not data or 'seconds' not in data:
        raise ValidationError("Missing 'seconds' parameter")
    
    seconds = validate_skip_duration(data['seconds'])
    success = mpv.skip(seconds)
    logger.info(f"Skip request: {seconds}s - {'success' if success else 'failed'}")
    
    return jsonify({"success": success})

@app.route('/api/seek', methods=['POST'])
@handle_errors
def seek():
    """Seek to specific position"""
    data = request.get_json()
    if not data or 'position' not in data:
        raise ValidationError("Missing 'position' parameter")
    
    position = validate_seek_position(data['position'])
    success = mpv.seek(position)
    logger.info(f"Seek request: {position}s - {'success' if success else 'failed'}")
    
    return jsonify({"success": success})

@app.route('/api/volume', methods=['POST'])
@handle_errors
def volume():
    """Set volume level"""
    data = request.get_json()
    if not data or 'level' not in data:
        raise ValidationError("Missing 'level' parameter")
    
    level = validate_volume(data['level'])
    success = mpv.set_volume(level)
    
    if success:
        config.set('volume', level)
    
    logger.info(f"Volume request: {level} - {'success' if success else 'failed'}")
    return jsonify({"success": success})

@app.route('/api/hdmi', methods=['POST'])
@handle_errors
def hdmi():
    """Set HDMI output"""
    data = request.get_json()
    if not data or 'output' not in data:
        raise ValidationError("Missing 'output' parameter")
    
    output = validate_hdmi_output(data['output'])
    success = mpv.set_hdmi_output(output)
    
    if success:
        config.set('hdmi_output', output)
    
    logger.info(f"HDMI output request: {output} - {'success' if success else 'failed'}")
    return jsonify({"success": success})

# ============================================================================
# ROUTES - STATUS & INFO
# ============================================================================

@app.route('/api/status', methods=['GET'])
@handle_errors
def status():
    """Get player status"""
    player_status = mpv.get_status()
    return jsonify(player_status)

@app.route('/api/health', methods=['GET'])
@handle_errors
def health():
    """Health check endpoint"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "mpv_running": mpv.is_running(),
        "media_dir": str(media_dir),
        "disk_space": get_disk_space(media_dir)
    }
    return jsonify(health_status)

def get_disk_space(path: Path) -> Dict[str, int]:
    """Get disk space information"""
    try:
        stat = os.statvfs(path)
        free = stat.f_bavail * stat.f_frsize
        total = stat.f_blocks * stat.f_frsize
        used = total - free
        return {
            "total": total,
            "used": used,
            "free": free,
            "percent_used": round((used / total) * 100, 2) if total > 0 else 0
        }
    except Exception as e:
        logger.error(f"Error getting disk space: {e}")
        return {"error": str(e)}

# ============================================================================
# ROUTES - FILE MANAGEMENT
# ============================================================================

@app.route('/api/files', methods=['GET'])
@handle_errors
def list_files():
    """List media files"""
    try:
        files = []
        for file_path in media_dir.glob('*'):
            if file_path.is_file() and file_path.suffix.lower() in ALLOWED_EXTENSIONS:
                stat = file_path.stat()
                files.append({
                    "name": file_path.name,
                    "size": stat.st_size,
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat()
                })
        
        # Sort by name
        files.sort(key=lambda x: x['name'])
        
        logger.debug(f"File list request: {len(files)} files")
        return jsonify({"success": True, "files": files})
    
    except Exception as e:
        logger.error(f"Error listing files: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/upload', methods=['POST'])
@handle_errors
async def upload_file():
    """Upload video file asynchronously"""
    if 'file' not in request.files:
        raise ValidationError("No file provided")
    
    file = request.files['file']
    
    if file.filename == '':
        raise ValidationError("No file selected")
    
    # Validate filename
    file_path = validate_filename(file.filename, media_dir)
    
    try:
        # Save file asynchronously in chunks to avoid memory issues
        chunk_size = 8192  # 8KB chunks
        
        async with aiofiles.open(file_path, 'wb') as f:
            while True:
                chunk = file.stream.read(chunk_size)
                if not chunk:
                    break
                await f.write(chunk)
        
        logger.info(f"File uploaded successfully: {file.filename}")
        return jsonify({
            "success": True,
            "filename": file_path.name,
            "size": file_path.stat().st_size
        })
    
    except Exception as e:
        # Clean up partial file on error
        if file_path.exists():
            file_path.unlink()
        logger.error(f"Upload failed for {file.filename}: {e}")
        raise

@app.route('/api/files/<filename>', methods=['DELETE'])
@handle_errors
def delete_file(filename):
    """Delete video file"""
    file_path = validate_filename(filename, media_dir)
    
    if not file_path.exists():
        return jsonify({
            "success": False, 
            "error": f"File not found: {filename}"
        }), 404
    
    # Check if file is currently playing
    current_status = mpv.get_status()
    if current_status.get('current_file') == filename:
        mpv.stop()
    
    try:
        file_path.unlink()
        logger.info(f"File deleted: {filename}")
        return jsonify({"success": True})
    except Exception as e:
        logger.error(f"Error deleting file {filename}: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

# ============================================================================
# ROUTES - CONFIGURATION
# ============================================================================

@app.route('/api/config', methods=['GET'])
@handle_errors
def get_config():
    """Get configuration"""
    return jsonify(config.config)

@app.route('/api/config', methods=['POST'])
@handle_errors
def update_config():
    """Update configuration"""
    data = request.get_json()
    
    if not data:
        raise ValidationError("No configuration data provided")
    
    # Validate specific fields if they're being updated
    if 'volume' in data:
        data['volume'] = validate_volume(data['volume'])
    
    if 'hdmi_output' in data:
        data['hdmi_output'] = validate_hdmi_output(data['hdmi_output'])
    
    # Update config
    for key, value in data.items():
        if key in config.config:
            config.set(key, value)
    
    logger.info(f"Configuration updated: {list(data.keys())}")
    return jsonify({"success": True, "config": config.config})

# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(RequestEntityTooLarge)
def handle_file_too_large(e):
    """Handle file upload too large"""
    max_size_mb = config.get('max_upload_size') / (1024 * 1024)
    logger.warning(f"Upload rejected: file too large (max {max_size_mb}MB)")
    return jsonify({
        "success": False,
        "error": f"File too large. Maximum size is {max_size_mb}MB"
    }), 413

@app.errorhandler(404)
def not_found(e):
    """Handle 404 errors"""
    return jsonify({"success": False, "error": "Not found"}), 404

@app.errorhandler(500)
def internal_error(e):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {e}", exc_info=True)
    return jsonify({"success": False, "error": "Internal server error"}), 500

# ============================================================================
# MAIN
# ============================================================================

def main():
    """Main entry point"""
    port = config.get('port', 5000)
    
    logger.info("=" * 60)
    logger.info("Headless Pi MPV Player Starting")
    logger.info("=" * 60)
    logger.info(f"Media directory: {media_dir}")
    logger.info(f"Config file: {config.config_path}")
    logger.info(f"Web interface: http://0.0.0.0:{port}")
    logger.info(f"Log file: {USER_HOME}/logs/headless-mpv.log")
    logger.info("=" * 60)
    
    # Run Flask app
    app.run(
        host='0.0.0.0',
        port=port,
        debug=False,
        threaded=True
    )

if __name__ == '__main__':
    main()
