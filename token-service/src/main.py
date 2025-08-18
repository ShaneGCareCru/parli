"""
Parli Token Service
FastAPI backend for ephemeral OpenAI token generation
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
from datetime import datetime, timedelta, timezone
from pydantic import BaseModel
import openai
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Parli Token Service",
    description="Ephemeral token service for Parli voice translator",
    version="1.0.0",
)

# CORS middleware for mobile app access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure with specific origins in production
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


class TokenResponse(BaseModel):
    token: str
    expires_at: datetime


@app.get("/healthz")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc)}


@app.post("/realtime/ephemeral", response_model=TokenResponse)
async def create_ephemeral_token():
    """
    Create ephemeral OpenAI Realtime API token
    Returns token with 5-minute expiry for secure mobile access
    """
    try:
        # Get OpenAI API key from environment
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            logger.error("OpenAI API key not configured")
            raise HTTPException(status_code=500, detail="Service configuration error")

        # TODO: Initialize OpenAI client when ephemeral token API becomes available
        # client = openai.AsyncOpenAI(api_key=api_key)

        # SECURITY WARNING: Returning API key directly is temporary and MUST be replaced
        # before production deployment. This violates security guidelines.
        # TODO: Replace with actual ephemeral token API when available from OpenAI
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)

        logger.info(f"Created ephemeral token, expires at: {expires_at}")

        return TokenResponse(
            token=api_key,  # Temporary: replace with ephemeral token
            expires_at=expires_at,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to create ephemeral token: {str(e)}")
        raise HTTPException(status_code=500, detail="Token creation failed")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
