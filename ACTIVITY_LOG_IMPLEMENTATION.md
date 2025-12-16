# Activity Log API Implementation Summary

## Files Created/Modified

### 1. Database Model Added
**File:** `/Users/seanhunt/Code/MeterScience/api/src/models.py`

Added `ActivityLog` model with:
- UUID primary key
- Foreign key to users table
- Activity type, description, and metadata fields
- Timestamp
- Indexes on user_id, created_at, and activity_type

### 2. API Routes Created
**File:** `/Users/seanhunt/Code/MeterScience/api/src/routes/activity.py`

Implements:
- `GET /api/v1/activity/` - List user activities with pagination and filtering
- `log_activity()` helper function for creating activity logs

Pydantic models:
- `ActivityResponse` - Single activity
- `ActivityListResponse` - Paginated list with metadata

### 3. Router Registration
**Files Modified:**
- `/Users/seanhunt/Code/MeterScience/api/src/main.py` - Added activity router
- `/Users/seanhunt/Code/MeterScience/api/src/routes/__init__.py` - Exported activity module

### 4. Documentation
**Files Created:**
- `/Users/seanhunt/Code/MeterScience/api/ACTIVITY_LOG_README.md` - Full API documentation
- `/Users/seanhunt/Code/MeterScience/api/src/routes/activity_usage_example.py` - Integration examples

## API Endpoint

### GET /api/v1/activity/

**Query Parameters:**
- `activity_type` (optional): Filter by type (reading, verification, xp_gain, badge_earned, level_up, streak)
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

## Helper Function Usage

Import in any route file:
```python
from .activity import log_activity
```

Use in your route handlers:
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

## Activity Types

| Type | Description | Example Metadata |
|------|-------------|------------------|
| `reading` | Meter reading recorded | `meter_id`, `confidence`, `xp_earned` |
| `verification` | Verified another's reading | `reading_id`, `vote`, `xp_earned` |
| `xp_gain` | Earned XP | `xp_amount`, `total_xp` |
| `badge_earned` | Earned a badge | `badge_id`, `badge_name`, `badge_tier` |
| `level_up` | Leveled up | `old_level`, `new_level`, `total_xp` |
| `streak` | Streak maintained/reset | `streak_days`, `bonus_xp` |

## Integration Points

To start logging activities, add `log_activity()` calls in:

1. **api/src/routes/readings.py**
   - After creating a reading (line ~160)
   - Log "reading" activity type

2. **XP/Level system**
   - When awarding XP, log "xp_gain"
   - When leveling up, log "level_up"

3. **Badge system**
   - When awarding badge, log "badge_earned"

4. **api/src/routes/verify.py**
   - After verification vote, log "verification"

5. **Streak logic**
   - When streak increases, log "streak"

## Database Migration

The `ActivityLog` table will be auto-created on app startup via:
```python
await conn.run_sync(Base.metadata.create_all)
```

Or create a migration if using Alembic:
```bash
cd api
alembic revision --autogenerate -m "Add activity_logs table"
alembic upgrade head
```

## Testing

Start the API server:
```bash
cd /Users/seanhunt/Code/MeterScience/api
source venv/bin/activate
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

Test endpoints:
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

## iOS App Integration

1. Fetch activities when Profile view loads
2. Display in a scrollable list
3. Show activity icons based on type
4. Format timestamps as relative (e.g., "2 hours ago")
5. Implement infinite scroll for pagination

## Code Style Compliance

- Uses async/await patterns like other routes
- Follows SQLAlchemy 2.0 mapped_column syntax
- Uses Pydantic for request/response validation
- Includes proper type hints
- Matches existing route structure and naming conventions
- Uses JSONB for metadata storage (PostgreSQL)
- Includes database indexes for performance

## Next Steps

1. Start the API server to auto-create the database table
2. Test the endpoint with Swagger UI at http://localhost:8000/docs
3. Add `log_activity()` calls to existing routes (see usage examples)
4. Update iOS app to fetch and display activities
5. Consider adding real-time updates via WebSocket (future enhancement)
