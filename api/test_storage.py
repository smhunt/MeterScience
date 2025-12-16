#!/usr/bin/env python3
"""
Test script for MinIO storage service

Prerequisites:
1. Docker containers running: docker-compose up -d
2. MinIO accessible at http://localhost:9000
3. Environment variables set (or using defaults)

Usage:
    python test_storage.py
"""

import asyncio
import base64
import os
import sys
from uuid import uuid4

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))


async def test_storage():
    """Test MinIO storage operations"""
    from services.storage import storage_service

    print("=" * 60)
    print("MinIO Storage Service Test")
    print("=" * 60)

    # Test 1: Service initialization
    print("\n✅ Storage service initialized")
    print(f"   Endpoint: {storage_service.endpoint}")
    print(f"   Bucket: {storage_service.bucket_name}")

    # Test 2: Upload test image
    print("\n📤 Testing image upload...")

    # Create a simple test image (1x1 red pixel PNG)
    test_image_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
    test_image_bytes = base64.b64decode(test_image_b64)

    user_id = uuid4()
    meter_id = uuid4()

    try:
        image_url, image_hash = await storage_service.upload_image(
            image_data=test_image_bytes,
            user_id=user_id,
            meter_id=meter_id,
        )

        print(f"✅ Upload successful!")
        print(f"   URL: {image_url}")
        print(f"   Hash: {image_hash}")

    except Exception as e:
        print(f"❌ Upload failed: {e}")
        return

    # Test 3: Test deduplication
    print("\n🔄 Testing deduplication...")

    try:
        image_url2, image_hash2 = await storage_service.upload_image(
            image_data=test_image_bytes,
            user_id=uuid4(),  # Different user
            meter_id=uuid4(),  # Different meter
        )

        if image_hash == image_hash2:
            print(f"✅ Deduplication working! Same hash returned.")
            print(f"   Hash: {image_hash2}")
        else:
            print(f"❌ Deduplication failed - different hashes")

    except Exception as e:
        print(f"❌ Deduplication test failed: {e}")

    # Test 4: Presigned URL
    print("\n🔐 Testing presigned URL generation...")

    try:
        # Extract S3 key from URL
        s3_key = image_url.split(f"/{storage_service.bucket_name}/")[1]
        presigned_url = storage_service.get_presigned_url(s3_key, expiration=60)

        print(f"✅ Presigned URL generated!")
        print(f"   URL: {presigned_url[:80]}...")

    except Exception as e:
        print(f"❌ Presigned URL failed: {e}")

    # Test 5: Delete image
    print("\n🗑️  Testing image deletion...")

    try:
        await storage_service.delete_image_by_url(image_url)
        print(f"✅ Image deleted successfully!")

    except Exception as e:
        print(f"❌ Deletion failed: {e}")

    print("\n" + "=" * 60)
    print("Test completed!")
    print("=" * 60)
    print("\n📌 Next steps:")
    print("   1. Access MinIO console: http://localhost:9001")
    print("      Username: meterscience")
    print("      Password: meterscience123")
    print("   2. Verify 'meter-images' bucket exists")
    print("   3. Test from iOS app by submitting a reading with image_data")
    print()


if __name__ == "__main__":
    asyncio.run(test_storage())
