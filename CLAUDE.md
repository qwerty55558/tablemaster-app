# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**TableMaster App** is a Flutter application for table matching at events. It uses device-based authentication (not user accounts) and real-time WebSocket synchronization. The UI is in Korean. It targets Android, iOS, and Web platforms.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run on development (Android emulator or device)
flutter run --dart-define-from-file=.env.development

# Run on specific device
flutter run -d <device-id> --dart-define-from-file=.env.development

# Build web for production
flutter build web --release --dart-define-from-file=.env.production

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Lint and analyze
flutter analyze

# Format code
dart format lib/

# Docker build and run full stack
docker-compose up -d
```

## Architecture

### State Management
Riverpod (`flutter_riverpod`) is used throughout. All providers are defined in `lib/providers/providers.dart`:
- **Service providers** (singletons): `apiServiceProvider`, `authServiceProvider`, `webSocketServiceProvider`
- **StreamProviders** wrap the service streams: `authStatusProvider`, `tablesStreamProvider`, `myTableStreamProvider`, `wsConnectionProvider`
- **StateNotifierProviders** for mutable state: `TablesNotifier` (HTTP init + WebSocket delta updates), `CurrentTableNotifier`
- **Auto-dispose providers** for page-scoped state: `selectedTableProvider`, `setupFormProvider`

### Authentication Flow
`AuthService` manages device-based auth through a state machine: `initializing → unregistered → pending → authenticated/failed`.

1. App starts → `AuthService.initialize()` loads saved tokens and device ID
2. Calls `ApiService.initialize()` for HTTP verification
3. If approved: sets authenticated state, then connects WebSocket
4. If pending: polls `/auth/device/status` every 5 seconds until approved
5. If unregistered: shows registration UI on WelcomePage
6. `AuthenticatedClient` (http_client.dart) auto-refreshes tokens on 401

Device IDs are obtained via `device_info_plus` (Android/iOS) or generated via UUID (Web), then stored in `flutter_secure_storage`.

### Real-time Data (WebSocket)
`WebSocketService` uses STOMP over SockJS. On connect it sends a full table snapshot, then sends delta updates. Subscriptions:
- `/topic/tables` — broadcast table list (snapshot + deltas)
- `/user/queue/myTable` — current table updates
- `/user/queue/device` — device notifications (e.g., `DEVICE_DELETED`)

Reconnection uses exponential backoff (5s, 10s, 15s) with max 3 attempts, triggering token refresh before reconnect.

### Navigation Flow
```
WelcomePage (video screensaver, swipe-up gesture)
    ↓ if table not configured
SetupPage (multi-step form: name → location → guests → gender ratio)
    ↓ after setup
MatchingPage (sidebar table list + main detail view)
```

A global `navigatorKey` in `main.dart` enables navigation from within services (e.g., redirecting to WelcomePage on `DEVICE_DELETED`).

### Environment Configuration
Two env files drive runtime config via `flutter_dotenv`:
- `.env.development` — `API_HOST=10.0.2.2` (Android emulator gateway)
- `.env.production` — `API_HOST=api.clauminirockpt.me`, `USE_HTTPS=true`

`lib/config/api_config.dart` constructs all API base URLs and endpoint constants from these env vars.

### Key Design Decisions
- **No user auth**: authentication is device-tied; an admin must approve device registrations
- **HTTP + WebSocket dual stack**: HTTP for auth and initial data, WebSocket for real-time updates
- **Snapshot strategy**: `TablesNotifier` loads table list via HTTP on init, then applies WebSocket deltas
- **Dark theme only**: `lib/theme/app_colors.dart` defines the full dark palette; no light mode
- **Chat is not implemented**: `/user/queue/chat` subscription exists in `WebSocketService` but message handling is TODO


## Build
* 디벨롭 모드로 개발 중이니 빌드는 따로 하지 말 것 명령 이후 변경사항 요약만
* 임의로 커밋, 푸시 하지말 것