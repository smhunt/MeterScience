"""
MeterScience API
FastAPI backend for citizen science meter reading platform
"""

from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, status, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import uvicorn

from .database import engine, get_db, Base
from .routes import readings, users, meters, campaigns, verify, stats, webhooks, activity
from .services.auth import verify_token, get_current_user
from .models import User

# Create tables
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await engine.dispose()

# Initialize app
app = FastAPI(
    title="MeterScience API",
    description="Citizen science platform for crowdsourced utility meter reading",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(meters.router, prefix="/api/v1/meters", tags=["Meters"])
app.include_router(readings.router, prefix="/api/v1/readings", tags=["Readings"])
app.include_router(campaigns.router, prefix="/api/v1/campaigns", tags=["Campaigns"])
app.include_router(verify.router, prefix="/api/v1/verify", tags=["Verification"])
app.include_router(stats.router, prefix="/api/v1/stats", tags=["Statistics"])
app.include_router(webhooks.router, prefix="/api/v1/webhooks", tags=["Webhooks"])
app.include_router(activity.router, prefix="/api/v1/activity", tags=["Activity"])


@app.get("/")
async def root():
    return {
        "name": "MeterScience API",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "operational"
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }


@app.get("/api/v1")
async def api_info():
    return {
        "version": "1.0.0",
        "endpoints": {
            "users": "/api/v1/users",
            "meters": "/api/v1/meters",
            "readings": "/api/v1/readings",
            "campaigns": "/api/v1/campaigns",
            "verify": "/api/v1/verify",
            "stats": "/api/v1/stats",
            "webhooks": "/api/v1/webhooks",
            "activity": "/api/v1/activity",
        }
    }


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
