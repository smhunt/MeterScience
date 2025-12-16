# MinIO Storage Service

This service provides S3-compatible object storage for meter reading images using MinIO.

## Features

- Base64 image upload from iOS app
- Automatic image hash generation for deduplication
- Organized storage by user and meter ID
- Public and presigned URL support
- Automatic bucket creation and configuration

## Usage

### Upload Image

```python
from services.storage import storage_service

# Upload image (async)
image_url, image_hash = await storage_service.upload_image(
    image_data=image_bytes,
    user_id=user_id,
    meter_id=meter_id,
    filename="optional_name.jpg"  # Optional
)
```

### Get Presigned URL

```python
# Generate temporary URL for private access
presigned_url = storage_service.get_presigned_url(
    s3_key="users/{user_id}/meters/{meter_id}/image.jpg",
    expiration=3600  # 1 hour
)
```

### Delete Image

```python
# Delete by S3 key
await storage_service.delete_image(s3_key)

# Delete by URL
await storage_service.delete_image_by_url(image_url)
```

## Storage Structure

Images are stored in two locations:

1. **User/Meter organized**: `users/{user_id}/meters/{meter_id}/{timestamp}_{hash}.jpg`
2. **Hash-based (deduplication)**: `hashes/{sha256_hash}.jpg`

When an image with the same hash already exists, the service returns the existing URL instead of uploading again.

## Configuration

Environment variables (see `.env.example`):

```bash
MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=meterscience
MINIO_SECRET_KEY=meterscience123
MINIO_BUCKET=meter-images
MINIO_REGION=us-east-1
```

## Docker Setup

MinIO is automatically configured in `docker-compose.yml`:

- **API Port**: 9000 (S3-compatible API)
- **Console Port**: 9001 (Web UI)
- **Credentials**: meterscience / meterscience123

Access the MinIO console at http://localhost:9001

## API Integration

The storage service is integrated into the readings endpoints:

### Create Reading with Image

```json
POST /api/v1/readings
{
  "meter_id": "uuid",
  "raw_value": "123456",
  "normalized_value": "123456",
  "confidence": 0.95,
  "image_data": "base64_encoded_image_string"
}
```

The response will include the `image_url`:

```json
{
  "id": "uuid",
  "image_url": "http://localhost:9000/meter-images/users/.../image.jpg",
  ...
}
```

## Image Deduplication

The service automatically:

1. Generates SHA256 hash of uploaded images
2. Checks if hash already exists
3. Returns existing URL if found (saves storage)
4. Stores both user-organized and hash-based copies

## Security Notes

**Development Mode**: The bucket is configured with public read access for easy development.

**Production**: Should use:
- Presigned URLs instead of public access
- Proper IAM policies
- HTTPS endpoint
- Content validation and size limits
- Virus scanning for uploaded images
