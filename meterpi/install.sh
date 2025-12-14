#!/bin/bash
# MeterPi Installation Script
# Run on a fresh Raspberry Pi OS Lite installation

set -e

echo "=========================================="
echo "  MeterPi Installation"
echo "=========================================="

# Update system
echo "[1/8] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
echo "[2/8] Installing dependencies..."
sudo apt-get install -y \
    python3-pip \
    python3-opencv \
    python3-flask \
    python3-numpy \
    tesseract-ocr \
    tesseract-ocr-eng \
    libatlas-base-dev \
    libjasper-dev \
    libqtgui4 \
    libqt4-test \
    libhdf5-dev \
    git

# Install Python packages
echo "[3/8] Installing Python packages..."
pip3 install --break-system-packages \
    pytesseract \
    flask-cors \
    paho-mqtt \
    requests

# Create directory structure
echo "[4/8] Creating directories..."
sudo mkdir -p /home/pi/meterpi
sudo mkdir -p /home/pi/meterpi/images
sudo chown -R pi:pi /home/pi/meterpi

# Copy application files
echo "[5/8] Installing application..."
cp meterpi.py /home/pi/meterpi/
chmod +x /home/pi/meterpi/meterpi.py

# Create default config
echo "[6/8] Creating configuration..."
cat > /home/pi/meterpi/config.json << 'EOF'
{
    "capture_interval_seconds": 60,
    "camera_device": 0,
    "camera_width": 1280,
    "camera_height": 720,
    "api_port": 5000,
    "mqtt_enabled": false,
    "mqtt_broker": "localhost",
    "mqtt_topic": "meterpi/readings",
    "cloud_sync_enabled": false,
    "cloud_api_url": "https://api.meterscience.io/v1",
    "cloud_api_key": "",
    "meter_type": "electric",
    "expected_digits": 6,
    "min_confidence": 0.7,
    "consensus_frames": 3
}
EOF

# Create systemd service
echo "[7/8] Setting up systemd service..."
sudo cat > /etc/systemd/system/meterpi.service << 'EOF'
[Unit]
Description=MeterPi Meter Reading Service
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/meterpi
ExecStart=/usr/bin/python3 /home/pi/meterpi/meterpi.py
Restart=always
RestartSec=10
StandardOutput=append:/home/pi/meterpi/meterpi.log
StandardError=append:/home/pi/meterpi/meterpi.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable meterpi.service

# Enable camera
echo "[8/8] Enabling camera..."
sudo raspi-config nonint do_camera 0 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Edit /home/pi/meterpi/config.json with your settings"
echo "  2. Mount camera pointing at your meter"
echo "  3. Start service: sudo systemctl start meterpi"
echo "  4. View logs: tail -f /home/pi/meterpi/meterpi.log"
echo "  5. Access API: http://$(hostname -I | awk '{print $1}'):5000/api/v1/readings/latest"
echo ""
echo "Reboot recommended: sudo reboot"
