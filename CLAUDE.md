# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Parli is an AI-powered voice translator mobile application using OpenAI's Realtime API. The app enables real-time speech translation through a push-to-talk interface, designed specifically for business travelers in Asia.

## Key Architecture

### Core Design Principles
- **Realtime-first**: Uses OpenAI Realtime API directly rather than STT�MT�TTS pipeline
- **Half-duplex PTT**: Push-to-talk prevents echo/crosstalk on single device
- **Dual sessions**: Maintains two persistent Realtime sessions (A�B and B�A) to avoid context switching
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
- Support for EN�ZH-CN, EN�KO, EN�ES, EN�FR translation pairs
- Must handle network interruptions gracefully (China/Korea travel scenarios)

### Flutter Development
When implementing Flutter components:
- **Preferred Flutter Version**: Use Flutter 3.35.0 for all development and CI/CD pipelines
- Use proper state management (Provider, Riverpod, or Bloc pattern)
- Implement platform-specific audio permissions handling
- Ensure WebRTC implementation follows platform guidelines
- Test on both iOS and Android devices

### Backend Token Service (FastAPI)
When implementing the token service:
- **Technology Choice**: Use FastAPI with async/await patterns for optimal performance
- **Environment**: Use conda environments for Python dependency management
- **Docker Optimization**: Layer caching for efficient rebuilds during development
- Keep it stateless and lightweight
- Implement rate limiting and abuse prevention  
- Use environment variables for OpenAI API keys
- Return tokens with 5-minute expiry
- Include CORS configuration for mobile app access

### Audio Handling
- Implement proper echo cancellation
- Use platform-native audio session configuration
- Handle Bluetooth headset connection/disconnection
- Implement voice activity detection (VAD) for better UX

### Error Handling
- Implement exponential backoff for reconnection
- Provide clear network status indicators
- Cache successful connections for offline reference
- Handle WebRTC�WebSocket fallback transparently

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

## Linear-GitHub Integration for Claude Code

### Integration Status
- **Linear Workspace**: Parli
- **Linear Team**: Parli (team prefix: PAR)
- **GitHub Repository**: ShaneGCareCru/parli
- **Integration Type**: Two-way sync configured between GitHub and Linear

### Linear Project Structure
Work is organized under 11 Linear projects (EPICs A-K):
- EPIC A: Foundations & Repo Hygiene
- EPIC B: Token Service
- EPIC C: Realtime Sessions
- EPIC D: PTT Loop & Audio Pipeline
- EPIC E: Core UX & Settings
- EPIC F: Conversation Track & Storage
- EPIC G: Resilience & Limits
- EPIC H: Consent & Compliance
- EPIC I: Observability & Diagnostics
- EPIC J: Travel Mode & Preflight
- EPIC K: QA Harness & Release

### Claude Code Integration Guidelines

**CRITICAL RULE**: Claude MUST NEVER manually update Linear issue statuses to "Done" unless a GitHub PR has been created and merged. All work must follow the proper Git workflow.

When creating or working with Pull Requests, Claude MUST:

1. **MANDATORY: Create Branch and PR for ALL Work**:
   - ALWAYS create a feature branch before making changes
   - NEVER commit directly to main branch
   - Create GitHub PR linking to Linear issue before marking work complete
   - Pattern: Create branch → Make changes → Commit → Push → Create PR → Merge → Linear auto-completes

2. **Always Reference Linear Issues in PR Descriptions**:
   - Use magic words: `Fixes PAR-123`, `Closes PAR-456`, or `Refs PAR-789`
   - This automatically links the PR to the Linear issue
   - When PR merges, "Fixes" and "Closes" will auto-complete the Linear issue

3. **Include Linear Issue IDs in Commit Messages**:
   - Format: `feat: implement audio processing (PAR-45)`
   - Format: `fix: resolve WebRTC connection timeout, fixes PAR-67`
   - This creates commit-level linking for better traceability

4. **Leverage Automated Status Updates**:
   - Opening PRs will move linked Linear issues to "In Progress"
   - Merging PRs will move issues with "Fixes/Closes" to "Done"
   - NEVER manually update Linear issue statuses - let the PR workflow handle it

5. **When Creating Issues Programmatically**:
   - Create issues in Linear (they will auto-sync to GitHub if needed)
   - Assign to appropriate EPIC projects for better organization
   - Use team "Parli" as the target team

6. **Branch Naming Convention**:
   - Follow pattern: `feature/PAR-123-brief-description`
   - Use Linear issue numbers for consistency with integration
   - Example: `bugfix/PAR-89-webrtc-fallback-timeout`

7. **Cross-Platform Updates**:
   - Changes to issue titles, descriptions, assignees, and labels sync both ways
   - Comments made in Linear sync threads will appear in GitHub
   - GitHub issue updates will reflect in corresponding Linear issues

### Integration Benefits for Development
- Automatic issue status progression based on development workflow
- Centralized tracking of development progress across both platforms  
- Linkback comments provide context in both GitHub PRs and Linear issues
- Unified view of code changes and project management in Linear interface

## Mono-Repo Development Guidelines

### Repository Structure
```
parli/
├── app/                    # Flutter mobile application
│   ├── lib/               # Dart source code
│   ├── android/           # Android platform code
│   ├── ios/               # iOS platform code
│   └── test/              # Flutter tests
├── token-service/         # FastAPI backend service
│   ├── src/               # Python source code
│   ├── tests/             # Python tests
│   └── Dockerfile         # Container configuration
├── docs/                  # Architecture and development docs
├── scripts/               # Development automation scripts
├── .github/workflows/     # CI/CD pipeline definitions
└── docker-compose.yml     # Local development environment
```

### Development Workflow

#### Local Environment Setup
1. **Quick Start**: Run `./scripts/dev-setup.sh` for automated setup
2. **Manual Setup**: 
   ```bash
   # Backend service
   cp token-service/.env.example token-service/.env
   # Edit .env with OpenAI API key
   docker compose up -d
   
   # Flutter app
   cd app/ && flutter pub get && flutter run
   ```

#### Code Quality Standards
- **Flutter**: Use `flutter analyze`, `dart format`, and `flutter test`
- **Python**: Use `black`, `isort`, `flake8`, and `pytest`
- **CI/CD**: GitHub Actions automatically enforce quality gates on PRs

#### Testing Strategy
- **Flutter**: Unit tests in `app/test/`, widget tests for UI components
- **Backend**: Unit tests in `token-service/tests/`, FastAPI TestClient for API testing
- **Integration**: Docker-based testing for full system validation
- **Performance**: Latency measurement tests for P50 ≤ 1.6s, P95 ≤ 2.3s targets

#### Security Practices
- **Secrets Management**: All keys via `.env` files (never committed)
- **Mobile Security**: No API keys in Flutter app bundle
- **Backend Security**: Rate limiting, CORS, input validation
- **Development**: Use `.env.example` files with mock/placeholder values

### Claude Code Integration Guidelines

When working with this mono-repo, Claude should:

1. **Project Context Awareness**:
   - Understand that changes may affect both Flutter app and Python backend
   - Consider cross-component implications (API contracts, data models)
   - Reference architecture docs in `docs/` for design decisions

2. **Build and Test Commands**:
   - **Flutter**: `cd app && flutter test && flutter build apk --debug`
   - **Backend**: `cd token-service && pytest && python src/main.py`
   - **Full System**: `docker compose up` for integrated testing

3. **Development Environment**:
   - Always check `.env` configuration before backend development
   - Use `flutter doctor` to verify Flutter SDK setup
   - Prefer conda environments for Python development consistency

4. **Code Generation and Scaffolding**:
   - Follow existing patterns in `app/lib/` for Flutter code structure
   - Use FastAPI conventions in `token-service/src/` for backend code
   - Update both component READMEs when adding new features

5. **Documentation Updates**:
   - Update `docs/ARCHITECTURE.md` for design changes
   - Update `docs/DEVELOPMENT.md` for new development practices
   - Keep component-specific READMEs current

### Performance and Quality Targets

- **Build Times**: Flutter builds ≤ 2 minutes, Backend builds ≤ 30 seconds
- **Test Coverage**: ≥ 80% for business logic components
- **Latency**: Real-time translation P50 ≤ 1.6s, P95 ≤ 2.3s
- **Code Quality**: Pass all linting and analysis checks in CI/CD

## Project Documentation
- **PRD.md**: Complete product requirements and specifications
- **TASKLIST.md**: Development backlog with story points and sprint planning
- **docs/ARCHITECTURE.md**: Technical architecture and design decisions
- **docs/DEVELOPMENT.md**: Development practices and guidelines