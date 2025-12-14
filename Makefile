# MeterScience Makefile
# Dangerous autonomous development commands

.PHONY: all build run shell auto clean nuke

# Default: build and run
all: build run

# Build the dangerous Docker image
build:
	@echo "🔨 Building dangerous Docker image..."
	docker build -t meterscience-dangerous -f Dockerfile.dangerous .

# Run the container
run:
	@echo "🚀 Starting dangerous container..."
	docker rm -f meterscience-dev 2>/dev/null || true
	docker run -d \
		--name meterscience-dev \
		--privileged \
		--net=host \
		-v $(PWD):/workspace \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e ANTHROPIC_API_KEY=$(ANTHROPIC_API_KEY) \
		meterscience-dangerous \
		tail -f /dev/null
	@echo "✅ Container running. Use 'make shell' to enter."

# Enter the container
shell:
	@echo "🐚 Entering dangerous sandbox..."
	docker exec -it meterscience-dev bash

# Auto-execute full build
auto:
	@echo "🤖 Running autonomous build..."
	docker exec meterscience-dev /workspace/scripts/auto-execute.sh

# Start all services
services:
	@echo "📡 Starting services..."
	docker exec -d meterscience-dev uvicorn api.src.main:app --host 0.0.0.0 --port 8000
	docker exec -d meterscience-dev python meterpi/meterpi.py
	@echo "✅ API: http://localhost:8000"
	@echo "✅ MeterPi: http://localhost:5000"

# Run API only
api:
	docker exec -it meterscience-dev uvicorn api.src.main:app --host 0.0.0.0 --port 8000 --reload

# Run MeterPi only
meterpi:
	docker exec -it meterscience-dev python meterpi/meterpi.py

# Run tests
test:
	docker exec meterscience-dev pytest -v

# Format code
fmt:
	docker exec meterscience-dev black api/ meterpi/
	docker exec meterscience-dev isort api/ meterpi/

# Clean up container
clean:
	@echo "🧹 Cleaning up..."
	docker rm -f meterscience-dev 2>/dev/null || true

# Nuclear option - remove everything
nuke: clean
	@echo "☢️  Nuking everything..."
	docker rmi meterscience-dangerous 2>/dev/null || true
	rm -rf __pycache__ .pytest_cache .mypy_cache
	find . -name "*.pyc" -delete

# Show status
status:
	@echo "📊 Container status:"
	@docker ps -a --filter name=meterscience-dev --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View logs
logs:
	docker exec meterscience-dev cat /workspace/.claude/build.log 2>/dev/null || echo "No logs yet"

# Help
help:
	@echo "MeterScience Makefile Commands:"
	@echo ""
	@echo "  make build    - Build Docker image"
	@echo "  make run      - Start container"
	@echo "  make shell    - Enter container shell"
	@echo "  make auto     - Run autonomous full build"
	@echo "  make services - Start API + MeterPi"
	@echo "  make api      - Run API server"
	@echo "  make meterpi  - Run MeterPi server"
	@echo "  make test     - Run tests"
	@echo "  make fmt      - Format code"
	@echo "  make clean    - Remove container"
	@echo "  make nuke     - Remove everything"
	@echo "  make status   - Show container status"
	@echo "  make logs     - View build logs"
	@echo ""
	@echo "Quick start:"
	@echo "  make build run auto services"
