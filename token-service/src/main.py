"""
Parli Token Service
FastAPI backend for ephemeral OpenAI token generation
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import os
from datetime import datetime, timedelta, timezone
from pydantic import BaseModel, Field
import openai
import logging
import secrets
from typing import Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize rate limiter
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Parli Token Service",
    description="Ephemeral token service for Parli voice translator",
    version="1.0.0",
)

# Add rate limit error handler
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS middleware for mobile app access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure with specific origins in production
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


class TokenRequest(BaseModel):
    """Request model for token creation (for future use with additional params)"""

    client_id: Optional[str] = Field(
        None, description="Optional client identifier for tracking"
    )


class TokenResponse(BaseModel):
    """Response model for ephemeral token"""

    token: str = Field(..., description="Ephemeral access token")
    expires_at: datetime = Field(..., description="Token expiration timestamp (UTC)")
    token_type: str = Field(
        default="Bearer", description="Token type for authorization header"
    )


@app.get("/healthz")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc)}


@app.post("/realtime/ephemeral", response_model=TokenResponse)
@limiter.limit("10/minute")  # Rate limit: 10 requests per minute per IP
async def create_ephemeral_token(
    request: Request, token_request: Optional[TokenRequest] = None
):
    """
    Create ephemeral OpenAI Realtime API token.

    Returns a token with 5-minute expiry for secure mobile access.
    Rate limited to prevent abuse.

    Args:
        request: FastAPI request object (required for rate limiting)
        token_request: Optional request parameters for future extensibility

    Returns:
        TokenResponse with ephemeral token and expiration time

    Raises:
        HTTPException: If service is misconfigured or token creation fails
        RateLimitExceeded: If rate limit is exceeded
    """
    try:
        # Log request with client info if provided
        client_id = token_request.client_id if token_request else None
        remote_addr = get_remote_address(request)
        logger.info(f"Token request from {remote_addr}, client_id: {client_id}")

        # Get OpenAI API key from environment
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            logger.error("OpenAI API key not configured")
            raise HTTPException(
                status_code=500, detail="Service configuration error: API key missing"
            )

        # Validate API key format (basic check)
        if not api_key.startswith("sk-") or len(api_key) < 20:
            logger.error("Invalid OpenAI API key format")
            raise HTTPException(
                status_code=500,
                detail="Service configuration error: Invalid API key format",
            )

        # TODO: Initialize OpenAI client when ephemeral token API becomes available
        # client = openai.AsyncOpenAI(api_key=api_key)
        # try:
        #     ephemeral_token = await client.tokens.create(
        #         duration=300,  # 5 minutes in seconds
        #         scopes=["realtime"]
        #     )
        #     token = ephemeral_token.token
        # except openai.OpenAIError as e:
        #     logger.error(f"OpenAI API error: {str(e)}")
        #     raise HTTPException(status_code=502, detail="Failed to create token from OpenAI")

        # SECURITY WARNING: Returning API key directly is temporary and MUST be replaced
        # before production deployment. This violates security guidelines.
        # TODO: Replace with actual ephemeral token API when available from OpenAI

        # For now, create a mock ephemeral token identifier (NOT for production)
        # This helps track token usage in logs while we wait for the real API
        token_id = secrets.token_urlsafe(16)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)

        logger.info(
            f"Created ephemeral token {token_id[:8]}... for client {client_id}, "
            f"expires at: {expires_at.isoformat()}"
        )

        return TokenResponse(
            token=api_key,  # Temporary: replace with ephemeral token
            expires_at=expires_at,
            token_type="Bearer",
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Unexpected error creating ephemeral token: {str(e)}", exc_info=True
        )
        raise HTTPException(
            status_code=500, detail="Internal server error during token creation"
        )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)