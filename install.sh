#!/bin/bash

#==============================================================================
# Headless Pi MPV Player - Installation Script
# Enhanced with error handling, validation, and logging
#
# GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
# Author: keep-on-walking
#
# One-command installation:
#   curl -sSL https://raw.githubusercontent.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition/main/install.sh | bash
#==============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

#==============================================================================
# CONFIGURATION
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME}"
INSTALL_DIR="${USER_HOME}/headless-mpv-player"
MEDIA_DIR="${USER_HOME}/videos"
CONFIG_FILE="${USER_HOME}/headless-mpv-config.json"
LOG_DIR="${USER_HOME}/logs"
LOG_FILE="${LOG_DIR}/install.log"
SERVICE_NAME="headless-mpv-player"

# GitHub repository details
GITHUB_REPO="keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# Detect if running from curl pipe (no local files)
if [[ ! -f "${SCRIPT_DIR}/app.py" ]]; then
    DOWNLOAD_FROM_GITHUB=true
else
    DOWNLOAD_FROM_GITHUB=false
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

log_info() {
    local msg="$1"
    echo -e "${BLUE}[INFO]${NC} ${msg}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ${msg}" >> "${LOG_FILE}"
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${msg}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] ${msg}" >> "${LOG_FILE}"
}

log_warning() {
    local msg="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${msg}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] ${msg}" >> "${LOG_FILE}"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} ${msg}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${msg}" >> "${LOG_FILE}"
}

#==============================================================================
# ERROR HANDLING
#==============================================================================

error_exit() {
    local msg="$1"
    local exit_code="${2:-1}"
    log_error "${msg}"
    log_error "Installation failed. Check ${LOG_FILE} for details."
    exit "${exit_code}"
}

cleanup_on_error() {
    log_warning "Cleaning up after error..."
    
    # Stop service if it was started
    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        sudo systemctl stop "${SERVICE_NAME}" || true
    fi
    
    # Remove service file if it was created
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service" || true
        sudo systemctl daemon-reload || true
    fi
}

# Set up trap for errors
trap 'cleanup_on_error' ERR

#==============================================================================
# VALIDATION FUNCTIONS
#==============================================================================

check_os() {
    log_info "Checking operating system..."
    
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot detect operating system"
    fi
    
    . /etc/os-release
    
    if [[ "${ID}" != "raspbian" ]] && [[ "${ID}" != "debian" ]] && [[ "${ID}" != "ubuntu" ]]; then
        log_warning "This script is designed for Raspberry Pi OS, but detected: ${PRETTY_NAME}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        log_success "OS detected: ${PRETTY_NAME}"
    fi
}

check_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        error_exit "This script should NOT be run as root. Run as normal user (pi)."
    fi
}

check_sudo() {
    log_info "Checking sudo access..."
    
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo access. You may be prompted for your password."
        if ! sudo -v; then
            error_exit "Cannot obtain sudo access"
        fi
    fi
    
    log_success "Sudo access confirmed"
}

check_disk_space() {
    log_info "Checking disk space..."
    
    local available_mb=$(df -m "${USER_HOME}" | awk 'NR==2 {print $4}')
    local required_mb=500
    
    if [[ ${available_mb} -lt ${required_mb} ]]; then
        error_exit "Insufficient disk space. Need ${required_mb}MB, have ${available_mb}MB"
    fi
    
    log_success "Disk space: ${available_mb}MB available"
}

check_internet() {
    log_info "Checking internet connection..."
    
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        error_exit "No internet connection. Please connect to the internet and try again."
    fi
    
    log_success "Internet connection OK"
}

download_from_github() {
    log_info "Downloading files from GitHub repository..."
    
    local files=(
        "app.py"
        "mpv_controller.py"
        "requirements.txt"
    )
    
    local template_files=(
        "templates/index.html"
    )
    
    local static_files=(
        "static/app.js"
        "static/style.css"
    )
    
    # Create install directory if it doesn't exist
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/templates"
    mkdir -p "${INSTALL_DIR}/static"
    cd "${INSTALL_DIR}" || error_exit "Cannot access ${INSTALL_DIR}"
    
    # Download main files
    for file in "${files[@]}"; do
        log_info "Downloading ${file}..."
        if ! curl -sSL -f "${GITHUB_RAW_BASE}/${file}" -o "${file}"; then
            error_exit "Failed to download ${file} from GitHub"
        fi
        log_success "Downloaded ${file}"
    done
    
    # Download template files
    for file in "${template_files[@]}"; do
        log_info "Downloading ${file}..."
        if ! curl -sSL -f "${GITHUB_RAW_BASE}/${file}" -o "${file}"; then
            error_exit "Failed to download ${file} from GitHub"
        fi
        log_success "Downloaded ${file}"
    done
    
    # Download static files
    for file in "${static_files[@]}"; do
        log_info "Downloading ${file}..."
        if ! curl -sSL -f "${GITHUB_RAW_BASE}/${file}" -o "${file}"; then
            error_exit "Failed to download ${file} from GitHub"
        fi
        log_success "Downloaded ${file}"
    done
    
    log_success "All files downloaded from GitHub"
}

#==============================================================================
# INSTALLATION FUNCTIONS
#==============================================================================

create_directories() {
    log_info "Creating directories..."
    
    mkdir -p "${INSTALL_DIR}" || error_exit "Failed to create ${INSTALL_DIR}"
    mkdir -p "${MEDIA_DIR}" || error_exit "Failed to create ${MEDIA_DIR}"
    mkdir -p "${LOG_DIR}" || error_exit "Failed to create ${LOG_DIR}"
    
    log_success "Directories created"
}

update_system() {
    log_info "Updating system packages..."
    
    if ! sudo apt-get update; then
        error_exit "Failed to update package lists"
    fi
    
    log_success "System updated"
}

install_dependencies() {
    log_info "Installing system dependencies..."
    
    local packages=(
        "mpv"
        "python3"
        "python3-pip"
        "python3-venv"
        "git"
        "alsa-utils"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  ${package} "; then
            log_info "Installing ${package}..."
            if ! sudo apt-get install -y "${package}"; then
                error_exit "Failed to install ${package}"
            fi
        else
            log_info "${package} already installed"
        fi
    done
    
    log_success "System dependencies installed"
}

setup_python_venv() {
    log_info "Setting up Python virtual environment..."
    
    cd "${INSTALL_DIR}" || error_exit "Cannot access ${INSTALL_DIR}"
    
    if [[ ! -d "venv" ]]; then
        if ! python3 -m venv venv; then
            error_exit "Failed to create virtual environment"
        fi
    fi
    
    if ! source venv/bin/activate; then
        error_exit "Failed to activate virtual environment"
    fi
    
    # Upgrade pip
    if ! pip install --upgrade pip; then
        log_warning "Failed to upgrade pip, continuing..."
    fi
    
    log_success "Python virtual environment ready"
}

install_python_dependencies() {
    log_info "Installing Python dependencies..."
    
    cd "${INSTALL_DIR}" || error_exit "Cannot access ${INSTALL_DIR}"
    source venv/bin/activate || error_exit "Failed to activate venv"
    
    if [[ -f requirements.txt ]]; then
        if ! pip install -r requirements.txt; then
            error_exit "Failed to install Python dependencies"
        fi
    else
        # Install dependencies directly if requirements.txt doesn't exist
        local python_packages=(
            "flask"
            "werkzeug"
            "aiofiles"
        )
        
        for package in "${python_packages[@]}"; do
            log_info "Installing ${package}..."
            if ! pip install "${package}"; then
                error_exit "Failed to install ${package}"
            fi
        done
    fi
    
    log_success "Python dependencies installed"
}

copy_files() {
    log_info "Setting up application files..."
    
    if [[ "${DOWNLOAD_FROM_GITHUB}" == "true" ]]; then
        # Files already downloaded to INSTALL_DIR
        log_info "Files already downloaded from GitHub"
    else
        # Copy from local script directory
        log_info "Copying application files..."
        
        # Copy Python files
        for file in app.py mpv_controller.py requirements.txt; do
            if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
                cp "${SCRIPT_DIR}/${file}" "${INSTALL_DIR}/" || error_exit "Failed to copy ${file}"
            fi
        done
        
        # Copy directories
        for dir in templates static; do
            if [[ -d "${SCRIPT_DIR}/${dir}" ]]; then
                cp -r "${SCRIPT_DIR}/${dir}" "${INSTALL_DIR}/" || error_exit "Failed to copy ${dir}"
            fi
        done
    fi
    
    # Make Python files executable
    chmod +x "${INSTALL_DIR}/app.py" || error_exit "Failed to make app.py executable"
    chmod +x "${INSTALL_DIR}/mpv_controller.py" || error_exit "Failed to make mpv_controller.py executable"
    
    log_success "Application files ready"
}

create_config() {
    log_info "Creating configuration file..."
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat > "${CONFIG_FILE}" <<EOF
{
  "media_dir": "${MEDIA_DIR}",
  "max_upload_size": 2147483648,
  "volume": 100,
  "loop": false,
  "hardware_accel": true,
  "hdmi_output": "auto",
  "audio_in_headless": true,
  "port": 5000,
  "log_level": "INFO"
}
EOF
        
        if [[ $? -ne 0 ]]; then
            error_exit "Failed to create config file"
        fi
        
        log_success "Configuration file created: ${CONFIG_FILE}"
    else
        log_info "Configuration file already exists, skipping"
    fi
}

setup_service() {
    log_info "Setting up systemd service..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    sudo tee "${service_file}" > /dev/null <<EOF
[Unit]
Description=Headless Pi MPV Player
After=network.target sound.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${INSTALL_DIR}
Environment="PATH=${INSTALL_DIR}/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${INSTALL_DIR}/venv/bin/python ${INSTALL_DIR}/app.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    if [[ $? -ne 0 ]]; then
        error_exit "Failed to create service file"
    fi
    
    # Reload systemd
    if ! sudo systemctl daemon-reload; then
        error_exit "Failed to reload systemd"
    fi
    
    # Enable service
    if ! sudo systemctl enable "${SERVICE_NAME}"; then
        error_exit "Failed to enable service"
    fi
    
    log_success "Service configured and enabled"
}

setup_screen_blanking() {
    log_info "Setting up screen blanking..."
    
    # Copy blank screen script if it exists
    if [[ -f "${SCRIPT_DIR}/fix_blank_screen.sh" ]]; then
        sudo cp "${SCRIPT_DIR}/fix_blank_screen.sh" /usr/local/bin/
        sudo chmod +x /usr/local/bin/fix_blank_screen.sh
        
        # Copy blank screen service if it exists
        if [[ -f "${SCRIPT_DIR}/blank-screen.service" ]]; then
            sudo cp "${SCRIPT_DIR}/blank-screen.service" /etc/systemd/system/
            sudo systemctl daemon-reload
            sudo systemctl enable blank-screen.service
            log_success "Screen blanking configured"
        fi
    else
        log_warning "Screen blanking scripts not found, skipping"
    fi
}

start_service() {
    log_info "Starting service..."
    
    if ! sudo systemctl start "${SERVICE_NAME}"; then
        error_exit "Failed to start service"
    fi
    
    # Wait a moment for service to start
    sleep 2
    
    # Check if service is running
    if ! sudo systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_error "Service failed to start. Checking logs..."
        sudo journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
        error_exit "Service is not running"
    fi
    
    log_success "Service started successfully"
}

#==============================================================================
# NETWORK INFO
#==============================================================================

get_ip_address() {
    local ip=$(hostname -I | awk '{print $1}')
    echo "${ip}"
}

#==============================================================================
# MAIN INSTALLATION
#==============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  Headless Pi MPV Player - Installer"
    echo "=========================================="
    echo ""
    
    # Create log directory first
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    
    log_info "Installation started"
    log_info "Log file: ${LOG_FILE}"
    echo ""
    
    # Pre-flight checks
    check_root
    check_os
    check_sudo
    check_disk_space
    check_internet
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    # Installation steps
    create_directories
    
    # Download from GitHub if needed
    if [[ "${DOWNLOAD_FROM_GITHUB}" == "true" ]]; then
        download_from_github
    fi
    
    update_system
    install_dependencies
    setup_python_venv
    install_python_dependencies
    copy_files
    create_config
    setup_service
    setup_screen_blanking
    start_service
    
    echo ""
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo ""
    log_success "Installation completed successfully"
    
    local ip=$(get_ip_address)
    
    echo "Web Interface: http://${ip}:5000"
    echo "Media Directory: ${MEDIA_DIR}"
    echo "Config File: ${CONFIG_FILE}"
    echo "Log File: ${LOG_DIR}/headless-mpv.log"
    echo ""
    echo "Service Commands:"
    echo "  Start:   sudo systemctl start ${SERVICE_NAME}"
    echo "  Stop:    sudo systemctl stop ${SERVICE_NAME}"
    echo "  Restart: sudo systemctl restart ${SERVICE_NAME}"
    echo "  Status:  sudo systemctl status ${SERVICE_NAME}"
    echo "  Logs:    sudo journalctl -u ${SERVICE_NAME} -f"
    echo ""
    echo "Installation log: ${LOG_FILE}"
    echo ""
}

# Run main installation
main "$@"
