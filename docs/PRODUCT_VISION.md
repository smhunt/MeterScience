# MeterScience: Complete Product Ecosystem

## Vision
Democratize utility data collection through citizen science, creating the world's largest independent utility consumption dataset while giving consumers unprecedented insight into their usage.

---

## Product Tiers

### 1. FREE: MeterScience App (iOS/Android)
**Target:** Anyone with a utility meter
**Value Prop:** "Scan your meters, earn rewards, help science"

Features:
- Manual meter scanning with Vision AI
- Gamification (streaks, XP, badges, leaderboards)
- Neighborhood campaigns & coordination
- Community verification for accuracy
- Basic usage tracking & trends
- Data contribution to research

Revenue: None (growth engine)

---

### 2. PRO: MeterScience+ Subscription ($4.99/mo)
**Target:** Energy-conscious homeowners, landlords
**Value Prop:** "Know exactly what you're paying for"

Features:
- Everything in Free, plus:
- Unlimited meter history & export
- Bill prediction & anomaly alerts
- Usage comparisons (vs neighbors, region)
- Time-of-use optimization suggestions
- Priority verification queue
- API access for home automation

Revenue: Subscription

---

### 3. HARDWARE: MeterPi Kit ($79-149)
**Target:** Enthusiasts, landlords, small businesses
**Value Prop:** "Set it and forget it - automatic readings every minute"

#### MeterPi Basic ($79)
- Raspberry Pi Zero 2 W
- Wide-angle camera module
- 3D-printed meter mount (universal)
- Pre-flashed SD card
- USB-C power adapter
- Quick-start guide

#### MeterPi Pro ($149)
- Raspberry Pi 4 (2GB)
- IR-illuminated camera (night reading)
- Weatherproof enclosure (outdoor meters)
- PoE adapter option
- Local SQLite + cloud sync
- MQTT/Home Assistant integration
- Solar power option add-on ($49)

Hardware Features:
- 1-minute reading intervals (configurable)
- On-device OCR (no cloud dependency)
- Local REST API for queries
- Automatic cloud sync when online
- Edge anomaly detection
- OTA firmware updates

Revenue: Hardware margin + optional cloud subscription

---

### 4. ENTERPRISE: MeterScience for Utilities
**Target:** Utility companies, municipalities, researchers
**Value Prop:** "Consumer-collected data you can't get any other way"

Data Products:
- Anonymized consumption patterns by region
- Peak usage correlation data
- Billing verification datasets
- Grid stress indicators
- Conservation program effectiveness
- Smart meter deployment prioritization

Delivery:
- REST API with OAuth2
- Webhook events (anomalies, thresholds)
- Bulk data exports (JSON, CSV, Parquet)
- Grafana/dashboard integration
- Custom data pipelines

Pricing:
- Per-meter-per-month for ongoing access
- Per-query for research datasets
- Custom contracts for exclusivity

---

## Hardware Technical Spec: MeterPi

### Bill of Materials (Basic Kit)

| Component | Cost | Source |
|-----------|------|--------|
| Raspberry Pi Zero 2 W | $15 | RPi Foundation |
| Camera Module v2 | $25 | RPi Foundation |
| 16GB SD Card | $8 | Amazon |
| USB-C Power Supply | $10 | Amazon |
| 3D Printed Mount | $5 | In-house |
| Packaging/Manual | $3 | In-house |
| **Total BOM** | **$66** | |
| **Retail Price** | **$79** | |
| **Margin** | **16%** | |

### Software Stack

```
┌─────────────────────────────────────────┐
│           MeterPi Device                │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │     Camera Capture (Python)     │    │
│  │   - OpenCV frame capture        │    │
│  │   - Auto-exposure adjustment    │    │
│  │   - IR LED control (Pro)        │    │
│  └──────────────┬──────────────────┘    │
│                 │                        │
│  ┌──────────────▼──────────────────┐    │
│  │    On-Device OCR (Tesseract)    │    │
│  │   - Digit extraction            │    │
│  │   - Confidence scoring          │    │
│  │   - Multi-frame consensus       │    │
│  └──────────────┬──────────────────┘    │
│                 │                        │
│  ┌──────────────▼──────────────────┐    │
│  │     Local Storage (SQLite)      │    │
│  │   - Full reading history        │    │
│  │   - Configurable retention      │    │
│  │   - Query API                   │    │
│  └──────────────┬──────────────────┘    │
│                 │                        │
│  ┌──────────────▼──────────────────┐    │
│  │      Local REST API (Flask)     │    │
│  │   - GET /readings               │    │
│  │   - GET /readings/latest        │    │
│  │   - GET /readings/range         │    │
│  │   - GET /stats                  │    │
│  │   - WebSocket live stream       │    │
│  └──────────────┬──────────────────┘    │
│                 │                        │
│  ┌──────────────▼──────────────────┐    │
│  │     Cloud Sync (Optional)       │    │
│  │   - Batched uploads             │    │
│  │   - Offline queue               │    │
│  │   - Webhook triggers            │    │
│  └─────────────────────────────────┘    │
│                                          │
│  ┌─────────────────────────────────┐    │
│  │   Home Automation Integration   │    │
│  │   - MQTT publish                │    │
│  │   - Home Assistant discovery    │    │
│  │   - Node-RED compatible         │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Local API Examples

```bash
# Get latest reading
curl http://meterpi.local:5000/api/v1/readings/latest

{
  "reading_id": "abc123",
  "value": "45892",
  "numeric": 45892,
  "confidence": 0.97,
  "timestamp": "2024-01-15T14:32:00Z",
  "image_hash": "sha256:...",
  "processing_ms": 145
}

# Get readings for date range
curl "http://meterpi.local:5000/api/v1/readings?from=2024-01-01&to=2024-01-15"

# Get usage statistics
curl http://meterpi.local:5000/api/v1/stats

{
  "total_readings": 12847,
  "first_reading": "2023-06-01T00:00:00Z",
  "latest_reading": "2024-01-15T14:32:00Z",
  "average_daily_usage": 28.5,
  "current_month_usage": 412,
  "previous_month_usage": 398,
  "trend": "up",
  "trend_percent": 3.5
}

# WebSocket for live updates
wscat -c ws://meterpi.local:5000/ws/readings
```

### Home Assistant Integration

```yaml
# configuration.yaml
sensor:
  - platform: rest
    name: Electric Meter
    resource: http://meterpi.local:5000/api/v1/readings/latest
    value_template: "{{ value_json.numeric }}"
    unit_of_measurement: "kWh"
    scan_interval: 60
    
  - platform: rest
    name: Electric Daily Usage
    resource: http://meterpi.local:5000/api/v1/stats
    value_template: "{{ value_json.average_daily_usage }}"
    unit_of_measurement: "kWh/day"
    scan_interval: 3600
```

---

## Data Product API

### Authentication
```bash
curl -X POST https://api.meterscience.io/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"api_key": "your_api_key", "api_secret": "your_secret"}'
```

### Endpoints

#### Get Regional Consumption Patterns
```bash
GET /v1/data/consumption/patterns
  ?region=CA-ON          # ISO region code
  &meter_type=electric
  &granularity=hourly
  &from=2024-01-01
  &to=2024-01-31
```

#### Get Anonymized Readings Stream
```bash
GET /v1/data/readings/stream
  ?postal_prefix=N6A     # First 3 chars only (privacy)
  &meter_type=electric
  &verified_only=true
  
# Returns Server-Sent Events
data: {"ts":"2024-01-15T14:32:00Z","value":45892,"confidence":0.97}
data: {"ts":"2024-01-15T14:33:00Z","value":45893,"confidence":0.98}
```

#### Get Aggregate Statistics
```bash
GET /v1/data/stats/aggregate
  ?region=CA-ON
  &meter_type=electric
  &period=monthly
  
{
  "region": "CA-ON",
  "meter_type": "electric",
  "period": "2024-01",
  "meter_count": 12453,
  "reading_count": 847291,
  "avg_daily_consumption": 28.5,
  "median_daily_consumption": 24.2,
  "p90_daily_consumption": 52.1,
  "peak_hour": 18,
  "off_peak_avg": 1.2,
  "peak_avg": 3.8
}
```

#### Webhook Configuration
```bash
POST /v1/webhooks
{
  "url": "https://your-system.com/webhook",
  "events": ["reading.anomaly", "regional.peak"],
  "filters": {
    "region": "CA-ON",
    "meter_type": "electric"
  }
}
```

---

## Go-To-Market Strategy

### Phase 1: App Launch (Months 1-3)
- Launch iOS app in Canada
- Seed with beta users in London, ON area
- Focus on gamification and virality
- Target: 1,000 active users, 10,000 readings

### Phase 2: Community Building (Months 4-6)
- Launch Android app
- Neighborhood campaign features
- Referral program with rewards
- Partner with energy conservation groups
- Target: 10,000 users, 100,000 readings

### Phase 3: Hardware Beta (Months 7-9)
- Ship MeterPi kits to enthusiast users
- Gather feedback, iterate on design
- Build Home Assistant community presence
- Target: 500 hardware units

### Phase 4: Enterprise Pilot (Months 10-12)
- Approach 2-3 utilities with data samples
- Offer free pilot program
- Validate data product value prop
- Target: 2 signed enterprise contracts

### Phase 5: Scale (Year 2)
- Expand to US markets
- Mass hardware production
- Enterprise sales team
- Series A fundraise

---

## Revenue Projections

### Year 1
| Stream | Units | Price | Revenue |
|--------|-------|-------|---------|
| Pro Subscriptions | 500 | $60/yr | $30,000 |
| MeterPi Basic | 300 | $79 | $23,700 |
| MeterPi Pro | 200 | $149 | $29,800 |
| **Total** | | | **$83,500** |

### Year 2
| Stream | Units | Price | Revenue |
|--------|-------|-------|---------|
| Pro Subscriptions | 5,000 | $60/yr | $300,000 |
| MeterPi Basic | 3,000 | $79 | $237,000 |
| MeterPi Pro | 1,500 | $149 | $223,500 |
| Enterprise Contracts | 3 | $50,000/yr | $150,000 |
| **Total** | | | **$910,500** |

### Year 3
| Stream | Units | Price | Revenue |
|--------|-------|-------|---------|
| Pro Subscriptions | 25,000 | $60/yr | $1,500,000 |
| Hardware (mixed) | 15,000 | $100 avg | $1,500,000 |
| Enterprise | 10 | $100,000/yr | $1,000,000 |
| **Total** | | | **$4,000,000** |

---

## Competitive Advantages

1. **Network Effects**: More users = better verification = more accurate data = more valuable to utilities

2. **Hardware Lock-in**: MeterPi users are sticky subscribers

3. **Unique Dataset**: No one else has crowd-sourced, verified, high-frequency meter data

4. **Local-First**: Works offline, respects privacy, appeals to technical users

5. **Citizen Science Framing**: Intrinsic motivation beyond money

6. **Tucows Relationship**: Leverage existing registrar infrastructure for domain/hosting bundle

---

## Integration with EcoWorks Portfolio

- **Domain Commerce MCP**: Bundle meterscience.com, meterpi.io domains
- **Handled.ca**: Appointment booking for MeterPi installation service
- **WordPress Clients**: Offer MeterPi to healthcare facilities for utility monitoring

---

## Next Steps

1. Finish iOS MVP with gamification
2. Build MeterPi prototype on Raspberry Pi
3. Create landing page for waitlist
4. Write Home Assistant integration
5. Approach London Hydro for data partnership conversation
