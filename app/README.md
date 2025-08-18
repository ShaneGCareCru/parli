# Parli Mobile App

Flutter mobile application for AI-powered voice translation.

## Prerequisites

- Flutter SDK (latest stable)
- Android Studio / Xcode
- Android device/emulator or iOS device/simulator

## Setup

```bash
# Install dependencies
flutter pub get

# Run on device/simulator
flutter run

# Build for platforms
flutter build android --debug
flutter build ios --debug --no-codesign
```

## Architecture

- **Target Platforms**: Android (API 21+), iOS (12+)
- **Package Name**: com.parli
- **WebRTC Integration**: Uses `flutter_webrtc` for low-latency audio
- **Audio Pipeline**: Push-to-talk interface with real-time processing

## Key Dependencies

- `flutter_webrtc`: WebRTC audio transport (primary)
- `web_socket_channel`: WebSocket fallback transport
- `http`: REST client for token service communication
- `provider`: State management for real-time sessions
- `logging`: Debug logging for transport connections

## Development

The app follows Flutter best practices:
- State management with Provider pattern
- Platform-specific audio handling (microphone permissions)
- WebRTC-first transport with automatic WebSocket fallback
- Ephemeral token authentication via backend service

### Transport Architecture

The app uses a dual-transport approach:

- **WebRTC (Primary)**: Low-latency peer connection for optimal audio quality
- **WebSocket (Fallback)**: Reliable connection for restrictive networks (China/Korea)
- **Automatic Failover**: Seamless switching when WebRTC connection fails
- **Manual Override**: Travel Mode forces WebSocket for problematic regions

### Audio Pipeline

- **Input**: 16kHz PCM16 mono audio from device microphone
- **Processing**: Echo cancellation, noise suppression, auto-gain control
- **Streaming**: Real-time audio chunks sent to OpenAI Realtime API
- **Output**: Streamed audio deltas for immediate playback

### Client Classes

- `WebRTCClient`: Primary low-latency transport implementation
- `WebSocketClient`: Fallback transport with automatic reconnection
- `TransportManager`: Orchestrates transport selection and failover

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests (when available)
flutter test integration_test/
```
