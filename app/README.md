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
- `http`: REST client for token service
- Additional dependencies will be added as features are implemented

## Development

The app follows Flutter best practices:
- State management with Provider/Riverpod
- Platform-specific audio handling
- WebRTC-first with WebSocket fallback
- Ephemeral token authentication

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests (when available)
flutter test integration_test/
```
