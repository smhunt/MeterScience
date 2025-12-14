"""
Campaigns API endpoints
"""

from fastapi import APIRouter
router = APIRouter()

@router.get("/")
async def list_campaigns():
    return {"message": "TODO: List campaigns"}

@router.post("/")
async def create_campaign():
    return {"message": "TODO: Create campaign"}

@router.get("/{campaign_id}")
async def get_campaign(campaign_id: str):
    return {"message": f"TODO: Get campaign {campaign_id}"}

@router.post("/{campaign_id}/join")
async def join_campaign(campaign_id: str):
    return {"message": f"TODO: Join campaign {campaign_id}"}
