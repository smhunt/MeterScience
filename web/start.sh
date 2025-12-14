#!/bin/bash

# MeterScience Landing Page - Dev Server Startup Script

echo "Starting MeterScience landing page..."
echo "LAN URL: http://10.10.10.24:3011"
echo ""

# Navigate to web directory
cd "$(dirname "$0")"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Start the dev server
echo "Starting Next.js dev server on port 3011..."
npm run dev
