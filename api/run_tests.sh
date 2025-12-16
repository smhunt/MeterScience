#!/bin/bash
# Test runner script for MeterScience API

cd "$(dirname "$0")"

echo "Running MeterScience API Tests"
echo "==============================="
echo ""

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Run pytest with coverage
python -m pytest -v --cov=src --cov-report=term-missing --cov-report=html

echo ""
echo "Coverage report generated in htmlcov/index.html"
