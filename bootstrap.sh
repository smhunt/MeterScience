#!/bin/bash
# MeterScience One-Liner Bootstrap
# 
# Run with:
#   curl -sSL https://raw.githubusercontent.com/yourrepo/meterscience/main/bootstrap.sh | bash
#
# Or locally:
#   ./bootstrap.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║          MeterScience Autonomous Bootstrap               ║"
echo "║     ⚠️  DANGEROUS MODE - Zero Restrictions ⚠️             ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Installing...${NC}"
    curl -fsSL https://get.docker.com | sh
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose not found. Installing...${NC}"
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi

# Create project directory
PROJECT_DIR="${HOME}/MeterScience"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo -e "${GREEN}[1/4] Building dangerous Docker image...${NC}"

# Create Dockerfile inline if not exists
if [ ! -f "Dockerfile.dangerous" ]; then
    echo "Downloading Dockerfile.dangerous..."
    # In real deployment, this would download from repo
    # For now, we create a minimal version
    cat > Dockerfile.dangerous << 'DOCKERFILE'
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential git curl wget python3 python3-pip python3-venv \
    nodejs npm postgresql-client sqlite3 redis-tools \
    tesseract-ocr python3-opencv vim tmux jq \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages \
    fastapi uvicorn sqlalchemy psycopg2-binary redis \
    pydantic flask flask-cors pytesseract opencv-python-headless \
    httpx requests anthropic pytest black
WORKDIR /workspace
CMD ["/bin/bash"]
DOCKERFILE
fi

docker build -t meterscience-dangerous -f Dockerfile.dangerous .

echo -e "${GREEN}[2/4] Starting container...${NC}"

# Stop existing if running
docker rm -f meterscience-dev 2>/dev/null || true

# Run with ALL permissions
docker run -d \
    --name meterscience-dev \
    --privileged \
    --net=host \
    -v "${PROJECT_DIR}:/workspace" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
    meterscience-dangerous \
    tail -f /dev/null

echo -e "${GREEN}[3/4] Executing autonomous build...${NC}"

# Run the auto-execute script inside container
docker exec meterscience-dev bash -c '
cd /workspace

# Create and run the build
mkdir -p scripts
cat > scripts/build-all.sh << "BUILD"
#!/bin/bash
set -e
echo "Building MeterScience..."

# Create directories
mkdir -p ios/MeterScience/{Models,Views,Services}
mkdir -p api/src/{routes,services}
mkdir -p meterpi web/landing docs

# API
cat > api/src/main.py << "PY"
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="MeterScience API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.get("/")
def root():
    return {"message": "MeterScience API", "status": "ready"}

@app.get("/health")
def health():
    return {"status": "healthy"}
PY

# MeterPi
cat > meterpi/meterpi.py << "PY"
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route("/api/v1/health")
def health():
    return jsonify({"status": "healthy", "device": "meterpi"})

@app.route("/api/v1/readings/latest")
def latest():
    return jsonify({"value": "12345", "confidence": 0.95})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
PY

# Landing page
cat > web/landing/index.html << "HTML"
<!DOCTYPE html>
<html>
<head>
    <title>MeterScience</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 min-h-screen flex items-center justify-center">
    <div class="text-center">
        <h1 class="text-5xl font-bold text-green-600 mb-4">⚡ MeterScience</h1>
        <p class="text-xl text-gray-600 mb-8">Citizen Science Utility Monitoring</p>
        <a href="#" class="bg-green-600 text-white px-8 py-4 rounded-lg text-lg">Join Waitlist</a>
    </div>
</body>
</html>
HTML

echo "Build complete!"
BUILD

chmod +x scripts/build-all.sh
./scripts/build-all.sh
'

echo -e "${GREEN}[4/4] Done!${NC}"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   BUILD COMPLETE!                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Enter the sandbox:${NC}"
echo "  docker exec -it meterscience-dev bash"
echo ""
echo -e "${GREEN}Start API:${NC}"
echo "  docker exec meterscience-dev uvicorn api.src.main:app --host 0.0.0.0 --port 8000"
echo ""
echo -e "${GREEN}Start MeterPi:${NC}"
echo "  docker exec meterscience-dev python meterpi/meterpi.py"
echo ""
echo -e "${GREEN}Project location:${NC} ${PROJECT_DIR}"
echo ""
echo -e "${YELLOW}⚠️  This container has ZERO security restrictions!${NC}"
echo ""
