#!/bin/bash
#
# Test Runner Script
# Runs all tests and generates coverage report
#
# GitHub: https://github.com/keep-on-walking/Headless-Pi-MPV-Player-Enhanced-Edition
# Author: keep-on-walking
#

set -e

echo "=========================================="
echo "  Headless Pi MPV Player - Test Runner"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Check if virtual environment exists
if [[ ! -d "venv" ]]; then
    echo "Error: Virtual environment not found"
    echo "Run install.sh first or create venv manually"
    exit 1
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install test dependencies if not already installed
echo "Checking test dependencies..."
pip install -q pytest pytest-asyncio pytest-cov 2>/dev/null || {
    echo "Installing test dependencies..."
    pip install pytest pytest-asyncio pytest-cov
}

echo ""
echo "Running tests..."
echo ""

# Run tests with coverage
if pytest test_app.py -v --cov=app --cov=mpv_controller --cov-report=html --cov-report=term; then
    echo ""
    echo "=========================================="
    echo "  ✅ All Tests Passed!"
    echo "=========================================="
    echo ""
    echo "Coverage report generated in: htmlcov/index.html"
    echo ""
    echo "To view the coverage report:"
    echo "  cd htmlcov"
    echo "  python -m http.server 8000"
    echo "  Then open http://your-ip:8000 in browser"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "  ❌ Tests Failed"
    echo "=========================================="
    echo ""
    exit 1
fi
