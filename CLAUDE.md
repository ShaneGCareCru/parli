# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Parli is an AI-powered voice translator mobile application using OpenAI's Realtime API. The app enables real-time speech translation through a push-to-talk interface, designed specifically for business travelers in Asia.

## Key Architecture

### Core Design Principles
- **Realtime-first**: Uses OpenAI Realtime API directly rather than STT’MT’TTS pipeline
- **Half-duplex PTT**: Push-to-talk prevents echo/crosstalk on single device
- **Dual sessions**: Maintains two persistent Realtime sessions (A’B and B’A) to avoid context switching
- **WebRTC primary**: Uses WebRTC for low latency with WebSocket fallback for resilience
- **Ephemeral auth**: Backend token service mints short-lived tokens for API access

### Technology Stack
- **Mobile App**: Flutter (targets Android/iOS)
- **Backend**: Token service (FastAPI or Express.js)
- **Audio Transport**: WebRTC (primary) with WebSocket fallback
- **Translation**: OpenAI Realtime API with GPT-4o

## Development Guidelines

### Performance Requirements
- Latency targets: P50 d 1.6s, P95 d 2.3s end-to-start
- Support for EN”ZH-CN, EN”KO, EN”ES, EN”FR translation pairs
- Must handle network interruptions gracefully (China/Korea travel scenarios)

### Flutter Development
When implementing Flutter components:
- Use proper state management (Provider, Riverpod, or Bloc pattern)
- Implement platform-specific audio permissions handling
- Ensure WebRTC implementation follows platform guidelines
- Test on both iOS and Android devices

### Backend Token Service
When implementing the token service:
- Keep it stateless and lightweight
- Implement rate limiting and abuse prevention
- Use environment variables for OpenAI API keys
- Return tokens with 5-minute expiry
- Include CORS configuration for web testing

### Audio Handling
- Implement proper echo cancellation
- Use platform-native audio session configuration
- Handle Bluetooth headset connection/disconnection
- Implement voice activity detection (VAD) for better UX

### Error Handling
- Implement exponential backoff for reconnection
- Provide clear network status indicators
- Cache successful connections for offline reference
- Handle WebRTC’WebSocket fallback transparently

## Testing Strategy

### Unit Testing
- Test audio processing pipelines
- Test network fallback logic
- Test token refresh mechanisms

### Integration Testing
- Test end-to-end translation flow
- Test network interruption scenarios
- Test session persistence across app lifecycle

### Performance Testing
- Measure actual latencies against targets
- Test under various network conditions
- Profile memory usage during long sessions

## Security Considerations
- Never store OpenAI API keys in mobile app
- Implement certificate pinning for token service
- Use encrypted storage for any cached data
- Implement proper session cleanup on app termination

## Project Documentation
- **PRD.md**: Complete product requirements and specifications
- **TASKLIST.md**: Development backlog with story points and sprint planning