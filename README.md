# Parli - AI Voice Translator

Real-time voice translation app using OpenAI's Realtime API, designed for business travelers in Asia.

## 🚀 Quick Start

```bash
# Prerequisites: Flutter SDK, Docker, Git
git clone <repository>
cd parli

# Automated setup (recommended)
./scripts/dev-setup.sh

# Manual setup
cp token-service/.env.example token-service/.env
# Edit .env with your OpenAI API key

# Start backend service
docker compose up -d --build

# Start Flutter app (separate terminal)
cd app/
flutter run
```

## 📁 Project Structure

```
parli/
├── app/                    # Flutter mobile application
├── token-service/          # Backend API service for ephemeral tokens
├── docs/                   # Project documentation
├── scripts/                # Build and deployment scripts
├── docker-compose.yml      # Local development setup
├── .gitignore             # Combined gitignore
└── README.md              # This file
```

## 🏗️ Architecture Overview

### Core Components

- **Mobile App** (Flutter): Cross-platform iOS/Android with push-to-talk interface
- **Token Service** (FastAPI): Secure backend for ephemeral OpenAI token generation
- **Realtime Sessions**: Dual WebRTC/WebSocket connections for A↔B and B↔A translation

### Key Design Principles

- **Realtime-first**: Direct OpenAI Realtime API integration (no STT→MT→TTS pipeline)
- **Half-duplex PTT**: Push-to-talk prevents echo/crosstalk on single device  
- **Dual sessions**: Maintains two persistent sessions to avoid context switching
- **WebRTC primary**: Low latency with WebSocket fallback for resilience
- **Ephemeral auth**: No API keys stored in mobile app

## 📱 Development

### Prerequisites

- Flutter SDK (latest stable)
- Docker & Docker Compose
- OpenAI API key
- Android Studio / Xcode (for mobile development)

### Getting Started

1. **Clone and setup**:
   ```bash
   git clone <repository>
   cd parli
   ./scripts/dev-setup.sh
   ```

2. **Configure API key**:
   ```bash
   # Edit token-service/.env
   OPENAI_API_KEY=your_openai_api_key_here
   ```

3. **Start development**:
   ```bash
   # Terminal 1: Backend service
   docker compose up

   # Terminal 2: Flutter app
   cd app/
   flutter run
   ```

### Component Development

- **Flutter App**: See [app/README.md](app/README.md) for mobile development
- **Token Service**: See [token-service/README.md](token-service/README.md) for backend API
- **Architecture Details**: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 🎯 Supported Languages

- English ↔ Simplified Chinese (EN↔ZH-CN)
- English ↔ Korean (EN↔KO)  
- English ↔ Spanish (EN↔ES)
- English ↔ French (EN↔FR)

## 📊 Performance Targets

- **Latency**: P50 ≤ 1.6s, P95 ≤ 2.3s (end-to-start)
- **Availability**: Graceful network interruption handling
- **Audio Quality**: Echo cancellation, noise suppression

## 🔐 Security

- API keys never stored in mobile app
- Ephemeral tokens with 5-minute expiry
- Certificate pinning for token service
- Encrypted local storage for cached data

## 📖 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Development Guidelines](docs/DEVELOPMENT.md)  
- [Product Requirements](PRD.md)
- [Task Backlog](TASKLIST.md)
- [Claude Code Integration](CLAUDE.md)

## 🧪 Testing

```bash
# Flutter app tests
cd app/
flutter test

# Token service tests  
cd token-service/
pytest

# End-to-end testing
# See docs/TESTING.md for integration test setup
```

## 📋 Development Workflow

1. **Feature Development**: Work on Linear issues (PAR-*) linked to GitHub PRs
2. **Branch Naming**: `feature/PAR-123-brief-description`
3. **Commit Format**: `feat: implement feature (PAR-123)`
4. **Pull Requests**: Include "Fixes PAR-123" for auto-completion

## 🚢 Deployment

- **Beta**: Internal distribution via TestFlight/Internal App Sharing
- **Production**: App Store/Play Store release
- **Backend**: Containerized deployment with secrets management

## 🆘 Troubleshooting

### Common Issues

**Flutter won't build:**
```bash
cd app/
flutter clean
flutter pub get
flutter doctor  # Check for missing dependencies
```

**Token service health check fails:**
```bash
# Check if API key is set
grep OPENAI_API_KEY token-service/.env

# View service logs
docker compose logs token-service
```

**Network connectivity issues:**
- Enable "Travel Mode" in app settings for China/Korea
- WebRTC fallback to WebSocket should be automatic

### Getting Help

- Project documentation in `/docs`
- Linear workspace: Issues and tracking
- GitHub: Code reviews and CI/CD

---

*Built with Flutter, FastAPI, and OpenAI Realtime API*