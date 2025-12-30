#!/usr/bin/env python3
"""
Test Suite for Headless Pi MPV Player
Comprehensive tests for input validation, API endpoints, and MPV controller

GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
Author: keep-on-walking
License: MIT
"""

import pytest
import json
import tempfile
import os
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Import modules to test
import sys
sys.path.insert(0, str(Path(__file__).parent))

from app import (
    app, 
    validate_volume, 
    validate_seek_position, 
    validate_skip_duration,
    validate_filename,
    validate_hdmi_output,
    ValidationError,
    Config
)
from mpv_controller import MPVController, PlayerState

# ==============================================================================
# FIXTURES
# ==============================================================================

@pytest.fixture
def client():
    """Flask test client"""
    app.config['TESTING'] = True
    app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB for tests
    with app.test_client() as client:
        yield client

@pytest.fixture
def temp_media_dir():
    """Temporary media directory"""
    with tempfile.TemporaryDirectory() as tmpdir:
        media_path = Path(tmpdir)
        # Create some test files
        (media_path / "test_video.mp4").write_text("fake video content")
        (media_path / "test_video2.avi").write_text("fake video content 2")
        yield media_path

@pytest.fixture
def temp_config():
    """Temporary configuration file"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        config = {
            "media_dir": "/tmp/test_videos",
            "volume": 100,
            "port": 5000
        }
        json.dump(config, f)
        config_path = Path(f.name)
    
    yield config_path
    
    # Cleanup
    if config_path.exists():
        config_path.unlink()

@pytest.fixture
def mock_mpv_controller():
    """Mocked MPV controller"""
    with patch('app.mpv') as mock:
        mock.is_running.return_value = True
        mock.get_status.return_value = {
            "state": "playing",
            "current_file": "test.mp4",
            "position": 30.0,
            "duration": 120.0,
            "volume": 100
        }
        yield mock

# ==============================================================================
# INPUT VALIDATION TESTS
# ==============================================================================

class TestVolumeValidation:
    """Test volume validation"""
    
    def test_valid_volume(self):
        """Test valid volume values"""
        assert validate_volume(0) == 0
        assert validate_volume(50) == 50
        assert validate_volume(100) == 100
        assert validate_volume(150) == 150
    
    def test_volume_as_string(self):
        """Test volume as string input"""
        assert validate_volume("75") == 75
    
    def test_volume_below_minimum(self):
        """Test volume below minimum"""
        with pytest.raises(ValidationError, match="must be between"):
            validate_volume(-1)
    
    def test_volume_above_maximum(self):
        """Test volume above maximum"""
        with pytest.raises(ValidationError, match="must be between"):
            validate_volume(151)
    
    def test_volume_invalid_type(self):
        """Test invalid volume type"""
        with pytest.raises(ValidationError):
            validate_volume("invalid")
        
        with pytest.raises(ValidationError):
            validate_volume(None)

class TestSeekValidation:
    """Test seek position validation"""
    
    def test_valid_seek(self):
        """Test valid seek positions"""
        assert validate_seek_position(0) == 0.0
        assert validate_seek_position(30.5) == 30.5
        assert validate_seek_position(3600) == 3600.0
    
    def test_seek_as_string(self):
        """Test seek as string input"""
        assert validate_seek_position("45.5") == 45.5
    
    def test_seek_negative(self):
        """Test negative seek position"""
        with pytest.raises(ValidationError):
            validate_seek_position(-1)
    
    def test_seek_too_large(self):
        """Test seek position too large"""
        with pytest.raises(ValidationError):
            validate_seek_position(90000)  # > 24 hours
    
    def test_seek_invalid_type(self):
        """Test invalid seek type"""
        with pytest.raises(ValidationError):
            validate_seek_position("invalid")

class TestSkipValidation:
    """Test skip duration validation"""
    
    def test_valid_skip_forward(self):
        """Test valid forward skip"""
        assert validate_skip_duration(10) == 10.0
        assert validate_skip_duration(30) == 30.0
    
    def test_valid_skip_backward(self):
        """Test valid backward skip"""
        assert validate_skip_duration(-10) == -10.0
        assert validate_skip_duration(-30) == -30.0
    
    def test_skip_too_large(self):
        """Test skip duration too large"""
        with pytest.raises(ValidationError):
            validate_skip_duration(4000)  # > 1 hour
    
    def test_skip_too_negative(self):
        """Test skip duration too negative"""
        with pytest.raises(ValidationError):
            validate_skip_duration(-4000)

class TestFilenameValidation:
    """Test filename validation"""
    
    def test_valid_filename(self, temp_media_dir):
        """Test valid filenames"""
        result = validate_filename("video.mp4", temp_media_dir)
        assert result.name == "video.mp4"
    
    def test_filename_with_spaces(self, temp_media_dir):
        """Test filename with spaces"""
        result = validate_filename("my video.mp4", temp_media_dir)
        assert result.name == "my_video.mp4"
    
    def test_filename_path_traversal(self, temp_media_dir):
        """Test path traversal attempt"""
        with pytest.raises(ValidationError, match="Path traversal"):
            validate_filename("../../../etc/passwd", temp_media_dir)
    
    def test_filename_invalid_extension(self, temp_media_dir):
        """Test invalid file extension"""
        with pytest.raises(ValidationError, match="not allowed"):
            validate_filename("malicious.exe", temp_media_dir)
    
    def test_filename_empty(self, temp_media_dir):
        """Test empty filename"""
        with pytest.raises(ValidationError, match="cannot be empty"):
            validate_filename("", temp_media_dir)

class TestHDMIValidation:
    """Test HDMI output validation"""
    
    def test_valid_hdmi_outputs(self):
        """Test valid HDMI outputs"""
        assert validate_hdmi_output("auto") == "auto"
        assert validate_hdmi_output("HDMI-A-1") == "HDMI-A-1"
        assert validate_hdmi_output("HDMI-A-2") == "HDMI-A-2"
    
    def test_invalid_hdmi_output(self):
        """Test invalid HDMI output"""
        with pytest.raises(ValidationError, match="Invalid HDMI output"):
            validate_hdmi_output("HDMI-3")

# ==============================================================================
# CONFIGURATION TESTS
# ==============================================================================

class TestConfiguration:
    """Test configuration management"""
    
    def test_load_default_config(self):
        """Test loading default configuration"""
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = Path(tmpdir) / "config.json"
            config = Config(config_path)
            
            assert config.get('volume') == 100
            assert config.get('port') == 5000
            assert config_path.exists()
    
    def test_load_existing_config(self, temp_config):
        """Test loading existing configuration"""
        config = Config(temp_config)
        assert config.get('media_dir') == "/tmp/test_videos"
        assert config.get('volume') == 100
    
    def test_save_config(self, temp_config):
        """Test saving configuration"""
        config = Config(temp_config)
        success = config.set('volume', 75)
        
        assert success
        assert config.get('volume') == 75
        
        # Reload to verify persistence
        config2 = Config(temp_config)
        assert config2.get('volume') == 75

# ==============================================================================
# API ENDPOINT TESTS
# ==============================================================================

class TestPlaybackEndpoints:
    """Test playback control endpoints"""
    
    def test_play_endpoint_with_file(self, client, mock_mpv_controller, temp_media_dir):
        """Test play endpoint with file"""
        mock_mpv_controller.play.return_value = True
        
        response = client.post('/api/play', 
            json={"file": "test_video.mp4"},
            content_type='application/json'
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
    
    def test_play_endpoint_resume(self, client, mock_mpv_controller):
        """Test play endpoint without file (resume)"""
        mock_mpv_controller.resume.return_value = True
        
        response = client.post('/api/play',
            json={},
            content_type='application/json'
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
    
    def test_pause_endpoint(self, client, mock_mpv_controller):
        """Test pause endpoint"""
        mock_mpv_controller.pause.return_value = True
        
        response = client.post('/api/pause')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
    
    def test_stop_endpoint(self, client, mock_mpv_controller):
        """Test stop endpoint"""
        mock_mpv_controller.stop.return_value = True
        
        response = client.post('/api/stop')
        assert response.status_code == 200
    
    def test_skip_endpoint_valid(self, client, mock_mpv_controller):
        """Test skip endpoint with valid duration"""
        mock_mpv_controller.skip.return_value = True
        
        response = client.post('/api/skip',
            json={"seconds": 30},
            content_type='application/json'
        )
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['success'] is True
    
    def test_skip_endpoint_invalid(self, client):
        """Test skip endpoint with invalid duration"""
        response = client.post('/api/skip',
            json={"seconds": 5000},  # Too large
            content_type='application/json'
        )
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'error' in data
    
    def test_seek_endpoint_valid(self, client, mock_mpv_controller):
        """Test seek endpoint with valid position"""
        mock_mpv_controller.seek.return_value = True
        
        response = client.post('/api/seek',
            json={"position": 60},
            content_type='application/json'
        )
        
        assert response.status_code == 200
    
    def test_seek_endpoint_invalid(self, client):
        """Test seek endpoint with invalid position"""
        response = client.post('/api/seek',
            json={"position": -10},  # Negative
            content_type='application/json'
        )
        
        assert response.status_code == 400
    
    def test_volume_endpoint_valid(self, client, mock_mpv_controller):
        """Test volume endpoint with valid level"""
        mock_mpv_controller.set_volume.return_value = True
        
        response = client.post('/api/volume',
            json={"level": 75},
            content_type='application/json'
        )
        
        assert response.status_code == 200
    
    def test_volume_endpoint_invalid(self, client):
        """Test volume endpoint with invalid level"""
        response = client.post('/api/volume',
            json={"level": 200},  # Too high
            content_type='application/json'
        )
        
        assert response.status_code == 400

class TestStatusEndpoints:
    """Test status and info endpoints"""
    
    def test_status_endpoint(self, client, mock_mpv_controller):
        """Test status endpoint"""
        response = client.get('/api/status')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'state' in data
        assert 'position' in data
    
    def test_health_endpoint(self, client, mock_mpv_controller):
        """Test health check endpoint"""
        response = client.get('/api/health')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'
        assert 'timestamp' in data
    
    def test_config_get_endpoint(self, client):
        """Test get configuration endpoint"""
        response = client.get('/api/config')
        
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'volume' in data
        assert 'port' in data

class TestFileManagementEndpoints:
    """Test file management endpoints"""
    
    def test_list_files_endpoint(self, client, temp_media_dir, mock_mpv_controller):
        """Test list files endpoint"""
        with patch('app.media_dir', temp_media_dir):
            response = client.get('/api/files')
            
            assert response.status_code == 200
            data = json.loads(response.data)
            assert data['success'] is True
            assert 'files' in data
    
    def test_delete_file_endpoint(self, client, temp_media_dir, mock_mpv_controller):
        """Test delete file endpoint"""
        # Create a test file
        test_file = temp_media_dir / "delete_me.mp4"
        test_file.write_text("test")
        
        with patch('app.media_dir', temp_media_dir):
            response = client.delete('/api/files/delete_me.mp4')
            
            assert response.status_code == 200
            assert not test_file.exists()

# ==============================================================================
# MPV CONTROLLER TESTS
# ==============================================================================

class TestMPVController:
    """Test MPV controller functionality"""
    
    def test_controller_initialization(self, temp_media_dir):
        """Test controller initialization"""
        controller = MPVController(
            media_dir=temp_media_dir,
            hardware_accel=True,
            hdmi_output="auto"
        )
        
        assert controller.state == PlayerState.STOPPED
        assert controller.media_dir == temp_media_dir
    
    def test_controller_cleanup_socket(self, temp_media_dir):
        """Test socket cleanup"""
        controller = MPVController(media_dir=temp_media_dir)
        
        # Create a fake socket file
        socket_path = Path("/tmp/mpv-socket-test")
        socket_path.touch()
        
        controller.socket_path = socket_path
        controller._cleanup_socket()
        
        assert not socket_path.exists()
    
    @patch('mpv_controller.subprocess.Popen')
    def test_controller_process_management(self, mock_popen, temp_media_dir):
        """Test process management"""
        mock_process = Mock()
        mock_process.poll.return_value = None
        mock_popen.return_value = mock_process
        
        controller = MPVController(media_dir=temp_media_dir)
        controller.process = mock_process
        
        assert controller.is_running()
        
        # Test cleanup
        controller._cleanup_process()
        mock_process.terminate.assert_called_once()

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

class TestIntegration:
    """Integration tests for full workflows"""
    
    def test_full_playback_workflow(self, client, mock_mpv_controller):
        """Test complete playback workflow"""
        # Play
        response = client.post('/api/play', json={"file": "test.mp4"})
        assert response.status_code == 200
        
        # Check status
        response = client.get('/api/status')
        assert response.status_code == 200
        
        # Skip forward
        response = client.post('/api/skip', json={"seconds": 30})
        assert response.status_code == 200
        
        # Pause
        response = client.post('/api/pause')
        assert response.status_code == 200
        
        # Stop
        response = client.post('/api/stop')
        assert response.status_code == 200
    
    def test_error_recovery(self, client):
        """Test error recovery"""
        # Send invalid requests
        response = client.post('/api/volume', json={"level": 999})
        assert response.status_code == 400
        
        # App should still be responsive
        response = client.get('/api/health')
        assert response.status_code == 200

# ==============================================================================
# RUN TESTS
# ==============================================================================

if __name__ == '__main__':
    pytest.main([__file__, '-v', '--cov=app', '--cov=mpv_controller', '--cov-report=html'])
