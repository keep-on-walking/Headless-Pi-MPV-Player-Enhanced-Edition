/**
 * Headless Pi MPV Player - Enhanced Edition
 * Web Interface JavaScript
 * 
 * GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
 * Author: keep-on-walking
 */

// API Configuration
const API_BASE = '/api';
const UPDATE_INTERVAL = 1000; // 1 second

// State
let updateTimer = null;
let currentFiles = [];

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Show notification to user
 */
function showNotification(message, type = 'info') {
    const notification = document.getElementById('notification');
    notification.textContent = message;
    notification.className = `notification ${type} show`;
    
    setTimeout(() => {
        notification.classList.remove('show');
    }, 3000);
}

/**
 * Format seconds to MM:SS or HH:MM:SS
 */
function formatTime(seconds) {
    if (!seconds || seconds < 0) return '0:00';
    
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    
    if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    } else {
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }
}

/**
 * Format bytes to human readable
 */
function formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}

/**
 * Make API request
 */
async function apiRequest(endpoint, options = {}) {
    try {
        const response = await fetch(`${API_BASE}${endpoint}`, {
            headers: {
                'Content-Type': 'application/json',
            },
            ...options
        });
        
        const data = await response.json();
        
        if (!response.ok) {
            throw new Error(data.error || 'Request failed');
        }
        
        return data;
    } catch (error) {
        console.error('API request failed:', error);
        throw error;
    }
}

// ============================================================================
// Status Updates
// ============================================================================

/**
 * Update player status display
 */
async function updateStatus() {
    try {
        const status = await apiRequest('/status');
        
        // Update status display
        document.getElementById('status-state').textContent = status.state || 'Unknown';
        document.getElementById('status-file').textContent = status.current_file || 'None';
        document.getElementById('status-position').textContent = formatTime(status.position);
        document.getElementById('status-duration').textContent = formatTime(status.duration);
        document.getElementById('status-volume').textContent = status.volume || 100;
        
        // Update progress bar
        if (status.duration > 0) {
            const progress = (status.position / status.duration) * 100;
            document.getElementById('progress-bar').style.width = `${progress}%`;
        } else {
            document.getElementById('progress-bar').style.width = '0%';
        }
        
        // Update state indicator color
        const stateElement = document.getElementById('status-state');
        stateElement.className = 'status-value';
        if (status.state === 'playing') {
            stateElement.style.color = '#10b981'; // Green
        } else if (status.state === 'paused') {
            stateElement.style.color = '#f59e0b'; // Yellow
        } else {
            stateElement.style.color = '#6b7280'; // Gray
        }
        
    } catch (error) {
        console.error('Failed to update status:', error);
    }
}

/**
 * Update system health information
 */
async function updateHealth() {
    try {
        const health = await apiRequest('/health');
        
        // Update disk space
        if (health.disk_space) {
            const freeGB = (health.disk_space.free / (1024 * 1024 * 1024)).toFixed(2);
            const totalGB = (health.disk_space.total / (1024 * 1024 * 1024)).toFixed(2);
            const percentUsed = health.disk_space.percent_used || 0;
            document.getElementById('disk-free').textContent = 
                `${freeGB} GB free of ${totalGB} GB (${percentUsed.toFixed(1)}% used)`;
        }
        
        // Update health status
        const healthStatus = document.getElementById('health-status');
        healthStatus.textContent = health.status || 'Unknown';
        if (health.status === 'healthy') {
            healthStatus.style.color = '#10b981'; // Green
        } else {
            healthStatus.style.color = '#dc2626'; // Red
        }
        
    } catch (error) {
        console.error('Failed to update health:', error);
    }
}

/**
 * Start automatic status updates
 */
function startStatusUpdates() {
    updateStatus();
    updateHealth();
    
    if (updateTimer) {
        clearInterval(updateTimer);
    }
    
    updateTimer = setInterval(() => {
        updateStatus();
    }, UPDATE_INTERVAL);
    
    // Update health less frequently
    setInterval(updateHealth, 10000); // Every 10 seconds
}

// ============================================================================
// Playback Controls
// ============================================================================

/**
 * Play specific file or resume
 */
async function play(filename = null) {
    try {
        const payload = filename ? { file: filename } : {};
        const result = await apiRequest('/play', {
            method: 'POST',
            body: JSON.stringify(payload)
        });
        
        if (result.success) {
            showNotification(filename ? `Playing: ${filename}` : 'Resumed playback', 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`Play failed: ${error.message}`, 'error');
    }
}

/**
 * Pause/resume playback
 */
async function pause() {
    try {
        const result = await apiRequest('/pause', { method: 'POST' });
        
        if (result.success) {
            showNotification('Playback paused/resumed', 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`Pause failed: ${error.message}`, 'error');
    }
}

/**
 * Stop playback
 */
async function stop() {
    try {
        const result = await apiRequest('/stop', { method: 'POST' });
        
        if (result.success) {
            showNotification('Playback stopped', 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`Stop failed: ${error.message}`, 'error');
    }
}

/**
 * Skip forward or backward
 */
async function skip(seconds) {
    try {
        const result = await apiRequest('/skip', {
            method: 'POST',
            body: JSON.stringify({ seconds: seconds })
        });
        
        if (result.success) {
            showNotification(`Skipped ${seconds}s`, 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`Skip failed: ${error.message}`, 'error');
    }
}

/**
 * Seek to specific position
 */
async function seek(position) {
    try {
        const result = await apiRequest('/seek', {
            method: 'POST',
            body: JSON.stringify({ position: position })
        });
        
        if (result.success) {
            showNotification(`Seeked to ${formatTime(position)}`, 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`Seek failed: ${error.message}`, 'error');
    }
}

/**
 * Set volume level
 */
async function setVolume(level) {
    try {
        const result = await apiRequest('/volume', {
            method: 'POST',
            body: JSON.stringify({ level: level })
        });
        
        if (result.success) {
            showNotification(`Volume set to ${level}`, 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`Volume change failed: ${error.message}`, 'error');
    }
}

/**
 * Set HDMI output
 */
async function setHDMI(output) {
    try {
        const result = await apiRequest('/hdmi', {
            method: 'POST',
            body: JSON.stringify({ output: output })
        });
        
        if (result.success) {
            showNotification(`HDMI output set to ${output}`, 'success');
            updateStatus();
        }
    } catch (error) {
        showNotification(`HDMI change failed: ${error.message}`, 'error');
    }
}

// ============================================================================
// File Management
// ============================================================================

/**
 * Load and display file list
 */
async function loadFiles() {
    try {
        const result = await apiRequest('/files');
        
        if (result.success) {
            currentFiles = result.files;
            displayFiles(result.files);
        }
    } catch (error) {
        console.error('Failed to load files:', error);
        document.getElementById('file-list').innerHTML = 
            '<p class="loading">Failed to load files</p>';
    }
}

/**
 * Display files in the list
 */
function displayFiles(files) {
    const fileList = document.getElementById('file-list');
    
    if (files.length === 0) {
        fileList.innerHTML = '<p class="loading">No video files found</p>';
        return;
    }
    
    fileList.innerHTML = files.map(file => `
        <div class="file-item">
            <div class="file-info">
                <div class="file-name">${file.name}</div>
                <div class="file-meta">
                    ${formatBytes(file.size)} • Modified: ${new Date(file.modified).toLocaleString()}
                </div>
            </div>
            <div class="file-actions">
                <button class="btn btn-primary btn-small" onclick="play('${file.name}')">
                    ▶ Play
                </button>
                <button class="btn btn-danger btn-small" onclick="deleteFile('${file.name}')">
                    🗑 Delete
                </button>
            </div>
        </div>
    `).join('');
}

/**
 * Upload file
 */
async function uploadFile() {
    const fileInput = document.getElementById('file-upload');
    const file = fileInput.files[0];
    
    if (!file) {
        showNotification('Please select a file', 'warning');
        return;
    }
    
    const formData = new FormData();
    formData.append('file', file);
    
    const progressContainer = document.getElementById('upload-progress');
    const progressBar = document.getElementById('upload-progress-bar');
    const statusText = document.getElementById('upload-status');
    
    progressContainer.style.display = 'block';
    progressBar.style.width = '0%';
    statusText.textContent = 'Uploading...';
    
    try {
        const xhr = new XMLHttpRequest();
        
        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percentComplete = (e.loaded / e.total) * 100;
                progressBar.style.width = `${percentComplete}%`;
                statusText.textContent = `Uploading... ${Math.round(percentComplete)}%`;
            }
        });
        
        xhr.addEventListener('load', () => {
            if (xhr.status === 200) {
                const result = JSON.parse(xhr.responseText);
                if (result.success) {
                    showNotification('File uploaded successfully', 'success');
                    fileInput.value = '';
                    progressContainer.style.display = 'none';
                    loadFiles();
                } else {
                    showNotification(`Upload failed: ${result.error}`, 'error');
                    progressContainer.style.display = 'none';
                }
            } else {
                showNotification('Upload failed', 'error');
                progressContainer.style.display = 'none';
            }
        });
        
        xhr.addEventListener('error', () => {
            showNotification('Upload failed', 'error');
            progressContainer.style.display = 'none';
        });
        
        xhr.open('POST', `${API_BASE}/upload`);
        xhr.send(formData);
        
    } catch (error) {
        showNotification(`Upload failed: ${error.message}`, 'error');
        progressContainer.style.display = 'none';
    }
}

/**
 * Delete file
 */
async function deleteFile(filename) {
    if (!confirm(`Are you sure you want to delete "${filename}"?`)) {
        return;
    }
    
    try {
        const result = await apiRequest(`/files/${encodeURIComponent(filename)}`, {
            method: 'DELETE'
        });
        
        if (result.success) {
            showNotification(`Deleted: ${filename}`, 'success');
            loadFiles();
        }
    } catch (error) {
        showNotification(`Delete failed: ${error.message}`, 'error');
    }
}

// ============================================================================
// Event Handlers
// ============================================================================

function setupEventHandlers() {
    // Playback controls
    document.getElementById('btn-play').addEventListener('click', () => play());
    document.getElementById('btn-pause').addEventListener('click', pause);
    document.getElementById('btn-stop').addEventListener('click', stop);
    
    // Skip controls
    document.getElementById('btn-skip-back-30').addEventListener('click', () => skip(-30));
    document.getElementById('btn-skip-back-10').addEventListener('click', () => skip(-10));
    document.getElementById('btn-skip-forward-10').addEventListener('click', () => skip(10));
    document.getElementById('btn-skip-forward-30').addEventListener('click', () => skip(30));
    
    // Custom skip
    document.getElementById('btn-custom-skip').addEventListener('click', () => {
        const seconds = parseInt(document.getElementById('custom-skip').value);
        if (!isNaN(seconds)) {
            skip(seconds);
        }
    });
    
    // Seek
    document.getElementById('btn-seek').addEventListener('click', () => {
        const position = parseInt(document.getElementById('seek-position').value);
        if (!isNaN(position) && position >= 0) {
            seek(position);
        }
    });
    
    // Volume control
    const volumeControl = document.getElementById('volume-control');
    const volumeDisplay = document.getElementById('volume-display');
    
    volumeControl.addEventListener('input', () => {
        volumeDisplay.textContent = volumeControl.value;
    });
    
    document.getElementById('btn-set-volume').addEventListener('click', () => {
        const level = parseInt(volumeControl.value);
        setVolume(level);
    });
    
    // HDMI output
    document.getElementById('btn-set-hdmi').addEventListener('click', () => {
        const output = document.getElementById('hdmi-output').value;
        setHDMI(output);
    });
    
    // File management
    document.getElementById('btn-upload').addEventListener('click', uploadFile);
    document.getElementById('btn-refresh-files').addEventListener('click', loadFiles);
}

// ============================================================================
// Initialization
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('Headless Pi MPV Player - Enhanced Edition');
    console.log('GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition');
    
    setupEventHandlers();
    startStatusUpdates();
    loadFiles();
    
    // Show welcome notification
    showNotification('Connected to MPV Player', 'success');
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (updateTimer) {
        clearInterval(updateTimer);
    }
});
