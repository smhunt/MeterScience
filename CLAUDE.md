# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MeterScience is a citizen science platform for crowdsourced utility meter reading. The platform consists of:
- **iOS app** - SwiftUI app with Vision framework OCR for scanning utility meters
- **Backend API** - FastAPI Python backend with PostgreSQL + PostGIS
- **MeterPi** - Raspberry Pi hardware kit for automated meter reading
- **Web** - Marketing site (planned)

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    iOS App      │────▶│   FastAPI       │────▶│  PostgreSQL     │
│  (SwiftUI +     │     │   Backend       │     │  + PostGIS      │
│   Vision OCR)   │     │   /api/v1/*     │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
┌─────────────────┐            │
│    MeterPi      │────────────┘
│  (Raspberry Pi) │   Cloud sync (optional)
│  Flask local API│
└─────────────────┘
```

**Key architectural decisions:**
1. Local-first - iOS app works offline, syncs when connected
2. Privacy by design - Minimum 5 homes before showing aggregates
3. Multi-frame OCR consensus - MeterPi requires 3 matching frames
4. Gamification core - XP, streaks, badges drive engagement

## Development Commands

### API (FastAPI Backend)
```bash
cd api
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Run tests
pytest -v

# Code formatting
black src/ && isort src/
```

### MeterPi (Raspberry Pi Software)
```bash
cd meterpi
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# API-only mode (no camera)
python meterpi.py --api-only

# Capture-only mode (no API server)
python meterpi.py --capture-only

# Full mode (both)
python meterpi.py

# Run tests
pytest -v
```

### iOS App
```bash
# Open in Xcode (requires Xcode 15+)
open ios/MeterScience.xcodeproj

# Run tests
xcodebuild test -scheme MeterScience -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Docker (Full Stack)
```bash
# Start all services (postgres, redis, minio, adminer)
docker-compose up -d

# Enter dev sandbox
docker exec -it meterscience-dev bash

# With Stripe webhook testing
docker-compose --profile stripe up -d
```

## API Endpoints

The FastAPI backend at `/api/v1/` includes:
- `/users` - User management and auth
- `/meters` - Meter configuration
- `/readings` - Submit and retrieve meter readings
- `/campaigns` - Neighborhood campaign coordination
- `/verify` - Community verification votes
- `/stats` - Aggregated statistics
- `/webhooks` - Enterprise webhook configuration

## Project Structure

```
ios/MeterScience/
├── Models/Models.swift    # All data models (UserProfile, MeterConfig, MeterReading, etc.)
├── Views/                 # SwiftUI views
└── Services/             # Business logic

api/src/
├── main.py               # FastAPI app entry, routes registration
├── database.py           # SQLAlchemy async setup
├── models.py             # Pydantic/SQLAlchemy models
├── routes/               # API route handlers
│   ├── readings.py
│   ├── users.py
│   ├── meters.py
│   ├── campaigns.py
│   ├── verify.py
│   ├── stats.py
│   └── webhooks.py
└── services/
    └── auth.py           # JWT authentication

meterpi/
├── meterpi.py            # Main application (OCR, capture, Flask API, MQTT)
├── homeassistant.yaml    # Home Assistant integration config
├── install.sh            # Raspberry Pi setup script
└── requirements.txt
```

## Data Models (iOS)

Key models in `ios/MeterScience/Models/Models.swift`:
- `UserProfile` - User with XP, badges, streaks, subscription tier
- `MeterConfig` - Meter setup with learned OCR parameters
- `MeterReading` - Reading with confidence, verification status
- `VerificationTask` - Community verification queue item
- `Campaign` - Neighborhood coordination
- `SubscriptionTier` - free/neighbor/block/district tiers

## MeterPi Configuration

Config file at `/home/pi/meterpi/config.json`:
```json
{
  "capture_interval_seconds": 60,
  "expected_digits": 6,
  "min_confidence": 0.7,
  "consensus_frames": 3,
  "mqtt_enabled": false,
  "mqtt_broker": "localhost",
  "cloud_sync_enabled": false
}
```

MeterPi local API runs on port 5000:
- `GET /api/v1/readings/latest` - Most recent reading
- `GET /api/v1/readings?from=&to=` - Date range query
- `GET /api/v1/stats` - Aggregate statistics
- `GET /ws/readings` - SSE live stream

## Business Logic

**Subscription tiers:**
| Tier | Price | Data Access |
|------|-------|-------------|
| Free | $0 | Your data only |
| Neighbor | $2.99/mo | Same postal code |
| Block | $4.99/mo | 5km radius |
| District | $9.99/mo | 25km radius + API |

**Referral rewards:**
- 1 referral = 1 month Neighbor free
- 5 referrals = 25% off forever
- 10 referrals = Block tier for life
- 25 referrals = District tier for life

## Environment Variables

Required for API:
```
DATABASE_URL=postgresql://meterscience:meterscience@localhost:5432/meterscience
REDIS_URL=redis://localhost:6379
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Code Style

### Python
- Type hints everywhere
- Pydantic for validation
- Black + isort formatting
- Pytest for testing

### Swift
- SwiftUI declarative patterns
- MVVM with ObservableObject
- Async/await for concurrency

## Git Workflow

**IMPORTANT: Always use feature branches for changes.**

### Standard Workflow
```bash
# 1. Create feature branch BEFORE making changes
git checkout -b feature/descriptive-name

# 2. Make changes and commit
git add . && git commit -m "Description of changes"

# 3. Push branch and create PR
git push -u origin feature/descriptive-name
gh pr create --title "Title" --body "Description with testing instructions"

# 4. Wait for user to test and approve

# 5. Merge when approved
gh pr merge --squash
```

### Branch Naming
- `feature/` - New features (e.g., `feature/camera-integration`)
- `fix/` - Bug fixes (e.g., `fix/login-error`)
- `refactor/` - Code refactoring (e.g., `refactor/api-service`)
- `docs/` - Documentation only (e.g., `docs/api-reference`)

### PR Requirements
Every PR must include:
1. **Summary** - What changed and why
2. **Testing Instructions** - Step-by-step guide to verify changes
3. **Checklist** - Checkboxes for each test scenario

### Rules
- NEVER commit directly to `master` without a PR
- ALWAYS create feature branch first, then make changes
- ALWAYS include testing instructions in PR body
- Wait for user approval before merging

## Planning Files

- `prompt_plan.md` - Current sprint tasks
- `progress.md` - Completed work log
- `docs/PRODUCT_VISION.md` - Full product ecosystem and roadmap
- `docs/architecture-diagram.drawio` - System architecture diagram
