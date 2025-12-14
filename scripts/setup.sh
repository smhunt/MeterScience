#!/bin/bash
# MeterScience Master Setup Script
# Autonomous execution - creates entire project from scratch

set -e  # Exit on error

echo "=========================================="
echo "  MeterScience - Full Project Setup"
echo "=========================================="

WORKSPACE="/workspace"
cd "$WORKSPACE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ============================================
# 1. Create iOS Project Structure
# ============================================
log "Creating iOS project structure..."

mkdir -p ios/MeterScience/Views
mkdir -p ios/MeterScience/Models
mkdir -p ios/MeterScience/Services
mkdir -p ios/MeterScience/Resources
mkdir -p ios/MeterScienceTests

# Create iOS files
cat > ios/MeterScience/MeterScienceApp.swift << 'SWIFT'
import SwiftUI

@main
struct MeterScienceApp: App {
    @StateObject private var dataStore = MeterDataStore()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataStore)
                .environmentObject(subscriptionManager)
        }
    }
}
SWIFT

log "iOS structure created"

# ============================================
# 2. Create MeterPi Structure
# ============================================
log "Creating MeterPi structure..."

mkdir -p meterpi/tests
mkdir -p meterpi/mounts

cat > meterpi/requirements.txt << 'REQS'
# MeterPi Requirements
opencv-python-headless>=4.8.0
pytesseract>=0.3.10
numpy>=1.24.0
flask>=3.0.0
flask-cors>=4.0.0
paho-mqtt>=1.6.0
requests>=2.31.0
pillow>=10.0.0
python-dotenv>=1.0.0
REQS

cat > meterpi/config.json << 'CONFIG'
{
    "capture_interval_seconds": 60,
    "camera_device": 0,
    "camera_width": 1280,
    "camera_height": 720,
    "api_port": 5000,
    "mqtt_enabled": false,
    "mqtt_broker": "localhost",
    "mqtt_topic": "meterpi/readings",
    "cloud_sync_enabled": true,
    "cloud_api_url": "https://api.meterscience.io/v1",
    "cloud_api_key": "",
    "meter_type": "electric",
    "expected_digits": 6,
    "min_confidence": 0.7,
    "consensus_frames": 3
}
CONFIG

log "MeterPi structure created"

# ============================================
# 3. Create API Structure
# ============================================
log "Creating API structure..."

mkdir -p api/src/routes
mkdir -p api/src/services
mkdir -p api/src/models
mkdir -p api/tests

cat > api/requirements.txt << 'REQS'
# API Requirements
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy>=2.0.0
psycopg2-binary>=2.9.0
redis>=5.0.0
pydantic>=2.5.0
pydantic-settings>=2.1.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.0
stripe>=7.0.0
boto3>=1.34.0
httpx>=0.26.0
python-multipart>=0.0.6
alembic>=1.13.0
pytest>=7.4.0
pytest-asyncio>=0.23.0
REQS

cat > api/src/main.py << 'PYTHON'
"""
MeterScience API
FastAPI backend for citizen science meter reading platform
"""

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import os

# Lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("🚀 MeterScience API starting...")
    yield
    # Shutdown
    print("👋 MeterScience API shutting down...")

app = FastAPI(
    title="MeterScience API",
    description="Citizen science utility meter reading platform",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "MeterScience API", "version": "1.0.0"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

# Import routes
# from .routes import readings, users, campaigns, verify

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
PYTHON

log "API structure created"

# ============================================
# 4. Create Web/Marketing Structure
# ============================================
log "Creating web structure..."

mkdir -p web/landing
mkdir -p web/docs

cat > web/landing/index.html << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MeterScience - Citizen Science Utility Monitoring</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50">
    <nav class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 py-4">
            <div class="flex justify-between items-center">
                <div class="text-2xl font-bold text-green-600">⚡ MeterScience</div>
                <div class="space-x-4">
                    <a href="#features" class="text-gray-600 hover:text-gray-900">Features</a>
                    <a href="#pricing" class="text-gray-600 hover:text-gray-900">Pricing</a>
                    <a href="#hardware" class="text-gray-600 hover:text-gray-900">MeterPi</a>
                    <a href="#waitlist" class="bg-green-600 text-white px-4 py-2 rounded-lg">Join Waitlist</a>
                </div>
            </div>
        </div>
    </nav>
    
    <main>
        <!-- Hero -->
        <section class="py-20 bg-gradient-to-br from-green-50 to-blue-50">
            <div class="max-w-4xl mx-auto text-center px-4">
                <h1 class="text-5xl font-bold text-gray-900 mb-6">
                    Citizen Science for Your Utility Bills
                </h1>
                <p class="text-xl text-gray-600 mb-8">
                    Scan your meters, track your usage, and unlock neighborhood insights 
                    that utilities can't provide. Your data is always free.
                </p>
                <div class="flex justify-center gap-4">
                    <a href="#waitlist" class="bg-green-600 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-green-700">
                        Join the Waitlist
                    </a>
                    <a href="#how" class="bg-white text-gray-700 px-8 py-4 rounded-lg text-lg font-semibold border hover:bg-gray-50">
                        How It Works
                    </a>
                </div>
            </div>
        </section>
        
        <!-- Features -->
        <section id="features" class="py-20">
            <div class="max-w-6xl mx-auto px-4">
                <h2 class="text-3xl font-bold text-center mb-12">Why MeterScience?</h2>
                <div class="grid md:grid-cols-3 gap-8">
                    <div class="bg-white p-6 rounded-xl shadow">
                        <div class="text-4xl mb-4">📱</div>
                        <h3 class="text-xl font-semibold mb-2">AI-Powered Scanning</h3>
                        <p class="text-gray-600">Point your phone at any meter. Our Vision AI reads it instantly.</p>
                    </div>
                    <div class="bg-white p-6 rounded-xl shadow">
                        <div class="text-4xl mb-4">🏘️</div>
                        <h3 class="text-xl font-semibold mb-2">Neighbor Comparisons</h3>
                        <p class="text-gray-600">See how your usage compares. Find savings opportunities.</p>
                    </div>
                    <div class="bg-white p-6 rounded-xl shadow">
                        <div class="text-4xl mb-4">🔬</div>
                        <h3 class="text-xl font-semibold mb-2">Citizen Science</h3>
                        <p class="text-gray-600">Contribute to research. Help your community save energy.</p>
                    </div>
                </div>
            </div>
        </section>
        
        <!-- Waitlist -->
        <section id="waitlist" class="py-20 bg-green-600">
            <div class="max-w-xl mx-auto text-center px-4">
                <h2 class="text-3xl font-bold text-white mb-4">Get Early Access</h2>
                <p class="text-green-100 mb-8">Join the waitlist and be first to try MeterScience.</p>
                <form class="flex gap-2">
                    <input type="email" placeholder="Enter your email" 
                           class="flex-1 px-4 py-3 rounded-lg text-gray-900">
                    <button type="submit" class="bg-gray-900 text-white px-6 py-3 rounded-lg font-semibold hover:bg-gray-800">
                        Join
                    </button>
                </form>
            </div>
        </section>
    </main>
    
    <footer class="bg-gray-900 text-gray-400 py-8">
        <div class="max-w-6xl mx-auto px-4 text-center">
            <p>© 2024 MeterScience by EcoWorks Web Architecture Inc.</p>
        </div>
    </footer>
</body>
</html>
HTML

log "Web structure created"

# ============================================
# 5. Create Automation Scripts
# ============================================
log "Creating automation scripts..."

cat > scripts/build-ios.sh << 'BASH'
#!/bin/bash
# Build iOS app (requires macOS with Xcode)
echo "Building iOS app..."
cd ios
# xcodebuild -scheme MeterScience -configuration Release
echo "Note: Full build requires macOS with Xcode"
BASH

cat > scripts/run-api.sh << 'BASH'
#!/bin/bash
# Start API server
cd /workspace/api
source venv/bin/activate 2>/dev/null || python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt -q
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
BASH

cat > scripts/run-meterpi.sh << 'BASH'
#!/bin/bash
# Start MeterPi (API only mode for testing)
cd /workspace/meterpi
source venv/bin/activate 2>/dev/null || python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt -q
python meterpi.py --api-only
BASH

cat > scripts/test-all.sh << 'BASH'
#!/bin/bash
# Run all tests
echo "Running API tests..."
cd /workspace/api && pytest -v

echo "Running MeterPi tests..."
cd /workspace/meterpi && pytest -v

echo "All tests complete!"
BASH

chmod +x scripts/*.sh

log "Automation scripts created"

# ============================================
# 6. Create Progress Tracking
# ============================================
log "Creating progress tracking..."

cat > progress.md << 'PROGRESS'
# MeterScience Progress Log

## Session: Initial Setup
**Date:** $(date +%Y-%m-%d)

### Completed
- [x] Project structure created
- [x] Docker environment configured
- [x] Database schema designed
- [x] API scaffolding complete
- [x] MeterPi base code ready
- [x] Landing page created

### In Progress
- [ ] iOS Views implementation
- [ ] API routes implementation
- [ ] MeterPi OCR integration

### Blocked
- None

### Notes
- Ready for Claude Code autonomous development
- All infrastructure in place

---
PROGRESS

log "Progress tracking created"

# ============================================
# 7. Initialize Git
# ============================================
log "Initializing git repository..."

git add -A
git commit -m "Initial MeterScience project setup

- iOS app structure with SwiftUI
- MeterPi Raspberry Pi software  
- FastAPI backend
- PostgreSQL schema with PostGIS
- Docker development environment
- Landing page

Ready for autonomous Claude Code development."

log "Git repository initialized"

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Project structure:"
tree -L 2 -d "$WORKSPACE" 2>/dev/null || find "$WORKSPACE" -type d -maxdepth 2
echo ""
echo "Next steps:"
echo "  1. Start services:  docker-compose up -d"
echo "  2. Enter sandbox:   docker exec -it meterscience-dev bash"
echo "  3. Run API:         ./scripts/run-api.sh"
echo "  4. Run tests:       ./scripts/test-all.sh"
echo ""
echo "For Claude Code:"
echo "  cd /workspace && claude"
echo "  @CLAUDE.md @prompt_plan.md @progress.md"
echo ""
