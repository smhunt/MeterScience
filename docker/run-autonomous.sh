#!/bin/bash
# MeterScience - Autonomous Claude Code Execution
# This script sets up and runs the entire project build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "  MeterScience Autonomous Build System"
echo "=============================================="
echo ""

# Check for API key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "ERROR: ANTHROPIC_API_KEY not set"
    echo "Export your API key: export ANTHROPIC_API_KEY=your-key"
    exit 1
fi

# Create .env file
cat > "$PROJECT_ROOT/.env" << EOF
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/meterscience
REDIS_URL=redis://localhost:6379
STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY:-sk_test_placeholder}
STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET:-whsec_placeholder}
EOF

echo "[1/6] Building Docker images..."
cd "$PROJECT_ROOT/docker"
docker-compose build

echo ""
echo "[2/6] Starting infrastructure services..."
docker-compose up -d db redis minio
sleep 5

echo ""
echo "[3/6] Waiting for database..."
until docker-compose exec -T db pg_isready -U postgres; do
    sleep 1
done

echo ""
echo "[4/6] Starting development sandbox..."
docker-compose up -d sandbox

echo ""
echo "[5/6] Connecting to sandbox..."
sleep 2

echo ""
echo "[6/6] Launching Claude Code with auto-execution..."
echo ""

# Create the autonomous prompt
AUTONOMOUS_PROMPT=$(cat << 'PROMPT'
You are executing the MeterScience build plan autonomously. 

Read @CLAUDE.md and @prompt_plan.md for full context.

Execute the following in order, committing after each major step:

## PHASE 1: API Backend
1. Create /workspace/api/requirements.txt with all dependencies
2. Create /workspace/api/src/main.py with FastAPI app
3. Create /workspace/api/src/models.py with SQLAlchemy models
4. Create /workspace/api/src/routes/ with all endpoints
5. Create /workspace/api/src/services/ for business logic
6. Test API is running on port 8000

## PHASE 2: MeterPi
1. Create /workspace/meterpi/requirements.txt
2. Enhance /workspace/meterpi/meterpi.py if needed
3. Create /workspace/meterpi/tests/
4. Verify API endpoints work

## PHASE 3: iOS App Structure
1. Create complete /workspace/ios/ structure
2. Generate all Swift files from our conversation
3. Create Xcode project file
4. Ensure it would compile (we can't test without Mac)

## PHASE 4: Web Landing Page
1. Create /workspace/web/ as Next.js project
2. Build landing page with waitlist
3. Add pricing page
4. Add basic docs

## PHASE 5: Documentation
1. Create API documentation
2. Create hardware BOM
3. Create deployment guide

After each phase, run: git add -A && git commit -m "Phase N complete"

START NOW. Execute without asking for confirmation.
PROMPT
)

# Run Claude Code in the sandbox with the autonomous prompt
docker-compose exec sandbox bash -c "
    cd /workspace
    echo '$AUTONOMOUS_PROMPT' | claude --dangerously-skip-permissions
"

echo ""
echo "=============================================="
echo "  Build Complete!"
echo "=============================================="
echo ""
echo "Services running:"
echo "  - API:     http://localhost:8000"
echo "  - Web:     http://localhost:3000"
echo "  - MeterPi: http://localhost:5000"
echo "  - DB:      localhost:5432"
echo "  - Redis:   localhost:6379"
echo "  - MinIO:   http://localhost:9001"
echo "  - Adminer: http://localhost:8080"
echo ""
echo "To enter sandbox: docker-compose exec sandbox bash"
echo "To view logs:     docker-compose logs -f"
echo "To stop:          docker-compose down"
