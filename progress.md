# MeterScience - Progress Log

## Session: Initial Project Setup
**Date:** 2024-12-13
**Duration:** ~2 hours

### Completed

#### Product Vision ✅
- [x] Complete product ecosystem documented
- [x] Freemium pricing model defined
- [x] Referral rewards ladder designed
- [x] Hardware (MeterPi) specs drafted
- [x] Enterprise data product API designed
- [x] Utility integration webhooks defined

#### Data Models ✅
- [x] User profile with gamification (XP, badges, streaks)
- [x] Meter configuration with learned OCR params
- [x] Full-context meter readings
- [x] Verification votes and tasks
- [x] Campaign/neighborhood coordination
- [x] API export payloads
- [x] Webhook events

#### iOS App (Partial) ✅
- [x] App.swift - Main entry + TabView
- [x] Models.swift - All data structures
- [x] DataStore.swift - Persistence + sync
- [x] Subscription.swift - Tiers + referrals
- [x] HomeView - Gamified dashboard
- [x] NeighborhoodView - Campaigns
- [x] VerifyView - Community validation
- [ ] CalibrationView - Meter teaching (started)
- [ ] SmartScanView - Live OCR (started)
- [ ] ProfileView - Stats/badges (started)
- [ ] SubscriptionView - Paywall (started)
- [ ] ReferralView - Invite system (started)

#### MeterPi Hardware ✅
- [x] meterpi.py - Full Python application
- [x] install.sh - Raspberry Pi setup
- [x] homeassistant.yaml - HA integration
- [x] Config structure defined

#### Infrastructure ✅
- [x] Dockerfile - Full dev sandbox
- [x] docker-compose.yml - Full stack
- [x] init.sql - PostgreSQL schema
- [x] supervisord.conf - Service management
- [x] entrypoint.sh - Container startup

#### Project Management ✅
- [x] CLAUDE.md - Master context file
- [x] prompt_plan.md - Sprint tasks
- [x] progress.md - This file
- [x] run-autonomous.sh - Auto execution

### In Progress
- [ ] Complete iOS Views
- [x] FastAPI backend ✅
- [ ] Landing page
- [ ] API documentation

### Blocked
- [ ] App Store developer account
- [ ] Stripe account setup
- [ ] Domain registration

### Key Decisions Made
1. Your data always free - neighbor data is premium
2. Gamification core to engagement
3. Local-first architecture
4. MeterPi as hardware upsell
5. Citizen science framing
6. 5-home minimum for privacy

### Next Session Goals
1. Complete all iOS Views
2. Build FastAPI backend
3. Create landing page
4. Test in Docker sandbox

---

## Session: FastAPI Backend Complete
**Date:** 2025-12-14

### Completed

#### FastAPI Backend ✅
All API endpoints fully implemented and tested:

- [x] **Users API** - Register, login, profile, referrals, leaderboard
- [x] **Meters API** - Full CRUD for meter configuration
- [x] **Readings API** - Submit readings, list, filter by meter
- [x] **Campaigns API** - Create, join, leave, leaderboard
- [x] **Verification API** - Queue, vote, status, history, leaderboard
- [x] **Stats API** - User stats, meter stats, platform stats, neighborhood (paid tier)
- [x] **Webhooks API** - Full CRUD, HMAC signing, test endpoint, secret rotation

#### Key Features Implemented
- JWT authentication with token refresh
- Gamification system (XP, levels, badges, streaks, trust scores)
- Community verification voting with consensus algorithm
- Subscription tier enforcement (free/neighbor/block/district)
- 10 webhook event types with HMAC-SHA256 signing
- Auto-disable webhooks after delivery failures

#### API Endpoints Summary
| Route | Endpoints |
|-------|-----------|
| `/api/v1/users` | register, login, me, referral, leaderboard |
| `/api/v1/meters` | CRUD + list |
| `/api/v1/readings` | CRUD + filter |
| `/api/v1/campaigns` | CRUD + join/leave + leaderboard |
| `/api/v1/verify` | queue, vote, status, history, leaderboard |
| `/api/v1/stats` | me, platform, meters, neighborhood |
| `/api/v1/webhooks` | CRUD + events + test + rotate-secret |

### API Running
- **URL:** http://10.10.10.24:3090
- **Docs:** http://10.10.10.24:3090/docs

### Git Commits
- `82f7831` Implement webhooks API endpoints
- `e1a779e` Implement full campaigns CRUD routes
- `a077af5` Implement community verification API endpoints
- `90dc64e` Implement comprehensive stats API endpoints
- `b68284f` Fix datetime timezone handling in readings routes
- `831c800` Implement meters CRUD API endpoints

### Next Steps
1. Complete iOS Views (CalibrationView, SmartScanView, ProfileView, etc.)
2. Create landing page / marketing site
3. Add OpenAPI documentation enhancements
4. Integration testing with iOS app

---

## Session: iOS Views + Landing Page
**Date:** 2025-12-14

### Completed

#### iOS App - Full View Implementation ✅
All major views now complete with live API integration:

- [x] **APIService.swift** - Full API client connecting to FastAPI backend
  - Async/await HTTP methods with JWT authentication
  - Request/response models for all endpoints
  - Error handling with typed APIError enum

- [x] **AuthManager.swift** - Authentication state management
  - Token storage in UserDefaults
  - Login, register, logout flows
  - User caching for offline access
  - LoginView included

- [x] **ProfileView.swift** - User profile with gamification
  - XP progress bar with level display
  - Stats grid (readings, verified, streak, trust score, etc.)
  - Badges section with horizontal scroll
  - Account actions (referrals, subscription, logout)

- [x] **ReferralView.swift** - Referral system
  - Display referral code with copy/share
  - Rewards ladder visualization (1/5/10/25 tiers)
  - Apply referral code form
  - ShareSheet UIKit integration

- [x] **SubscriptionView.swift** - StoreKit 2 paywall
  - Full StoreKit 2 integration (Products, Purchase, Restore)
  - Tier cards for Free/Neighbor/Block/District
  - Transaction listener for auto-updates
  - Loading overlay and error handling

- [x] **CalibrationView.swift** - Meter setup wizard
  - 4-step wizard flow with progress bar
  - Step 1: Meter type selection
  - Step 2: Name, postal code, digit count
  - Step 3: Sample reading input with visual digit boxes
  - Step 4: Confirmation and API submission

- [x] **SmartScanView.swift** - Camera + Vision OCR
  - AVFoundation camera preview
  - Real-time Vision text recognition
  - Confidence scoring and candidate selection
  - Result card with editing capability
  - Flash toggle and manual entry options

- [x] **ContentView.swift** - Main app structure
  - TabView with 4 tabs (Meters, Verify, Campaigns, Profile)
  - MetersListView with scan trigger
  - VerifyView for community verification
  - CampaignsView with join/leave functionality
  - Sheet/fullScreenCover navigation

#### Landing Page ✅
Complete marketing site built by subagent:

- **URL:** http://10.10.10.24:3011
- **Tech:** Next.js 14 + TypeScript + Tailwind CSS
- **Port:** 3011 (registered in PORTS.md)

Sections:
1. Navigation with smooth scroll
2. Hero with Kickstarter teaser
3. Stats bar (100% Free, 1 min to scan, etc.)
4. Problem section (3 pain points)
5. Solution section (Scan → Track → Compare)
6. Features (App vs MeterPi hardware)
7. Pricing (4 tiers + referral rewards)
8. Kickstarter teaser with backer benefits
9. Email signup waitlist form
10. Footer with links

### Files Created
```
ios/MeterScience/Services/
├── APIService.swift      # API client with all endpoints
└── AuthManager.swift     # Auth state + LoginView

ios/MeterScience/Views/
├── ContentView.swift     # Main TabView + sub-views
├── ProfileView.swift     # Stats, badges, account actions
├── ReferralView.swift    # Referral system + share sheet
├── SubscriptionView.swift # StoreKit 2 paywall
├── CalibrationView.swift  # Meter setup wizard
└── SmartScanView.swift   # Camera + Vision OCR

web/
├── app/
│   ├── globals.css       # Tailwind + custom styles
│   ├── layout.tsx        # Root layout with SEO
│   └── page.tsx          # Complete landing page
├── package.json          # Next.js config (port 3011)
├── tailwind.config.ts    # Custom color scheme
├── README.md             # Setup instructions
├── DEPLOYMENT.md         # Full deployment guide
└── start.sh              # Quick start script
```

### Services Running
- **API:** http://10.10.10.24:3090
- **Landing Page:** http://10.10.10.24:3011

### Next Steps
1. Build iOS app in Xcode and test on device
2. Configure Formspree for email collection
3. Add real images/screenshots to landing page
4. Git commit all changes
5. Consider TestFlight beta

---

## Session: Camera Fix + System Camera
**Date:** 2025-12-15

### Completed

#### Camera/Scanner Working ✅
- [x] Fixed white screen camera preview issue (live preview layer wasn't rendering)
- [x] Switched to UIImagePickerController (system camera) for reliable capture
- [x] OCR works on captured photos - detecting meter readings
- [x] Multiple OCR candidates shown (meter reading + serial numbers)
- [x] Created PR #1 for camera fixes (branch: fix/camera-preview-timing)

#### Git Workflow Improvements ✅
- [x] Added Git workflow guidelines to CLAUDE.md
- [x] Always use feature branches before making changes
- [x] Include testing instructions in PRs

#### Architecture Documentation ✅
- [x] Created draw.io architecture diagram (docs/architecture-diagram.drawio)

### Backlog (Future Features)

#### Live Camera Preview (Auto-capture)
- The custom AVCaptureSession preview layer never rendered properly
- Live OCR was working (detected text) but preview was white
- Possibly SwiftUI UIViewRepresentable layout issue
- Low priority - system camera works well as workaround

#### Enhanced Meter Metadata Collection
- Capture multiple photos per scan session (meter face, serial number, location)
- OCR candidates could identify: meter reading vs meter serial number
- Bonus XP for complete metadata (photo of meter label, utility account number)
- Could help with verification - serial number links readings to specific meter

### Git Commits
- `1b5774f` Clean up SmartScanView - remove unused camera code
- `93794f6` Use system camera (UIImagePickerController) for reliable capture
- `ef9d068` Add Git workflow guidelines to CLAUDE.md

### Next Steps
1. Merge camera fix PR
2. Continue with other iOS app features
3. Test full flow: register → add meter → scan reading → verify

---

## Session: Calibration UX + Reading History
**Date:** 2025-12-15

### Completed

#### Calibration Flow Improvements ✅
- [x] Default meter name auto-fills based on type ("My Gas Meter", etc.)
- [x] Canadian postal code formatting (A1A 1A1) with validation
- [x] Postal code saved to UserDefaults for reuse
- [x] Compact header on Step 3 - camera visible without scrolling
- [x] Auto-dismiss keyboard when entering camera step
- [x] Clear post-capture UI: "Photo captured!" → "Now enter the reading"
- [x] Auto-focus text field after photo capture
- [x] Flash/torch toggle button on camera preview
- [x] Torch stays on for aiming (not just capture flash)

#### Meter Detail View ✅
- [x] Tap meter → shows detail view with reading history
- [x] Stats: readings count, latest value, postal code
- [x] "Take New Reading" button opens scanner
- [x] Reading rows: value, date/time, verification status dot
- [x] Pull to refresh readings
- [x] Navigation using NavigationLink

#### API Integration ✅
- [x] Backend running on port 3090
- [x] WiFi deployment working (phone untethered)

### Files Changed
- `CalibrationView.swift` - UX improvements, flash, postal code
- `ContentView.swift` - Added MeterDetailView with readings history
- `APIService.swift` - Made MeterResponse Hashable, ReadingResponse optional status

### Next Steps
1. Use meter digit count in OCR validation
2. Activity/event log view
3. Profile improvements
4. GPS location capture

---

## Session: [Next Session]
**Date:**
**Duration:**

### Completed

### In Progress

### Notes
