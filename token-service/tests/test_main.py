"""
Tests for the token service main module
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import os

from src.main import app

client = TestClient(app)


def test_health_check():
    """Test health check endpoint"""
    response = client.get("/healthz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data


@patch.dict(os.environ, {"OPENAI_API_KEY": "test_key"})
def test_create_ephemeral_token_success():
    """Test successful token creation"""
    response = client.post("/realtime/ephemeral")
    assert response.status_code == 200
    data = response.json()
    assert "token" in data
    assert "expires_at" in data


def test_create_ephemeral_token_no_api_key():
    """Test token creation without API key"""
    with patch.dict(os.environ, {}, clear=True):
        response = client.post("/realtime/ephemeral")
        assert response.status_code == 500
        assert "Service configuration error" in response.json()["detail"]
