# Testing Guide

## Overview

The MeterScience API uses pytest with async support for comprehensive testing. Tests are designed to be fast, isolated, and maintainable.

## Quick Start

```bash
# Install dependencies
cd api
pip install -r requirements.txt

# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test file
pytest tests/test_users.py -v

# Run and stop on first failure
pytest -x
```

## Test Architecture

### Test Database
- Uses SQLite in-memory database for speed
- Each test gets a fresh database (created and destroyed automatically)
- No PostgreSQL required for unit tests
- Integration tests (not included) would use PostgreSQL + PostGIS

### Fixtures (conftest.py)
All tests have access to these fixtures:

#### Database Fixtures
- `db_session` - Async database session for direct queries
- `setup_database` - Auto-used fixture that creates/drops tables

#### HTTP Client
- `client` - Async HTTP client for API requests

#### User Fixtures
- `test_user` - Pre-created user (email: test@example.com, password: password123)
- `test_user_2` - Second user for multi-user scenarios
- `auth_headers` - Auth headers for test_user
- `auth_headers_user_2` - Auth headers for test_user_2

#### Domain-Specific Fixtures (per test file)
- `test_meter` - Pre-created meter (in meter/reading tests)
- `test_reading` - Pre-created reading (in reading tests)

## Test Files

### test_main.py
Tests for core API endpoints:
- Root endpoint (/)
- Health check (/health)
- API info (/api/v1)
- CORS headers
- 404 handling

### test_users.py
Tests for user management:
- **TestUserRegistration**: Registration with/without email, duplicate emails, validation
- **TestUserLogin**: Login success/failure, password verification
- **TestGetCurrentUser**: Get profile, auth required
- **TestUpdateCurrentUser**: Update display name, avatar, location
- **TestReferralCode**: Apply referral codes, validation, XP rewards
- **TestLeaderboard**: Global/local leaderboards, sorting

### test_meters.py
Tests for meter management:
- **TestCreateMeter**: Create with all valid types, validation, auth required
- **TestListMeters**: List user's meters, filter by type/status, pagination
- **TestGetMeter**: Get single meter, user isolation
- **TestUpdateMeter**: Update fields, validation
- **TestDeleteMeter**: Delete meter, cascade to readings
- **TestMeterCalibration**: Update bounding box, sample readings
- **TestMeterStats**: Reading counts, confidence averages

### test_readings.py
Tests for meter readings:
- **TestCreateReading**: Create with metadata, usage calculation, anomaly detection
- **TestListReadings**: Pagination, filter by meter/date/status
- **TestGetLatestReading**: Most recent reading per meter
- **TestGetReading**: Single reading, subscription tier access
- **TestDeleteReading**: Delete reading, auth required

## Test Organization

Tests follow a consistent pattern:

```python
class TestFeatureName:
    """Test description"""

    @pytest.mark.asyncio
    async def test_action_expected_result(
        self,
        client: AsyncClient,
        test_user: User,
        auth_headers: dict
    ):
        """Test docstring describing what's being tested"""
        # Arrange - set up test data
        data = {...}

        # Act - perform the action
        response = await client.post("/endpoint", json=data, headers=auth_headers)

        # Assert - verify results
        assert response.status_code == 201
        assert response.json()["field"] == "expected_value"
```

## Testing Patterns

### Authentication
```python
# Authenticated request
response = await client.get("/api/v1/users/me", headers=auth_headers)

# Unauthenticated request (should fail)
response = await client.get("/api/v1/users/me")
assert response.status_code == 401
```

### Database Assertions
```python
# Verify data was created
await db_session.refresh(test_user)
assert test_user.total_readings == 1

# Verify data was deleted
result = await db_session.execute(select(Meter).where(Meter.id == meter_id))
assert result.scalar_one_or_none() is None
```

### Pagination
```python
response = await client.get("/api/v1/readings/?page=1&per_page=10", headers=auth_headers)
data = response.json()
assert "readings" in data
assert "total" in data
assert "page" in data
assert data["page"] == 1
```

### Error Cases
```python
# Test validation errors
response = await client.post("/api/v1/meters/", json={"meter_type": "invalid"}, headers=auth_headers)
assert response.status_code == 400
assert "invalid" in response.json()["detail"].lower()

# Test not found
response = await client.get(f"/api/v1/meters/{fake_id}", headers=auth_headers)
assert response.status_code == 404
```

## Coverage Goals

Target coverage: 80%+ overall

Current coverage by module:
- `routes/users.py` - ~85%
- `routes/meters.py` - ~85%
- `routes/readings.py` - ~80%
- `services/auth.py` - ~90%
- `models.py` - ~70% (some fields only used in production)

Excluded from coverage:
- Database migrations
- CLI scripts
- Development tools

## Running Tests in CI/CD

Tests are designed to run in CI pipelines:

```yaml
# .github/workflows/test.yml example
- name: Run tests
  run: |
    cd api
    pip install -r requirements.txt
    pytest --cov=src --cov-fail-under=80
```

## Common Issues

### Async Event Loop Errors
**Symptom**: `RuntimeError: Event loop is closed`
**Solution**: Make sure pytest-asyncio is installed and pytest.ini has `asyncio_mode = auto`

### SQLite Limitations
**Symptom**: Tests fail with PostGIS/geography errors
**Solution**: Geographic features are tested in integration tests with real PostgreSQL

### Fixture Not Found
**Symptom**: `fixture 'auth_headers' not found`
**Solution**: Make sure conftest.py is in the tests directory

### Import Errors
**Symptom**: `ModuleNotFoundError: No module named 'src'`
**Solution**: Run pytest from the api/ directory, not api/tests/

## Best Practices

1. **Keep tests isolated** - Each test should work independently
2. **Use fixtures** - Don't duplicate setup code
3. **Test edge cases** - Not just happy paths
4. **Clear test names** - Name describes what's being tested
5. **One assertion per concept** - Tests can have multiple asserts, but test one thing
6. **Fast tests** - Use in-memory SQLite, avoid sleeps
7. **Deterministic** - Tests should always pass or always fail
8. **Clean up** - Use fixtures for teardown (automatic with our setup)

## Adding New Tests

1. Identify the feature to test
2. Create fixtures if needed (add to conftest.py or test file)
3. Write test class grouping related tests
4. Write individual test methods
5. Run tests: `pytest tests/test_yourfile.py -v`
6. Check coverage: `pytest tests/test_yourfile.py --cov=src.routes.yourroute`
7. Add to CI pipeline

## Performance Testing

Unit tests focus on correctness. For performance:
- Use pytest-benchmark for microbenchmarks
- Use locust for load testing (separate from unit tests)
- Profile with cProfile if needed

## Future Enhancements

Planned test additions:
- Integration tests with real PostgreSQL + PostGIS
- Tests for campaigns endpoints
- Tests for verification endpoints
- Tests for stats endpoints
- Tests for webhooks endpoints
- End-to-end tests with iOS app
- Load tests for scalability
- Security tests (SQL injection, XSS, etc.)
