"""
Verification API endpoints
"""

from fastapi import APIRouter
router = APIRouter()

@router.get("/queue")
async def get_verification_queue():
    return {"message": "TODO: Get verification queue"}

@router.post("/{reading_id}/vote")
async def vote_on_reading(reading_id: str):
    return {"message": f"TODO: Vote on reading {reading_id}"}
