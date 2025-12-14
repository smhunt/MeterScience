# 🔬 MeterScience

**Citizen Science Utility Monitoring Platform**

> Scan your meters, track your usage, unlock neighborhood insights. Your data is always free.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![iOS](https://img.shields.io/badge/iOS-17%2B-black.svg)](ios/)
[![API](https://img.shields.io/badge/API-FastAPI-009688.svg)](api/)

---

## 🌟 What is MeterScience?

MeterScience is a citizen science platform that turns everyday utility meter reading into valuable community data:

- **📱 iOS App** - AI-powered meter scanning using Apple Vision framework
- **🎮 Gamification** - XP, streaks, badges, and leaderboards
- **🏘️ Neighborhood Campaigns** - Coordinate readings with neighbors
- **✅ Community Verification** - Crowdsourced accuracy improvement
- **📊 Data Insights** - Compare usage with your area
- **🔌 MeterPi Hardware** - Raspberry Pi kit for automated readings

## 💡 Business Model

| Tier | Price | What You Get |
|------|-------|--------------|
| **Free** | $0 | Your own data, forever |
| **Neighbor** | $2.99/mo | Compare with your postal code |
| **Block** | $4.99/mo | 5km radius + create campaigns |
| **District** | $9.99/mo | 25km radius + full API access |

**Key insight:** Your data is always free. You pay for neighbor comparisons.

### Referral Rewards
- 1 referral → 1 month Neighbor free
- 5 referrals → 25% off forever
- 10 referrals → Block tier for life
- 25 referrals → District tier for life

---

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- (For iOS) macOS with Xcode 15+

### Development Environment

```bash
# Clone the repo
git clone https://github.com/yourusername/meterscience.git
cd meterscience

# Copy environment variables
cp .env.example .env

# Start all services
docker-compose up -d

# Enter development sandbox
docker exec -it meterscience-dev bash

# Run setup
./scripts/setup.sh
```

### Services

| Service | URL | Description |
|---------|-----|-------------|
| API | http://localhost:8000 | FastAPI backend |
| API Docs | http://localhost:8000/docs | Swagger UI |
| Database | localhost:5432 | PostgreSQL + PostGIS |
| Redis | localhost:6379 | Caching |
| MinIO | http://localhost:9001 | S3-compatible storage |
| Adminer | http://localhost:8081 | Database UI |

---

## 📁 Project Structure

```
meterscience/
├── ios/                    # iOS App (SwiftUI)
│   ├── MeterScience/
│   │   ├── Views/
│   │   ├── Models/
│   │   └── Services/
│   └── MeterScienceTests/
├── api/                    # Backend API (FastAPI)
│   ├── src/
│   │   ├── routes/
│   │   ├── services/
│   │   └── models/
│   └── tests/
├── meterpi/               # Raspberry Pi Software
│   ├── meterpi.py
│   ├── ocr_engine.py
│   └── install.sh
├── web/                   # Marketing Site
│   └── landing/
├── scripts/               # Automation
│   ├── setup.sh
│   ├── claude-executor.sh
│   └── init-db.sql
├── docker-compose.yml
├── Dockerfile
├── CLAUDE.md              # Claude Code context
└── prompt_plan.md         # Sprint planning
```

---

## 📱 iOS App

### Features
- Vision framework OCR for meter reading
- Real-time digit detection with confidence scoring
- Multi-frame consensus for accuracy
- Gamification (XP, levels, badges, streaks)
- Neighborhood campaigns
- Community verification
- Subscription management

### Building

```bash
# Requires macOS with Xcode 15+
cd ios
open MeterScience.xcodeproj
# Build and run on device (camera required)
```

---

## 🔌 MeterPi Hardware

Raspberry Pi kit for automated meter reading.

### Hardware (Basic Kit - $79)
- Raspberry Pi Zero 2 W
- Camera Module v2
- 3D-printed mount
- Pre-flashed SD card

### Features
- 1-minute reading intervals
- On-device OCR (no cloud dependency)
- Local REST API
- MQTT for Home Assistant
- Optional cloud sync

### Quick Setup

```bash
# On Raspberry Pi
curl -sSL https://meterscience.io/install.sh | bash

# Configure
nano /home/pi/meterpi/config.json

# Start
sudo systemctl start meterpi

# Test
curl http://localhost:5000/api/v1/readings/latest
```

---

## 🔒 API

### Authentication
```bash
# Get token
curl -X POST https://api.meterscience.io/v1/auth/token \
  -d '{"email": "you@example.com", "password": "..."}'

# Use token
curl https://api.meterscience.io/v1/readings \
  -H "Authorization: Bearer <token>"
```

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /readings | Submit a reading |
| GET | /readings | List readings |
| GET | /readings/stats | Aggregated stats |
| POST | /verify | Submit verification vote |
| GET | /campaigns | List campaigns |
| POST | /campaigns | Create campaign |

### Webhooks (District tier)
```bash
POST /webhooks
{
  "url": "https://your-server.com/webhook",
  "events": ["reading.created", "reading.verified"]
}
```

---

## 🧪 Testing

```bash
# All tests
./scripts/test-all.sh

# API tests
cd api && pytest -v

# MeterPi tests  
cd meterpi && pytest -v

# iOS tests (requires Xcode)
xcodebuild test -scheme MeterScience
```

---

## 🤖 Claude Code Integration

This project is optimized for autonomous development with Claude Code.

```bash
# Start Claude Code session
cd /workspace
claude

# Load context
@CLAUDE.md @prompt_plan.md @progress.md

# Claude will understand:
# - Project structure and architecture
# - Current sprint tasks
# - Code style preferences
# - What's been completed
```

---

## 📊 Data & Privacy

### Your Data
- Always exportable (JSON, CSV)
- Delete anytime
- Never sold individually

### Neighbor Data
- Anonymized (no names/addresses)
- Minimum 5 homes before showing stats
- Aggregated only (no individual readings)

### Enterprise Data
- Further anonymized
- Postal code level only
- Opt-out available

---

## 🗺️ Roadmap

### Phase 1: MVP (Current)
- [x] iOS app with Vision OCR
- [x] Basic gamification
- [ ] TestFlight beta

### Phase 2: Community
- [ ] Neighborhood campaigns
- [ ] Community verification
- [ ] Leaderboards

### Phase 3: Hardware
- [ ] MeterPi kit
- [ ] Home Assistant integration
- [ ] Production manufacturing

### Phase 4: Enterprise
- [ ] Utility data products
- [ ] API for researchers
- [ ] White-label options

---

## 🤝 Contributing

1. Fork the repo
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing`)
5. Open Pull Request

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

---

## 👋 Contact

**EcoWorks Web Architecture Inc.**
- Web: [meterscience.io](https://meterscience.io)
- Email: hello@meterscience.io
- Twitter: [@MeterScience](https://twitter.com/MeterScience)

---

*Built with ❤️ for citizen scientists everywhere*
