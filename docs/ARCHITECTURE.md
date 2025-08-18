# Parli Architecture

## Overview

Parli is a real-time voice translation application built around OpenAI's Realtime API, optimized for business travelers requiring quick, accurate translation in challenging network environments.

## Core Architecture Principles

### 1. Realtime-First Design
- **Direct API Integration**: Uses OpenAI Realtime API directly, avoiding traditional STT→MT→TTS pipeline
- **Persistent Connections**: Maintains WebRTC/WebSocket connections for continuous audio streaming
- **Minimal Latency**: Target P50 ≤ 1.6s, P95 ≤ 2.3s end-to-start translation

### 2. Dual Session Architecture
```
Mobile App
├── Session A→B (English → Chinese)
│   ├── WebRTC Primary Connection
│   └── WebSocket Fallback
└── Session B→A (Chinese → English)
    ├── WebRTC Primary Connection
    └── WebSocket Fallback
```

**Benefits:**
- No context switching between language pairs
- Independent connection health per direction
- Parallel processing capability

### 3. Transport Layer Strategy

**Primary**: WebRTC for low latency
- Direct peer connection to OpenAI
- Minimal overhead, optimal for good networks
- Hardware audio processing integration

**Fallback**: WebSocket for resilience
- Works through restrictive firewalls
- Better for high-latency networks (China, Korea)
- Automatic failover on WebRTC issues

## System Components

### Mobile Application (Flutter)

**Core Modules:**
- `RealtimeSession`: Manages OpenAI connections
- `AudioPipeline`: PTT capture and playback
- `TransportManager`: WebRTC/WS switching
- `TokenClient`: Ephemeral token management

**State Management:**
- Provider/Riverpod pattern for reactive UI
- Persistent settings storage
- Session lifecycle management

**Platform Integration:**
- iOS: AVAudioSession configuration
- Android: AudioManager integration
- Bluetooth headset support
- Background audio handling

### Token Service (FastAPI)

**Purpose**: Secure intermediary for OpenAI API access

**Endpoints:**
- `GET /healthz`: Service health check
- `POST /realtime/ephemeral`: Generate short-lived tokens

**Security Features:**
- API keys never exposed to mobile app
- 5-minute token expiry
- Rate limiting by IP/user
- CORS configuration for mobile origins

**Deployment:**
- Containerized with Docker
- Stateless for horizontal scaling
- Environment-based configuration

## Audio Processing Pipeline

### Input (Push-to-Talk)
1. **Capture**: Platform-native audio session
2. **Processing**: Echo cancellation, noise reduction
3. **Encoding**: PCM16 format for Realtime API
4. **Streaming**: Real-time transmission to active session

### Output (Translation Playback)
1. **Reception**: Audio deltas from Realtime API
2. **Buffering**: Jitter buffer for smooth playback
3. **Decoding**: Real-time audio reconstruction
4. **Playback**: Hardware-optimized output

## Network Resilience

### Connection Management
- Health monitoring with exponential backoff
- Graceful degradation (WebRTC → WebSocket)
- Session persistence across network changes
- Automatic reconnection with state recovery

### Geographic Considerations
- **Travel Mode**: Prefer WebSocket in restricted regions
- **Adaptive Routing**: Dynamic transport selection
- **Offline Handling**: Clear indicators when disconnected

## Security Architecture

### Authentication Flow
```
Mobile App → Token Service → OpenAI Realtime API
    ↓            ↓                ↓
  No Keys    API Key Secure   Ephemeral Token
```

### Data Protection
- No persistent storage of audio data
- Optional encrypted transcript caching (30-day TTL)
- Certificate pinning for token service
- No telemetry data contains sensitive content

## Performance Optimization

### Latency Targets
- **Audio Capture → First Response**: ≤ 1.6s (P50)
- **End-to-End Translation**: ≤ 2.3s (P95)
- **Transport Failover**: ≤ 500ms recovery

### Memory Management
- Streaming audio buffers (no full file caching)
- Session connection pooling
- Garbage collection optimization for real-time processing

### Battery Optimization
- Audio session suspension when inactive
- Background processing limits
- Efficient WebRTC implementation

## Monitoring and Observability

### Client-Side Metrics
- Translation latency (P50/P95)
- Transport switch events
- Error rates by type
- Battery and network usage

### Server-Side Metrics
- Token generation rate
- Health check response times
- API key usage tracking
- Rate limit violations

## Development Architecture

### Mono-Repo Structure
```
parli/
├── app/              # Flutter application
├── token-service/    # FastAPI backend
├── docs/            # Architecture docs
└── scripts/         # Development tools
```

### CI/CD Pipeline
- GitHub Actions for build automation
- Flutter: Android APK + iOS IPA generation
- Backend: Container image building and testing
- Automated testing on PR submission

### Quality Gates
- Unit tests for core logic
- Integration tests for API contracts
- Performance regression testing
- Manual QA checklist for releases

## Scalability Considerations

### Current Scope
- Single-user mobile application
- Stateless token service
- Direct OpenAI API consumption

### Future Extensibility
- Multi-user session support
- Custom model fine-tuning
- Enterprise deployment options
- Additional language pairs

This architecture prioritizes **reliability**, **performance**, and **security** for the initial business traveler use case while maintaining flexibility for future enhancement.