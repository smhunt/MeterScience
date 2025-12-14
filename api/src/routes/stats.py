"""
Statistics API endpoints
"""

from fastapi import APIRouter
router = APIRouter()

@router.get("/me")
async def get_my_stats():
    return {"message": "TODO: Get my stats"}

@router.get("/neighborhood")
async def get_neighborhood_stats():
    return {"message": "TODO: Get neighborhood stats"}

@router.get("/aggregate")
async def get_aggregate_stats():
    return {"message": "TODO: Get aggregate stats"}
