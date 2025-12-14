"""
Webhooks API endpoints
"""

from fastapi import APIRouter
router = APIRouter()

@router.get("/")
async def list_webhooks():
    return {"message": "TODO: List webhooks"}

@router.post("/")
async def create_webhook():
    return {"message": "TODO: Create webhook"}

@router.delete("/{webhook_id}")
async def delete_webhook(webhook_id: str):
    return {"message": f"TODO: Delete webhook {webhook_id}"}
