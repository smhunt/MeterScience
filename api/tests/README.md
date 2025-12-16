# MeterScience API Tests

Comprehensive test suite for the MeterScience FastAPI backend.

## Setup

Install test dependencies:

```bash
cd api
pip install -r requirements.txt
```

## Running Tests

### Run all tests
```bash
pytest
```

### Run with coverage report
```bash
pytest --cov=src --cov-report=html
```

### Run specific test file
```bash
pytest tests/test_users.py
pytest tests/test_meters.py
pytest tests/test_readings.py
```

### Run specific test class
```bash
pytest tests/test_users.py::TestUserRegistration
```

### Run specific test
```bash
pytest tests/test_users.py::TestUserRegistration::test_register_user_success
```

### Run with verbose output
```bash
pytest -v
```

### Run with output (print statements)
```bash
pytest -s
```

### Run only failed tests from last run
```bash
pytest --lf
```

## Test Structure

```
tests/
├── __init__.py
├── conftest.py           # Test fixtures and configuration
├── test_users.py         # User endpoint tests
├── test_meters.py        # Meter endpoint tests
├── test_readings.py      # Reading endpoint tests
└── README.md            # This file
```

## Test Database

Tests use an in-memory SQLite database for speed and isolation. Each test gets a fresh database that is automatically created and torn down.

## Fixtures

Common fixtures available in `conftest.py`:

- `client` - Async HTTP test client
- `db_session` - Database session for direct DB operations
- `test_user` - Pre-created test user
- `test_user_2` - Second test user for multi-user tests
- `auth_headers` - Authentication headers for test_user
- `auth_headers_user_2` - Authentication headers for test_user_2

## Test Coverage

Current test coverage includes:

### Users (`test_users.py`)
- User registration (with/without email, duplicate email, validation)
- User login (success, wrong password, non-existent user)
- Get current user (authenticated and unauthenticated)
- Update user profile
- Referral code application
- Leaderboard

### Meters (`test_meters.py`)
- Create meter (all valid types, invalid types, validation)
- List meters (filtering, pagination, user isolation)
- Get single meter
- Update meter
- Delete meter
- Meter calibration (bounding box, sample readings)
- Meter statistics

### Readings (`test_readings.py`)
- Create reading (with metadata, usage calculation, anomaly detection)
- List readings (filtering by meter, date, status, pagination)
- Get latest reading
- Get specific reading
- Delete reading
- Authorization checks

## Adding New Tests

1. Create test file: `test_<feature>.py`
2. Import required fixtures from `conftest.py`
3. Organize tests into classes by functionality
4. Use descriptive test names: `test_<action>_<expected_result>`
5. Follow AAA pattern: Arrange, Act, Assert

Example:

```python
@pytest.mark.asyncio
async def test_create_widget_success(
    client: AsyncClient,
    test_user: User,
    auth_headers: dict
):
    # Arrange
    widget_data = {"name": "Test Widget", "color": "blue"}

    # Act
    response = await client.post(
        "/api/v1/widgets/",
        headers=auth_headers,
        json=widget_data
    )

    # Assert
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Widget"
```

## Continuous Integration

These tests are designed to run in CI/CD pipelines. Exit code 0 indicates all tests passed.

## Coverage Reports

After running tests with coverage, view the HTML report:

```bash
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
```

## Common Issues

### Import errors
Make sure you're in the `api` directory and the virtual environment is activated.

### Database errors
Tests use SQLite which doesn't support all PostgreSQL features (like PostGIS). Geographic features are tested separately in integration tests.

### Async warnings
If you see warnings about event loops, make sure `pytest-asyncio` is installed and `asyncio_mode = auto` is set in `pytest.ini`.
