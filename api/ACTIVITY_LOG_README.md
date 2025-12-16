# Activity Log API

The Activity Log API provides a feed of user activities for the MeterScience iOS app.

## Overview

The Activity Log tracks user actions and achievements including:
- Meter readings
- Verification activities
- XP gains
- Badges earned
- Level ups
- Streak maintenance

## Database Model

**Table:** `activity_logs`

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | Foreign key to users table |
| activity_type | String(50) | Type of activity |
| description | String(500) | Human-readable description |
| metadata | JSONB | Additional structured data |
| created_at | DateTime | Timestamp |

**Indexes:**
- `idx_activity_logs_user_id` on `user_id`
- `idx_activity_logs_created_at` on `created_at`
- `idx_activity_logs_activity_type` on `activity_type`

## API Endpoints

### GET /api/v1/activity/

List activity logs for the current user.

**Authentication:** Required (Bearer token)

**Query Parameters:**
- `activity_type` (optional): Filter by activity type
- `page` (default: 1): Page number
- `per_page` (default: 50, max: 100): Items per page

**Response:**
```json
{
  "activities": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "activity_type": "reading",
      "description": "Recorded meter reading: 12345.6",
      "metadata": {
        "meter_id": "uuid",
        "confidence": 0.95,
        "xp_earned": 10
      },
      "created_at": "2025-12-15T10:30:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "per_page": 50
}
```

## Activity Types

| Type | Description | Metadata Fields |
|------|-------------|-----------------|
| `reading` | Meter reading recorded | `meter_id`, `confidence`, `xp_earned` |
| `verification` | Verified another user's reading | `reading_id`, `vote`, `xp_earned` |
| `xp_gain` | Earned XP | `xp_amount`, `total_xp` |
| `badge_earned` | Earned a badge | `badge_id`, `badge_name`, `badge_tier` |
| `level_up` | Leveled up | `old_level`, `new_level`, `total_xp` |
| `streak` | Streak maintained or reset | `streak_days`, `bonus_xp` |
| `campaign` | Joined/completed campaign | `campaign_id`, `campaign_name` |

## Usage in Other Routes

Import the helper function:

```python
from .activity import log_activity
```

Log an activity:

```python
await log_activity(
    db=db,
    user_id=current_user.id,
    activity_type="reading",
    description="Recorded meter reading: 12345.6",
    metadata={
        "meter_id": str(meter_id),
        "confidence": 0.95,
        "xp_earned": 10
    }
)
```

**Important:** The `log_activity` function uses `db.flush()` instead of `db.commit()`, so it will be committed as part of the parent transaction. This ensures atomicity.

## Integration Examples

See `api/src/routes/activity_usage_example.py` for detailed examples of how to integrate activity logging into:
- Readings endpoint (when user creates a reading)
- XP system (when user gains XP or levels up)
- Badge system (when user earns a badge)
- Verification endpoint (when user verifies a reading)
- Streak system (when user maintains or breaks a streak)
- Campaign endpoint (when user joins a campaign)

## iOS App Integration

The iOS app should:

1. **Fetch activities on Profile view load:**
```swift
GET /api/v1/activity/?page=1&per_page=50
```

2. **Filter by type if needed:**
```swift
GET /api/v1/activity/?activity_type=badge_earned&page=1&per_page=20
```

3. **Implement infinite scroll:**
```swift
// Load more when user scrolls to bottom
GET /api/v1/activity/?page=2&per_page=50
```

4. **Display in a list:**
- Show activity icon based on `activity_type`
- Display `description` as the main text
- Show timestamp relative to now (e.g., "2 hours ago")
- Optionally expand to show `metadata` details

## Database Migration

After adding this feature, create and run the migration:

```bash
cd api
alembic revision --autogenerate -m "Add activity_logs table"
alembic upgrade head
```

Or if not using Alembic, the table will be auto-created on app startup via SQLAlchemy's `create_all()`.

## Testing

Example cURL request:

```bash
# Get all activities
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/v1/activity/

# Filter by type
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/v1/activity/?activity_type=reading

# Pagination
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8000/api/v1/activity/?page=2&per_page=20
```

## Performance Considerations

- The `created_at` index ensures fast sorting by newest first
- The `user_id` index ensures fast filtering by user
- The `activity_type` index enables efficient filtering by type
- Consider archiving or deleting old activities after 1 year to keep table size manageable
- For very active users, consider implementing a cache layer

## Future Enhancements

Potential future additions:
- Real-time updates via WebSocket
- Activity aggregation (e.g., "Earned 5 badges this week")
- Social features (see friends' activities)
- Export activity history
- Activity search
