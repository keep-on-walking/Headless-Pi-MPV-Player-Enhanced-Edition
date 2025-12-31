#!/bin/bash
#
# Test Pi 5 Hardware Decoding
# Tests different hardware decoding methods
#

VIDEO_FILE="/home/mpvdev/videos/boxingv14.mp4"

echo "==========================================="
echo "Testing Hardware Decoding on Pi 5"
echo "==========================================="
echo ""

# Check available decoders
echo "Available hardware decoders:"
mpv --hwdec=help
echo ""

# Check V4L2 devices
echo "V4L2 devices:"
ls -la /dev/video* 2>/dev/null || echo "No V4L2 devices found"
echo ""

# Test 1: Auto detection
echo "TEST 1: Auto hardware decoding (hwdec=auto)"
echo "---"
mpv --hwdec=auto --vo=gpu --gpu-context=drm --msg-level=all=info --frames=60 "$VIDEO_FILE" 2>&1 | grep -E "hwdec|decode|Dropped" | head -10
echo ""

# Test 2: Force V4L2 M2M (Pi 5's hardware decoder)
echo "TEST 2: V4L2 M2M decoder (hwdec=v4l2m2m-copy)"
echo "---"
mpv --hwdec=v4l2m2m-copy --vo=gpu --gpu-context=drm --msg-level=all=info --frames=60 "$VIDEO_FILE" 2>&1 | grep -E "hwdec|decode|Dropped" | head -10
echo ""

# Test 3: DRM PRIME
echo "TEST 3: DRM PRIME decoder (hwdec=drm-copy)"
echo "---"
mpv --hwdec=drm-copy --vo=gpu --gpu-context=drm --msg-level=all=info --frames=60 "$VIDEO_FILE" 2>&1 | grep -E "hwdec|decode|Dropped" | head -10
echo ""

# Test 4: Check if codec is supported
echo "Checking video codec:"
ffprobe "$VIDEO_FILE" 2>&1 | grep -E "Video:|codec_name"
echo ""

echo "==========================================="
echo "If all tests show 'Dropped' frames, hardware"
echo "decoding is not working."
echo ""
echo "Common causes:"
echo "  - Video codec not supported by Pi 5 hardware"
echo "  - Missing kernel modules"
echo "  - Insufficient permissions"
echo "==========================================="
