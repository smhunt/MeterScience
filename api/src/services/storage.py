"""
MinIO/S3 Storage Service for meter reading images
"""

import hashlib
import os
from datetime import timedelta
from typing import Optional
from uuid import UUID

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from fastapi import HTTPException, status


class StorageService:
    """S3-compatible storage service using MinIO"""

    def __init__(self):
        self.endpoint = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
        self.access_key = os.getenv("MINIO_ACCESS_KEY", "meterscience")
        self.secret_key = os.getenv("MINIO_SECRET_KEY", "meterscience123")
        self.bucket_name = os.getenv("MINIO_BUCKET", "meter-images")
        self.region = os.getenv("MINIO_REGION", "us-east-1")
        self.available = False
        self.s3_client = None

        # Initialize S3 client - skip if storage is disabled
        if os.getenv("STORAGE_ENABLED", "true").lower() == "false":
            print("Storage service disabled via STORAGE_ENABLED=false")
            return

        try:
            self.s3_client = boto3.client(
                "s3",
                endpoint_url=self.endpoint,
                aws_access_key_id=self.access_key,
                aws_secret_access_key=self.secret_key,
                region_name=self.region,
                config=Config(signature_version="s3v4"),
            )

            # Ensure bucket exists
            self._ensure_bucket_exists()
            self.available = True
        except Exception as e:
            print(f"Storage service not available: {e}")

    def _ensure_bucket_exists(self) -> None:
        """Create bucket if it doesn't exist"""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code == "404":
                # Bucket doesn't exist, create it
                try:
                    self.s3_client.create_bucket(Bucket=self.bucket_name)

                    # Set public read policy for the bucket (for image access)
                    # In production, use presigned URLs instead
                    bucket_policy = {
                        "Version": "2012-10-17",
                        "Statement": [
                            {
                                "Sid": "PublicRead",
                                "Effect": "Allow",
                                "Principal": "*",
                                "Action": ["s3:GetObject"],
                                "Resource": [f"arn:aws:s3:::{self.bucket_name}/*"]
                            }
                        ]
                    }
                    import json
                    self.s3_client.put_bucket_policy(
                        Bucket=self.bucket_name,
                        Policy=json.dumps(bucket_policy)
                    )
                except ClientError as create_error:
                    print(f"Error creating bucket: {create_error}")
            else:
                print(f"Error checking bucket: {e}")

    def generate_image_hash(self, image_data: bytes) -> str:
        """
        Generate SHA256 hash of image data for deduplication

        Args:
            image_data: Raw image bytes

        Returns:
            Hexadecimal hash string
        """
        return hashlib.sha256(image_data).hexdigest()

    async def upload_image(
        self,
        image_data: bytes,
        user_id: UUID,
        meter_id: UUID,
        filename: Optional[str] = None,
    ) -> tuple[str, str]:
        """
        Upload image to MinIO storage

        Args:
            image_data: Raw image bytes
            user_id: User ID (for organizing files)
            meter_id: Meter ID (for organizing files)
            filename: Optional original filename (will generate if not provided)

        Returns:
            Tuple of (image_url, image_hash)

        Raises:
            HTTPException: If upload fails
        """
        # Check if storage is available
        if not self.available or not self.s3_client:
            # Return empty values if storage is not available
            return None, None

        # Generate image hash for deduplication
        image_hash = self.generate_image_hash(image_data)

        # Check if image already exists by hash
        existing_key = f"hashes/{image_hash}.jpg"
        try:
            self.s3_client.head_object(Bucket=self.bucket_name, Key=existing_key)
            # Image already exists, return existing URL
            image_url = self.get_public_url(existing_key)
            return image_url, image_hash
        except ClientError:
            # Image doesn't exist, continue with upload
            pass

        # Generate S3 key: users/{user_id}/meters/{meter_id}/{timestamp}_{hash[:8]}.jpg
        import time
        timestamp = int(time.time())

        if not filename:
            filename = f"{timestamp}_{image_hash[:8]}.jpg"

        # Organize by user and meter
        s3_key = f"users/{user_id}/meters/{meter_id}/{filename}"

        # Also store in hash-based location for deduplication
        hash_key = existing_key

        try:
            # Upload to main location
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_key,
                Body=image_data,
                ContentType="image/jpeg",
                Metadata={
                    "user_id": str(user_id),
                    "meter_id": str(meter_id),
                    "image_hash": image_hash,
                }
            )

            # Upload to hash-based location (for deduplication)
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=hash_key,
                Body=image_data,
                ContentType="image/jpeg",
                Metadata={
                    "image_hash": image_hash,
                }
            )

            # Get public URL
            image_url = self.get_public_url(s3_key)

            return image_url, image_hash

        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to upload image: {str(e)}"
            )

    def get_public_url(self, s3_key: str) -> str:
        """
        Get public URL for an S3 object

        Args:
            s3_key: S3 object key

        Returns:
            Public URL string
        """
        # For MinIO with public bucket policy
        return f"{self.endpoint}/{self.bucket_name}/{s3_key}"

    def get_presigned_url(
        self,
        s3_key: str,
        expiration: int = 3600
    ) -> str:
        """
        Generate presigned URL for private access

        Args:
            s3_key: S3 object key
            expiration: URL expiration time in seconds (default 1 hour)

        Returns:
            Presigned URL string

        Raises:
            HTTPException: If URL generation fails
        """
        try:
            url = self.s3_client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket_name, "Key": s3_key},
                ExpiresIn=expiration
            )
            return url
        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to generate presigned URL: {str(e)}"
            )

    async def delete_image(self, s3_key: str) -> None:
        """
        Delete image from storage

        Args:
            s3_key: S3 object key to delete

        Raises:
            HTTPException: If deletion fails
        """
        try:
            self.s3_client.delete_object(
                Bucket=self.bucket_name,
                Key=s3_key
            )
        except ClientError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to delete image: {str(e)}"
            )

    async def delete_image_by_url(self, image_url: str) -> None:
        """
        Delete image by its URL

        Args:
            image_url: Full image URL

        Raises:
            HTTPException: If deletion fails
        """
        # Extract S3 key from URL
        # URL format: http://localhost:9000/meter-images/users/{user_id}/...
        try:
            s3_key = image_url.split(f"/{self.bucket_name}/")[1]
            await self.delete_image(s3_key)
        except (IndexError, KeyError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid image URL format"
            )


# Global storage service instance
storage_service = StorageService()
