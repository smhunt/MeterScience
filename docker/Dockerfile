# MeterScience Development Sandbox
# DANGEROUS: Full permissions for autonomous Claude Code execution
# Use only in isolated environments

FROM ubuntu:24.04

LABEL maintainer="EcoWorks Web Architecture Inc."
LABEL description="Full-permission sandbox for MeterScience development"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Toronto

# Core system packages
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    cmake \
    pkg-config \
    # Python
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    # Node.js
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    # Ruby (for fastlane/iOS tooling)
    ruby-full \
    # Git & version control
    git \
    git-lfs \
    # Database
    postgresql-client \
    sqlite3 \
    redis-tools \
    # OCR & Vision
    tesseract-ocr \
    tesseract-ocr-eng \
    libtesseract-dev \
    libleptonica-dev \
    # OpenCV dependencies
    libopencv-dev \
    python3-opencv \
    # Image processing
    imagemagick \
    libmagickwand-dev \
    # Network tools
    curl \
    wget \
    httpie \
    jq \
    # SSH & remote
    openssh-client \
    rsync \
    # Process management
    tmux \
    screen \
    supervisor \
    # Editors
    vim \
    nano \
    # Archive tools
    zip \
    unzip \
    p7zip-full \
    # Misc
    htop \
    tree \
    ripgrep \
    fd-find \
    bat \
    fzf \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (for some Python packages)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Python packages - EVERYTHING we might need
RUN pip3 install --break-system-packages \
    # Web frameworks
    fastapi \
    uvicorn[standard] \
    flask \
    flask-cors \
    starlette \
    # Database
    sqlalchemy \
    alembic \
    asyncpg \
    psycopg2-binary \
    redis \
    # HTTP clients
    httpx \
    aiohttp \
    requests \
    # Data processing
    pandas \
    numpy \
    scipy \
    # OCR
    pytesseract \
    paddleocr \
    paddlepaddle \
    # Image processing
    opencv-python-headless \
    pillow \
    # ML
    scikit-learn \
    torch \
    torchvision \
    # Validation
    pydantic \
    pydantic-settings \
    # Auth
    python-jose[cryptography] \
    passlib[bcrypt] \
    # Payments
    stripe \
    # MQTT
    paho-mqtt \
    # Testing
    pytest \
    pytest-asyncio \
    pytest-cov \
    httpx \
    # Code quality
    black \
    isort \
    ruff \
    mypy \
    # Utilities
    python-dotenv \
    click \
    rich \
    typer \
    # Async
    anyio \
    # API docs
    openapi-spec-validator

# Node.js global packages
RUN npm install -g \
    # Package managers
    yarn \
    pnpm \
    # Build tools
    typescript \
    esbuild \
    vite \
    # React/Next
    create-react-app \
    create-next-app \
    # Linting
    eslint \
    prettier \
    # iOS tools (react-native)
    react-native-cli \
    # API mocking
    json-server \
    # Documentation
    typedoc \
    # Utilities
    concurrently \
    nodemon \
    pm2

# Ruby gems (for iOS tooling)
RUN gem install \
    fastlane \
    cocoapods \
    xcpretty

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create workspace
WORKDIR /workspace

# Create project structure
RUN mkdir -p \
    /workspace/ios \
    /workspace/meterpi \
    /workspace/api \
    /workspace/web \
    /workspace/docs \
    /workspace/.claude

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV NODE_ENV=development
ENV PATH="/workspace/node_modules/.bin:${PATH}"

# Allow pip to install system-wide without warnings
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Git config (for commits)
RUN git config --global user.email "claude@meterscience.app" \
    && git config --global user.name "Claude Code" \
    && git config --global init.defaultBranch main

# SSH config for GitHub
RUN mkdir -p /root/.ssh \
    && ssh-keyscan github.com >> /root/.ssh/known_hosts

# Supervisor config for running multiple services
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose ports
# 3000 - React dev server
# 5000 - MeterPi API
# 8000 - FastAPI backend
# 5432 - PostgreSQL (if running locally)
# 6379 - Redis (if running locally)
EXPOSE 3000 5000 8000 5432 6379

# Entry point
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
