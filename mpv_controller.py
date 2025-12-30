#!/usr/bin/env python3
"""
MPV Controller Module
Enhanced with proper error handling, process management, and state tracking

GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
Author: keep-on-walking
License: MIT
"""

import os
import subprocess
import time
import socket
import json
import logging
from pathlib import Path
from typing import Optional, Dict, Any, List
from enum import Enum

class PlayerState(Enum):
    """Player state enumeration"""
    STOPPED = "stopped"
    PLAYING = "playing"
    PAUSED = "paused"
    ERROR = "error"

class MPVController:
    """
    Controller for MPV media player with IPC communication
    """
    
    def __init__(
        self,
        media_dir: Path,
        hardware_accel: bool = True,
        hdmi_output: str = "auto",
        audio_in_headless: bool = True,
        logger: Optional[logging.Logger] = None
    ):
        """
        Initialize MPV controller
        
        Args:
            media_dir: Directory containing media files
            hardware_accel: Enable hardware acceleration
            hdmi_output: HDMI output selection (auto/HDMI-A-1/HDMI-A-2)
            audio_in_headless: Output audio even without display
            logger: Logger instance
        """
        self.media_dir = Path(media_dir)
        self.hardware_accel = hardware_accel
        self.hdmi_output = hdmi_output
        self.audio_in_headless = audio_in_headless
        self.logger = logger or logging.getLogger(__name__)
        
        # IPC socket path
        self.socket_path = Path("/tmp/mpv-socket")
        
        # Process management
        self.process: Optional[subprocess.Popen] = None
        self.state = PlayerState.STOPPED
        self.current_file: Optional[str] = None
        self.current_position: float = 0.0
        self.duration: float = 0.0
        self.volume: int = 100
        
        # Ensure socket is cleaned up from previous runs
        self._cleanup_socket()
        
        self.logger.info("MPV Controller initialized")
    
    def _cleanup_socket(self):
        """Remove stale socket file"""
        try:
            if self.socket_path.exists():
                self.socket_path.unlink()
                self.logger.debug("Cleaned up stale socket")
        except Exception as e:
            self.logger.warning(f"Could not clean up socket: {e}")
    
    def _cleanup_process(self):
        """Clean up MPV process"""
        if self.process:
            try:
                # Try graceful termination first
                self.process.terminate()
                try:
                    self.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    # Force kill if it doesn't terminate
                    self.logger.warning("MPV didn't terminate gracefully, forcing kill")
                    self.process.kill()
                    self.process.wait(timeout=2)
                
                self.logger.debug("MPV process cleaned up")
            except Exception as e:
                self.logger.error(f"Error cleaning up MPV process: {e}")
            finally:
                self.process = None
        
        self._cleanup_socket()
    
    def _get_mpv_command(self, file_path: str) -> List[str]:
        """
        Build MPV command with appropriate options
        
        Args:
            file_path: Path to media file
            
        Returns:
            Command list for subprocess
        """
        cmd = [
            "mpv",
            "--no-terminal",
            "--really-quiet",
            f"--input-ipc-server={self.socket_path}",
            "--idle=yes",
            "--force-window=no",
            "--keep-open=yes",
            f"--volume={self.volume}",
        ]
        
        # Video output configuration
        cmd.extend([
            "--vo=gpu",
            "--gpu-context=drm",
            "--drm-connector={}".format(self.hdmi_output if self.hdmi_output != "auto" else ""),
        ])
        
        # Hardware acceleration
        if self.hardware_accel:
            cmd.extend([
                "--hwdec=auto",
                "--hwdec-codecs=all",
            ])
        
        # Audio configuration
        if self.audio_in_headless:
            # Auto-detect HDMI audio device
            audio_device = self._detect_hdmi_audio()
            if audio_device:
                cmd.append(f"--audio-device={audio_device}")
                self.logger.debug(f"Using audio device: {audio_device}")
        
        # Force 1080p output to prevent 4K performance issues
        cmd.extend([
            "--video-output-levels=limited",
            "--video-sync=display-resample",
        ])
        
        # Add file path
        cmd.append(file_path)
        
        return cmd
    
    def _detect_hdmi_audio(self) -> Optional[str]:
        """
        Detect HDMI audio device on Raspberry Pi
        
        Returns:
            Audio device string or None
        """
        try:
            # Try to find vc4-hdmi audio device
            result = subprocess.run(
                ["aplay", "-L"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            for line in result.stdout.split('\n'):
                if 'vc4hdmi' in line.lower() or 'hdmi' in line.lower():
                    # Extract device name
                    if line.startswith('    '):
                        continue
                    device = line.strip()
                    if device:
                        return f"alsa/{device}"
            
            # Fallback to default ALSA
            return "alsa/default"
        
        except Exception as e:
            self.logger.warning(f"Could not detect HDMI audio: {e}")
            return None
    
    def _send_command(self, command: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Send command to MPV via IPC socket
        
        Args:
            command: Command dictionary
            
        Returns:
            Response dictionary or None on error
        """
        if not self.socket_path.exists():
            self.logger.warning("MPV socket not available")
            return None
        
        try:
            # Connect to socket
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(2.0)
            sock.connect(str(self.socket_path))
            
            # Send command
            command_str = json.dumps(command) + '\n'
            sock.sendall(command_str.encode('utf-8'))
            
            # Receive response
            response_data = b''
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response_data += chunk
                if b'\n' in chunk:
                    break
            
            sock.close()
            
            # Parse response
            if response_data:
                response = json.loads(response_data.decode('utf-8'))
                return response
            
            return None
        
        except socket.timeout:
            self.logger.debug(f"Socket timeout for command: {command.get('command')}")
            return None
        except Exception as e:
            self.logger.error(f"Error sending command {command.get('command')}: {e}")
            return None
    
    def _get_property(self, property_name: str) -> Any:
        """
        Get property from MPV
        
        Args:
            property_name: Property name
            
        Returns:
            Property value or None
        """
        response = self._send_command({
            "command": ["get_property", property_name]
        })
        
        if response and response.get("error") == "success":
            return response.get("data")
        
        return None
    
    def _set_property(self, property_name: str, value: Any) -> bool:
        """
        Set property in MPV
        
        Args:
            property_name: Property name
            value: Property value
            
        Returns:
            True if successful
        """
        response = self._send_command({
            "command": ["set_property", property_name, value]
        })
        
        return response and response.get("error") == "success"
    
    def play(self, file_path: str) -> bool:
        """
        Play media file
        
        Args:
            file_path: Path to media file
            
        Returns:
            True if playback started successfully
        """
        try:
            # Validate file exists
            path = Path(file_path)
            if not path.exists():
                self.logger.error(f"File not found: {file_path}")
                return False
            
            # Stop any existing playback
            if self.is_running():
                self.stop()
            
            # Build command
            cmd = self._get_mpv_command(file_path)
            
            # Start MPV process
            self.logger.info(f"Starting playback: {path.name}")
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.DEVNULL
            )
            
            # Wait for socket to be ready
            max_attempts = 20
            for attempt in range(max_attempts):
                if self.socket_path.exists():
                    break
                time.sleep(0.1)
            else:
                self.logger.error("MPV socket not created")
                self._cleanup_process()
                return False
            
            # Update state
            self.state = PlayerState.PLAYING
            self.current_file = path.name
            
            # Wait a bit for playback to initialize
            time.sleep(0.5)
            
            # Get duration
            self.duration = self._get_property("duration") or 0.0
            
            self.logger.info(f"Playback started successfully: {path.name}")
            return True
        
        except Exception as e:
            self.logger.error(f"Error starting playback: {e}", exc_info=True)
            self._cleanup_process()
            self.state = PlayerState.ERROR
            return False
    
    def pause(self) -> bool:
        """
        Toggle pause/resume
        
        Returns:
            True if successful
        """
        if not self.is_running():
            self.logger.warning("Cannot pause: player not running")
            return False
        
        try:
            # Get current pause state
            is_paused = self._get_property("pause")
            
            # Toggle pause
            success = self._set_property("pause", not is_paused)
            
            if success:
                self.state = PlayerState.PAUSED if not is_paused else PlayerState.PLAYING
                self.logger.info(f"Playback {'paused' if not is_paused else 'resumed'}")
            
            return success
        
        except Exception as e:
            self.logger.error(f"Error toggling pause: {e}")
            return False
    
    def resume(self) -> bool:
        """
        Resume playback (unpause)
        
        Returns:
            True if successful
        """
        if not self.is_running():
            self.logger.warning("Cannot resume: player not running")
            return False
        
        try:
            success = self._set_property("pause", False)
            
            if success:
                self.state = PlayerState.PLAYING
                self.logger.info("Playback resumed")
            
            return success
        
        except Exception as e:
            self.logger.error(f"Error resuming playback: {e}")
            return False
    
    def stop(self) -> bool:
        """
        Stop playback
        
        Returns:
            True if successful
        """
        try:
            self._cleanup_process()
            self.state = PlayerState.STOPPED
            self.current_file = None
            self.current_position = 0.0
            self.duration = 0.0
            self.logger.info("Playback stopped")
            return True
        
        except Exception as e:
            self.logger.error(f"Error stopping playback: {e}")
            return False
    
    def skip(self, seconds: float) -> bool:
        """
        Skip forward or backward
        
        Args:
            seconds: Number of seconds to skip (negative for backward)
            
        Returns:
            True if successful
        """
        if not self.is_running():
            self.logger.warning("Cannot skip: player not running")
            return False
        
        try:
            response = self._send_command({
                "command": ["seek", seconds, "relative"]
            })
            
            success = response and response.get("error") == "success"
            
            if success:
                # Force audio resync after seeking
                time.sleep(0.1)
                self._send_command({"command": ["ao-reload"]})
                self.logger.info(f"Skipped {seconds}s")
            
            return success
        
        except Exception as e:
            self.logger.error(f"Error skipping: {e}")
            return False
    
    def seek(self, position: float) -> bool:
        """
        Seek to specific position
        
        Args:
            position: Position in seconds
            
        Returns:
            True if successful
        """
        if not self.is_running():
            self.logger.warning("Cannot seek: player not running")
            return False
        
        try:
            response = self._send_command({
                "command": ["seek", position, "absolute"]
            })
            
            success = response and response.get("error") == "success"
            
            if success:
                # Force audio resync after seeking
                time.sleep(0.1)
                self._send_command({"command": ["ao-reload"]})
                self.logger.info(f"Seeked to {position}s")
            
            return success
        
        except Exception as e:
            self.logger.error(f"Error seeking: {e}")
            return False
    
    def set_volume(self, level: int) -> bool:
        """
        Set volume level
        
        Args:
            level: Volume level (0-150)
            
        Returns:
            True if successful
        """
        if not self.is_running():
            self.logger.warning("Cannot set volume: player not running")
            return False
        
        try:
            success = self._set_property("volume", level)
            
            if success:
                self.volume = level
                self.logger.info(f"Volume set to {level}")
            
            return success
        
        except Exception as e:
            self.logger.error(f"Error setting volume: {e}")
            return False
    
    def set_hdmi_output(self, output: str) -> bool:
        """
        Set HDMI output (requires restart)
        
        Args:
            output: HDMI output selection
            
        Returns:
            True if successful
        """
        try:
            self.hdmi_output = output
            
            # If playing, restart with new output
            if self.is_running() and self.current_file:
                current_pos = self.current_position
                file_path = self.media_dir / self.current_file
                
                self.stop()
                success = self.play(str(file_path))
                
                if success and current_pos > 0:
                    self.seek(current_pos)
                
                return success
            
            self.logger.info(f"HDMI output set to {output}")
            return True
        
        except Exception as e:
            self.logger.error(f"Error setting HDMI output: {e}")
            return False
    
    def is_running(self) -> bool:
        """
        Check if MPV process is running
        
        Returns:
            True if running
        """
        if self.process is None:
            return False
        
        # Check if process is still alive
        poll_result = self.process.poll()
        if poll_result is not None:
            # Process has terminated
            self._cleanup_process()
            self.state = PlayerState.STOPPED
            return False
        
        return True
    
    def get_status(self) -> Dict[str, Any]:
        """
        Get current player status
        
        Returns:
            Status dictionary
        """
        status = {
            "state": self.state.value,
            "current_file": self.current_file,
            "position": 0.0,
            "duration": self.duration,
            "volume": self.volume,
            "is_paused": False
        }
        
        if self.is_running():
            # Update position
            pos = self._get_property("time-pos")
            if pos is not None:
                self.current_position = pos
                status["position"] = pos
            
            # Update pause state
            is_paused = self._get_property("pause")
            if is_paused is not None:
                status["is_paused"] = is_paused
                self.state = PlayerState.PAUSED if is_paused else PlayerState.PLAYING
                status["state"] = self.state.value
        
        return status
    
    def __del__(self):
        """Cleanup on deletion"""
        self._cleanup_process()
