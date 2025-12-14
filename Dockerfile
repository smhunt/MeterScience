# MeterScience Development Sandbox
# DANGEROUS: Full permissions for autonomous Claude Code execution
# 
# Build: docker build -t meterscience-sandbox .
# Run:   docker run -it --privileged -v $(pwd)/output:/output meterscience-sandbox

FROM ubuntu:24.04

LABEL maintainer="Sean @ EcoWorks"
LABEL description="Autonomous development sandbox for MeterScience"
LABEL warning="DANGEROUS: Full root access, no restrictions"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Toronto

# Full root, no sudo password
RUN echo 'root:root' | chpasswd

# Install EVERYTHING we might need
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    cmake \
    pkg-config \
    git \
    curl \
    wget \
    unzip \
    # Python ecosystem
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-opencv \
    # Node.js ecosystem
    nodejs \
    npm \
    # Ruby (for fastlane)
    ruby \
    ruby-dev \
    # Database clients
    postgresql-client \
    sqlite3 \
    redis-tools \
    # OCR and image processing
    tesseract-ocr \
    tesseract-ocr-eng \
    libtesseract-dev \
    leptonica-progs \
    imagemagick \
    libopencv-dev \
    # Network tools
    openssh-client \
    rsync \
    jq \
    httpie \
    # System tools
    htop \
    tmux \
    vim \
    nano \
    tree \
    zip \
    # For iOS tooling
    libimobiledevice-utils \
    ideviceinstaller \
    # Misc
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install latest Node.js (v20 LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest

# Install global Node packages
RUN npm install -g \
    typescript \
    ts-node \
    @swc/core \
    @swc/cli \
    prettier \
    eslint \
    vercel \
    railway \
    wrangler

# Install Python packages globally (break system packages - we're dangerous)
RUN pip3 install --break-system-packages \
    # Web frameworks
    fastapi \
    uvicorn[standard] \
    flask \
    flask-cors \
    # Database
    sqlalchemy \
    psycopg2-binary \
    redis \
    # Data processing
    pandas \
    numpy \
    pillow \
    opencv-python-headless \
    # OCR
    pytesseract \
    paddlepaddle \
    paddleocr \
    # API clients
    httpx \
    requests \
    aiohttp \
    # Dev tools
    black \
    isort \
    pytest \
    pytest-asyncio \
    mypy \
    ruff \
    # Utilities
    python-dotenv \
    pydantic \
    pydantic-settings \
    paho-mqtt \
    stripe \
    boto3 \
    # AI/ML
    anthropic \
    openai

# Install Ruby gems for fastlane
RUN gem install fastlane

# Install Rust (for some tooling)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Go (for some tooling)
RUN wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz \
    && rm go1.22.0.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Create project structure
WORKDIR /workspace
RUN mkdir -p \
    /workspace/ios \
    /workspace/meterpi \
    /workspace/api \
    /workspace/web \
    /workspace/docs \
    /workspace/scripts \
    /workspace/.claude \
    /output

# Set up Git
RUN git config --global user.email "claude@meterscience.local" \
    && git config --global user.name "Claude Code" \
    && git config --global init.defaultBranch main

# Initialize git repo
RUN cd /workspace && git init

# Environment variables for development
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV NODE_ENV=development
ENV ANTHROPIC_API_KEY=""
ENV DATABASE_URL="sqlite:///./meterscience.db"
ENV REDIS_URL="redis://localhost:6379"
ENV STRIPE_SECRET_KEY=""
ENV STRIPE_WEBHOOK_SECRET=""

# Expose ports
EXPOSE 3000 5000 8000 8080

# Create entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "  MeterScience Development Sandbox"
echo "  DANGEROUS: Full permissions enabled"
echo "=========================================="
echo ""
echo "Workspace: /workspace"
echo "Output:    /output"
echo ""
echo "Quick commands:"
echo "  ./scripts/setup.sh      - Initialize project"
echo "  ./scripts/build-ios.sh  - Build iOS app"
echo "  ./scripts/run-api.sh    - Start API server"
echo "  ./scripts/test-all.sh   - Run all tests"
echo ""

# Keep container running
exec "$@"
EOF
chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
