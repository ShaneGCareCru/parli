# Parli Token Service

FastAPI backend service for generating ephemeral OpenAI Realtime API tokens.

## Prerequisites

- Python 3.11+
- OpenAI API key
- Docker (optional)

## Local Development

### Setup with Conda (Recommended)

```bash
# Create conda environment
conda create -n parli-token-service python=3.11
conda activate parli-token-service

# Install dependencies
pip install -r requirements.txt
```

### Environment Configuration

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your OpenAI API key
OPENAI_API_KEY=your_openai_api_key_here
```

### Run Locally

```bash
# Start development server with hot reload
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Or run directly
python src/main.py
```

### Run with Docker

```bash
# Build image
docker build -t parli-token-service .

# Run container
docker run -p 8000:8000 --env-file .env parli-token-service
```

## API Endpoints

### Health Check
```
GET /healthz
```
Returns service health status.

### Create Ephemeral Token
```
POST /realtime/ephemeral
```
Returns ephemeral OpenAI token for Realtime API access.

Response:
```json
{
  "token": "ephemeral_token_here",
  "expires_at": "2023-12-01T12:05:00Z"
}
```

## Security Features

- CORS configured for mobile app access
- Ephemeral tokens with 5-minute expiry
- No API keys stored in mobile app
- Rate limiting (to be implemented)

## Development Commands

```bash
# Run tests
pytest

# Code formatting
black src/ tests/
isort src/ tests/

# Linting
flake8 src/ tests/
```

## Architecture Notes

- **Stateless**: No persistent storage required
- **Lightweight**: Minimal dependencies for fast startup
- **Secure**: API keys never leave server environment
- **Resilient**: Proper error handling and logging