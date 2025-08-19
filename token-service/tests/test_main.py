"""
Tests for the token service main module
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import os
from datetime import datetime, timezone

from src.main import app, TokenRequest

client = TestClient(app)


def test_health_check():
    """Test health check endpoint"""
    response = client.get("/healthz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data


@patch.dict(os.environ, {"OPENAI_API_KEY": "sk-test_key_1234567890abcdef"})
def test_create_ephemeral_token_success():
    """Test successful token creation"""
    response = client.post("/realtime/ephemeral")
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert "expires_at" in data
    assert "token_type" in data
    assert data["token_type"] == "Bearer"

    # Verify expiration time is approximately 5 minutes from now
    expires_at = datetime.fromisoformat(data["expires_at"].replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    time_diff = (expires_at - now).total_seconds()
    assert 295 <= time_diff <= 305  # Within 5 seconds of 5 minutes


def test_create_ephemeral_token_no_api_key():
    """Test token creation without API key"""
    with patch.dict(os.environ, {}, clear=True):
        response = client.post("/realtime/ephemeral")
        assert response.status_code == 500
        assert "API key missing" in response.json()["detail"]


@patch.dict(os.environ, {"OPENAI_API_KEY": "invalid_key"})
def test_create_ephemeral_token_invalid_api_key_format():
    """Test token creation with invalid API key format"""
    response = client.post("/realtime/ephemeral")
    assert response.status_code == 500
    assert "Invalid API key format" in response.json()["detail"]


@patch.dict(os.environ, {"OPENAI_API_KEY": "sk-test_key_1234567890abcdef"})
def test_create_ephemeral_token_with_client_id():
    """Test token creation with optional client_id"""
    response = client.post("/realtime/ephemeral", json={"client_id": "mobile-app-v1.0"})
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert "expires_at" in data
    assert "token_type" in data


@patch.dict(os.environ, {"OPENAI_API_KEY": "sk-test_key_1234567890abcdef"})
def test_rate_limiting_configuration():
    """Test that rate limiting is properly configured"""
    from src.main import create_ephemeral_token, limiter
    
    # Verify the rate limiter is configured
    assert limiter is not None, "Rate limiter should be configured"
    
    # Verify the endpoint has rate limiting decorator applied
    # Check if the function has been wrapped by the decorator
    assert hasattr(create_ephemeral_token, '__wrapped__'), "Rate limiting decorator should be applied"
    
    # Test normal operation (should not hit rate limit in single request)
    response = client.post("/realtime/ephemeral")
    assert response.status_code == 200


@patch.dict(os.environ, {"OPENAI_API_KEY": "sk-test_key_1234567890abcdef"})
def test_rate_limiting_integration():
    """Test rate limiting integration with FastAPI"""
    from src.main import app
    from slowapi import Limiter
    
    # Verify the app has the limiter configured
    assert hasattr(app.state, 'limiter'), "App should have limiter configured"
    assert isinstance(app.state.limiter, Limiter), "App limiter should be Limiter instance"
    
    # Test that multiple requests work (within rate limit)
    responses = []
    for i in range(3):  # Well within the 10/minute limit
        response = client.post("/realtime/ephemeral")
        responses.append(response)
        assert response.status_code == 200
    
    # All requests should succeed
    assert all(r.status_code == 200 for r in responses)