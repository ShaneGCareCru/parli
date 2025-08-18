# Development Guidelines

## Overview

This guide covers development practices, coding standards, and workflows for the Parli project.

## Development Environment Setup

### Prerequisites
- Flutter SDK (latest stable channel)
- Python 3.11+ with conda/virtualenv
- Docker and Docker Compose
- Git with GitHub CLI (optional but recommended)
- Android Studio / Xcode for mobile development

### Quick Setup
```bash
# Clone and setup environment
git clone <repository>
cd parli
./scripts/dev-setup.sh

# Configure secrets
cp token-service/.env.example token-service/.env
# Edit .env with your OpenAI API key
```

## Project Structure Guidelines

### Directory Organization
```
parli/
├── app/                    # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart      # Entry point
│   │   ├── models/        # Data models
│   │   ├── services/      # Business logic
│   │   ├── ui/            # Screens and widgets
│   │   └── utils/         # Helper functions
│   └── test/              # Flutter tests
├── token-service/         # FastAPI backend
│   ├── src/
│   │   ├── main.py        # FastAPI application
│   │   ├── models/        # Pydantic models
│   │   └── services/      # Business logic
│   └── tests/             # Python tests
└── docs/                  # Documentation
```

## Coding Standards

### Flutter (Dart)
```dart
// Use descriptive names and follow Dart conventions
class RealtimeSessionManager {
  // Private members with underscore prefix
  final OpenAIClient _client;
  
  // Public interface with clear documentation
  /// Establishes connection to OpenAI Realtime API
  Future<RealtimeSession> connect(String token) async {
    // Implementation
  }
}

// State management pattern
class TranslationProvider extends ChangeNotifier {
  // Use immutable state where possible
  TranslationState get state => _state;
  
  // Clear action methods
  Future<void> startTranslation(String text) async {
    // Implementation with proper error handling
  }
}
```

### Python (FastAPI)
```python
# Type hints for all functions
async def create_ephemeral_token() -> TokenResponse:
    """
    Create ephemeral OpenAI token with 5-minute expiry.
    
    Returns:
        TokenResponse: Token and expiration details
        
    Raises:
        HTTPException: On API key configuration issues
    """
    pass

# Use Pydantic models for validation
class TokenResponse(BaseModel):
    token: str
    expires_at: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
```

## Git Workflow

### Branch Naming
- Feature branches: `feature/PAR-123-brief-description`
- Bug fixes: `bugfix/PAR-456-fix-connection-timeout`
- Hotfixes: `hotfix/PAR-789-critical-security-fix`

### Commit Messages
Follow the Linear integration format:
```bash
git commit -m "feat: implement audio processing pipeline (PAR-45)

- Add WebRTC audio capture
- Implement jitter buffer for smooth playback
- Add fallback to WebSocket transport

Fixes PAR-45"
```

### Pull Request Process
1. **Create PR** with Linear issue reference in description
2. **Code Review** by at least one team member  
3. **CI/CD Checks** must pass (build, test, lint)
4. **Merge** with squash to maintain clean history

## Testing Strategy

### Flutter Testing
```dart
// Unit tests for business logic
void main() {
  group('RealtimeSessionManager', () {
    test('should connect successfully with valid token', () async {
      // Arrange
      final manager = RealtimeSessionManager();
      const token = 'valid_token';
      
      // Act
      final session = await manager.connect(token);
      
      // Assert
      expect(session.isConnected, isTrue);
    });
  });
}

// Widget tests for UI components
void main() {
  testWidgets('PTT button shows recording state', (tester) async {
    await tester.pumpWidget(MyApp());
    await tester.tap(find.byType(PTTButton));
    await tester.pump();
    
    expect(find.text('Recording...'), findsOneWidget);
  });
}
```

### Python Testing
```python
# FastAPI testing with TestClient
def test_health_check():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

@patch.dict(os.environ, {"OPENAI_API_KEY": "test_key"})
def test_create_ephemeral_token():
    response = client.post("/realtime/ephemeral")
    assert response.status_code == 200
    assert "token" in response.json()
```

## Code Quality Tools

### Flutter
```bash
# Analysis and formatting
flutter analyze
dart format lib/ test/

# Testing
flutter test
flutter test --coverage
```

### Python
```bash
# Formatting and linting
black src/ tests/
isort src/ tests/
flake8 src/ tests/

# Testing
pytest
pytest --cov=src tests/
```

## Performance Guidelines

### Flutter Performance
- **State Management**: Use Provider/Riverpod, avoid excessive rebuilds
- **Audio Processing**: Leverage platform-native APIs
- **Memory**: Dispose controllers and streams properly
- **Battery**: Suspend audio sessions when inactive

### Backend Performance
- **Async/Await**: Use async handlers for I/O operations
- **Connection Pooling**: Reuse HTTP connections where possible
- **Caching**: Cache ephemeral tokens appropriately
- **Monitoring**: Log performance metrics

## Security Practices

### Mobile App
- **No Secrets**: Never store API keys in app bundle
- **Certificate Pinning**: Pin token service certificates
- **Local Storage**: Encrypt sensitive cached data
- **Permissions**: Request minimal required permissions

### Backend Service
- **Environment Variables**: All secrets via environment
- **Rate Limiting**: Prevent API abuse
- **CORS**: Configure specific allowed origins
- **Input Validation**: Validate all request parameters

## Debugging and Development Tools

### Flutter Debugging
```bash
# Run with debugging enabled
flutter run --debug

# Performance profiling
flutter run --profile
flutter run --release --trace-startup

# Device logs
flutter logs
```

### Backend Debugging
```bash
# Development server with hot reload
uvicorn src.main:app --reload --log-level debug

# Container debugging
docker-compose logs -f token-service
docker-compose exec token-service /bin/bash
```

## Integration with Linear/GitHub

### Issue Linking
- Reference Linear issues in PRs: `Fixes PAR-123`
- Use issue numbers in branch names: `feature/PAR-123-*`
- Include issue context in commit messages

### Automated Workflows
- PRs automatically move Linear issues to "In Progress"
- Merged PRs with "Fixes" keyword complete Linear issues
- Branch names sync with Linear issue tracking

## Release Process

### Version Management
- **Semantic Versioning**: Major.Minor.Patch (e.g., 1.2.3)
- **Flutter**: Update `pubspec.yaml` version
- **Backend**: Tag Docker images with version

### Release Checklist
1. **Code Review**: All features reviewed and approved
2. **Testing**: Unit, integration, and manual testing complete
3. **Performance**: Latency targets verified (P50 ≤ 1.6s, P95 ≤ 2.3s)
4. **Documentation**: Update user-facing docs
5. **Deployment**: Beta testing before production release

## Monitoring and Observability

### Development Metrics
- Build times and success rates
- Test coverage percentages
- Code quality scores (complexity, duplication)

### Runtime Metrics
- Translation latency measurements
- Error rates by component
- Network transport usage patterns

This development guide ensures consistent, high-quality code across the Parli project while maintaining rapid iteration capabilities.