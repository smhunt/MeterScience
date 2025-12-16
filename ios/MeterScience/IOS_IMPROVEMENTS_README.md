# iOS Improvements: Offline Queue & Tier Enforcement

This document describes the three iOS improvements implemented for MeterScience.

## 1. Offline Reading Queue

**Location:** `/ios/MeterScience/Services/OfflineQueue.swift`

### Features

- **Automatic Queueing**: Readings taken offline are automatically queued
- **Auto-Sync**: Network monitoring automatically syncs when connection is restored
- **Persistent Storage**: Queue saved to UserDefaults, survives app restarts
- **Manual Sync**: Users can manually trigger sync from the queue view
- **Visual Feedback**: Shows pending count and sync status

### Usage

```swift
// Queue a reading when offline
let reading = OfflineQueue.PendingReading(
    meterId: meter.id,
    rawValue: "123456",
    normalizedValue: "123456",
    confidence: 0.95,
    imageData: imageData,
    latitude: location?.coordinate.latitude,
    longitude: location?.coordinate.longitude
)

OfflineQueue.shared.queueReading(reading)

// Manual sync
await OfflineQueue.shared.syncPendingReadings()

// Show queue UI
OfflineQueueView()
    .sheet(isPresented: $showQueue) {
        OfflineQueueView()
    }
```

### Integration Points

1. **Meter Reading Flow**: Add to reading submission logic
2. **Tab Bar Badge**: Show pending count as badge on home tab
3. **Settings View**: Add "Offline Queue" row to show status

### Example Integration

```swift
// In reading submission
func submitReading(_ reading: MeterReading) async {
    do {
        let response = try await APIService.shared.createReading(...)
        // Success - reading uploaded
    } catch {
        // Network error - queue for later
        let pendingReading = OfflineQueue.PendingReading(
            meterId: reading.meterId,
            rawValue: reading.rawValue,
            normalizedValue: reading.normalizedValue,
            confidence: reading.confidence,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
        OfflineQueue.shared.queueReading(pendingReading)
    }
}

// Show badge on tab
TabView {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house")
        }
        .badge(OfflineQueue.shared.pendingReadings.count)
}
```

## 2. Subscription Tier Enforcement

**Location:** `/ios/MeterScience/Services/TierEnforcement.swift`

### Features

- **Feature-Based Access Control**: Check access before showing premium features
- **Automatic Upgrade Prompts**: Beautiful upgrade UI when users try locked features
- **Tier Badges**: Visual indicators of user's subscription level
- **Scope-Based Stats**: Different tiers unlock different geographical scopes

### Subscription Tiers

| Tier | Price | Data Access |
|------|-------|-------------|
| Free | $0 | Own data only |
| Neighbor | $2.99/mo | Same postal code |
| Block | $4.99/mo | 5km radius |
| District | $9.99/mo | 25km radius + API |

### Usage

```swift
// Check access before showing feature
if TierEnforcement.shared.checkAccess(to: .neighborhoodStats) {
    // Show neighborhood stats
    showNeighborhoodStats()
} else {
    // Upgrade prompt automatically shown
    // TierEnforcement.shared.showUpgradePrompt = true
}

// Check access without showing prompt
if TierEnforcement.shared.hasAccess(to: .blockStats) {
    // User has access
}

// Check scope access for stats
let scope = StatsScope.radius5km
if TierEnforcement.shared.canAccessScope(scope) {
    // Load stats for this scope
}

// Display tier badge
TierBadge(tier: user.subscriptionTier)
```

### Integration Points

1. **Neighborhood Stats View**: Gate access by postal code/radius
2. **API Settings**: Show API access only for District tier
3. **Profile View**: Display current tier with badge
4. **Stats Selector**: Show locked scopes with upgrade prompt

### Example Integration

```swift
// In NeighborhoodStatsView
struct NeighborhoodStatsView: View {
    @StateObject private var enforcement = TierEnforcement.shared
    @State private var selectedScope = StatsScope.own

    var body: some View {
        VStack {
            // Scope picker
            Picker("Scope", selection: $selectedScope) {
                ForEach(StatsScope.allCases, id: \.self) { scope in
                    HStack {
                        Text(scope.displayName)
                        if !enforcement.canAccessScope(scope) {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .tag(scope)
                }
            }

            // Load stats
            if enforcement.canAccessScope(selectedScope) {
                StatsContent(scope: selectedScope)
            } else {
                Button("Unlock \(selectedScope.displayName)") {
                    enforcement.blockedFeature = .neighborhoodStats
                    enforcement.showUpgradePrompt = true
                }
            }
        }
        .sheet(isPresented: $enforcement.showUpgradePrompt) {
            if let feature = enforcement.blockedFeature {
                UpgradePromptView(feature: feature)
            }
        }
    }
}
```

## 3. API Activity Integration

**Location:** `/ios/MeterScience/Views/ActivityLogView.swift`

### Features

- **API-First Loading**: Attempts to load from `/api/v1/activity/` endpoint
- **Graceful Fallback**: Falls back to local generation if API not available
- **Pagination Support**: Ready for infinite scroll (page parameter)
- **Pull-to-Refresh**: Maintained from original implementation
- **Error Handling**: Shows errors to user, logs to console

### API Endpoint

```
GET /api/v1/activity/?page=1
```

**Response:**
```json
{
  "activities": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "activity_type": "reading_submitted",
      "title": "Reading Submitted",
      "description": "Captured meter reading",
      "metadata": {
        "reading_value": "123456",
        "meter_name": "Electric Meter",
        "xp_amount": 10
      },
      "xp_earned": 10,
      "created_at": "2025-12-15T10:30:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "per_page": 20
}
```

### Activity Types

- `reading_submitted` - User submitted a meter reading
- `verification_performed` - User verified another reading
- `xp_earned` - User earned XP
- `badge_earned` - User earned a badge
- `level_up` - User leveled up
- `streak_milestone` - User hit a streak milestone
- `campaign_joined` - User joined a campaign

### Models Added to APIService.swift

```swift
struct ActivityListResponse: Decodable {
    let activities: [ActivityItemResponse]
    let total: Int
    let page: Int
    let perPage: Int
}

struct ActivityItemResponse: Decodable, Identifiable {
    let id: UUID
    let userId: UUID
    let activityType: String
    let title: String
    let description: String?
    let metadata: ActivityMetadataResponse?
    let xpEarned: Int?
    let createdAt: Date
}

struct ActivityMetadataResponse: Decodable {
    let readingValue: String?
    let meterName: String?
    let meterId: String?
    let xpAmount: Int?
    let badgeId: String?
    let badgeName: String?
    let badgeIcon: String?
    let newLevel: Int?
    let streakDays: Int?
    let campaignName: String?
    let campaignId: String?
    let verificationVote: String?
}
```

### Models Updated in Models.swift

```swift
// ActivityItem now Codable
struct ActivityItem: Identifiable, Codable {
    let id: UUID
    let type: ActivityType
    let timestamp: Date
    let title: String
    let subtitle: String?
    let icon: String
    let color: CodableColor  // Changed from Color
    let metadata: ActivityMetadata?

    var displayColor: Color {  // New computed property
        color.color
    }

    // New factory method
    static func from(response: ActivityItemResponse) -> ActivityItem
}

// ActivityType now String-based enum
enum ActivityType: String, Codable {
    case readingSubmitted = "reading_submitted"
    case verificationPerformed = "verification_performed"
    case xpEarned = "xp_earned"
    case badgeEarned = "badge_earned"
    case levelUp = "level_up"
    case streakMilestone = "streak_milestone"
    case campaignJoined = "campaign_joined"
}

// ActivityMetadata now Codable
struct ActivityMetadata: Codable {
    // ... existing properties ...

    // New factory method
    static func from(response: ActivityMetadataResponse) -> ActivityMetadata
}

// New helper struct for Color serialization
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(_ color: Color)
}
```

### Usage

The ActivityLogView automatically uses the new API endpoint. No changes needed to existing UI code.

```swift
// View remains the same
NavigationLink("Activity") {
    ActivityLogView()
}
```

The ViewModel handles the API/fallback logic:

```swift
// In ActivityLogViewModel
func loadActivities() async {
    do {
        // Try API first
        let response = try await APIService.shared.getActivity(page: currentPage)
        activities = response.activities.map { ActivityItem.from(response: $0) }
    } catch APIError.notFound {
        // Fall back to local generation
        await loadActivitiesFallback()
    }
}
```

## Testing Checklist

### Offline Queue

- [ ] Take reading while offline - should queue
- [ ] Verify reading appears in OfflineQueueView
- [ ] Turn on network - should auto-sync
- [ ] Manually trigger sync - should work
- [ ] Force quit app - queue should persist
- [ ] Delete pending reading - should remove from queue

### Tier Enforcement

- [ ] Free user tries to view postal code stats - should show upgrade prompt
- [ ] Neighbor tier can see postal code stats
- [ ] Block tier can see 5km radius stats
- [ ] District tier can see all stats
- [ ] Upgrade prompt shows correct benefits
- [ ] Tier badges display correctly in UI

### Activity Integration

- [ ] Activity log loads from API when available
- [ ] Falls back to local generation if API missing
- [ ] Pull-to-refresh works
- [ ] Activities grouped by date correctly
- [ ] Empty state shows when no activities
- [ ] Different activity types show correct icons/colors

## File Structure

```
ios/MeterScience/
├── Services/
│   ├── OfflineQueue.swift       # NEW: Offline reading queue
│   ├── TierEnforcement.swift    # NEW: Subscription tier checks
│   ├── APIService.swift         # UPDATED: Added getActivity()
│   └── AuthManager.swift        # Existing
├── Models/
│   └── Models.swift             # UPDATED: Made ActivityItem Codable
└── Views/
    └── ActivityLogView.swift    # UPDATED: API integration
```

## Next Steps

1. **Backend**: Implement `/api/v1/activity/` endpoint in FastAPI
2. **UI Integration**: Add OfflineQueue badge to tab bar
3. **Settings**: Add "Offline Queue" row to ProfileView
4. **Stats View**: Gate neighborhood stats with TierEnforcement
5. **Subscription Flow**: Implement actual Stripe integration for upgrades
6. **Testing**: Comprehensive testing of offline scenarios

## Notes

- All new code follows existing SwiftUI patterns
- Maintains backward compatibility
- Graceful degradation (API fallback)
- Uses actor isolation for thread safety (APIService)
- MainActor for UI-related classes
- Proper error handling throughout
