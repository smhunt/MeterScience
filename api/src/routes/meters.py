"""
Meters API endpoints
"""

from fastapi import APIRouter
router = APIRouter()

@router.get("/")
async def list_meters():
    return {"message": "TODO: List meters"}

@router.post("/")
async def create_meter():
    return {"message": "TODO: Create meter"}

@router.get("/{meter_id}")
async def get_meter(meter_id: str):
    return {"message": f"TODO: Get meter {meter_id}"}
