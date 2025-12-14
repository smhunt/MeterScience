#!/bin/bash
set -e

echo "=========================================="
echo "  MeterScience Development Sandbox"
echo "  DANGEROUS MODE: Full Permissions"
echo "=========================================="
echo ""

# Initialize git repo if not exists
if [ ! -d "/workspace/.git" ]; then
    echo "[INIT] Initializing git repository..."
    cd /workspace
    git init
    git add -A 2>/dev/null || true
    git commit -m "Initial commit" 2>/dev/null || true
fi

# Create Python virtual environments
if [ ! -d "/workspace/api/venv" ]; then
    echo "[INIT] Creating API virtual environment..."
    python3 -m venv /workspace/api/venv
fi

if [ ! -d "/workspace/meterpi/venv" ]; then
    echo "[INIT] Creating MeterPi virtual environment..."
    python3 -m venv /workspace/meterpi/venv
fi

# Install dependencies if requirements exist
if [ -f "/workspace/api/requirements.txt" ]; then
    echo "[INIT] Installing API dependencies..."
    /workspace/api/venv/bin/pip install -r /workspace/api/requirements.txt
fi

if [ -f "/workspace/meterpi/requirements.txt" ]; then
    echo "[INIT] Installing MeterPi dependencies..."
    /workspace/meterpi/venv/bin/pip install -r /workspace/meterpi/requirements.txt
fi

# Install Node dependencies if package.json exists
if [ -f "/workspace/web/package.json" ]; then
    echo "[INIT] Installing web dependencies..."
    cd /workspace/web && npm install
fi

# Print status
echo ""
echo "[STATUS] Environment ready!"
echo ""
echo "Available commands:"
echo "  claude                    - Start Claude Code"
echo "  cd /workspace && claude   - Start in project root"
echo ""
echo "Services:"
echo "  uvicorn api.main:app --reload --host 0.0.0.0 --port 8000"
echo "  python meterpi/meterpi.py --api-only"
echo "  cd web && npm run dev"
echo ""
echo "Project structure:"
tree -L 2 /workspace 2>/dev/null || ls -la /workspace
echo ""
echo "=========================================="

# Execute command or start interactive shell
exec "$@"
