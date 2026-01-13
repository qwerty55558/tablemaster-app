# Riverpod 상태 관리 마이그레이션

---

## 개요

Flutter 앱에서 **상태(State)**는 UI를 그리는 데 필요한 모든 데이터를 의미한다.
버튼 클릭 횟수, 로그인 여부, 서버에서 받아온 테이블 목록 등이 모두 상태다.

> **핵심 질문**
> - 어디에 상태를 저장할 것인가?
> - 어떻게 상태 변경을 UI에 반영할 것인가?
> - 언제 상태를 정리(dispose)할 것인가?

---

## 레거시 vs Riverpod 비교

### 레거시: Singleton + StreamController + setState

```
Service (Singleton)          StatefulWidget
┌─────────────────┐          ┌─────────────────────┐
│ _controller     │──Stream─▶│ StreamSubscription  │
│ _state          │          │ mounted check       │
│                 │          │ setState()          │
└─────────────────┘          └─────────────────────┘
      │                              │
      ▼                              ▼
 앱 전체 생명주기              위젯 생명주기에 묶임
 (수동 dispose)               (dispose에서 cancel)
```

**문제점**

| 문제 | 설명 |
|------|------|
| Boilerplate | 모든 StatefulWidget마다 subscription, dispose 반복 |
| mounted 체크 | 비동기 후 `if (mounted)` 빠뜨리면 에러 |
| 테스트 어려움 | Singleton은 mock 주입 불가 |
| 추적 어려움 | 상태 변경 흐름 파악 힘듦 |

---

### Riverpod 방식

```
Provider                     ConsumerWidget
┌─────────────────┐          ┌─────────────────────┐
│ 자동 캐싱       │◀─watch──│ ref.watch (구독)    │
│ 자동 정리       │          │ ref.read (1회)      │
│ 의존성 추적     │          │ ref.listen (효과)   │
└─────────────────┘          └─────────────────────┘
      │                              │
      ▼                              ▼
 ProviderScope 관리            자동 구독/해제
 (autoDispose 지원)           (mounted 체크 불필요)
```

**장점**

| 장점 | 설명 |
|------|------|
| 간결함 | `ref.watch()`만으로 구독 완료 |
| 안전함 | 생명주기 자동 추적 |
| 테스트 | `overrides`로 mock 주입 |
| 명확함 | Provider 정의만 보면 흐름 파악 |

---

## Riverpod 핵심 개념

### Provider 종류

| Provider | 용도 | 예시 |
|----------|------|------|
| `Provider` | 읽기 전용 값 | 서비스 인스턴스 |
| `StateProvider` | 단순 상태 | bool, 선택된 항목 |
| `StateNotifierProvider` | 복잡한 상태 + 로직 | 폼, 리스트 |
| `StreamProvider` | Stream → Provider | WebSocket 데이터 |
| `FutureProvider` | Future → Provider | API 호출 |

---

### ref 사용법

**ref.watch** - 값 구독 (build 내에서)
```dart
final tables = ref.watch(tablesProvider);
// 변경 시 자동 리빌드
```

**ref.read** - 1회성 읽기 (이벤트 핸들러)
```dart
onPressed: () {
  ref.read(counterProvider.notifier).increment();
}
```

**ref.listen** - Side effect (토스트, 네비게이션)
```dart
ref.listen(errorProvider, (prev, next) {
  showToast(context, next);
});
```

---

### autoDispose

```dart
// 위젯 dispose 시 Provider도 자동 정리
final selectedTableProvider = StateProvider.autoDispose<TableModel?>((ref) => null);

// 일반 Provider - 앱 전체 생명주기
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
```

---

## 마이그레이션 상세

### 파일 구조

```
lib/
├── providers/
│   └── providers.dart      ← 모든 Provider 정의
├── pages/
│   ├── matching_page.dart  ← ConsumerStatefulWidget
│   ├── setup_page.dart     ← ConsumerWidget
│   └── welcome_page.dart   ← ConsumerStatefulWidget
├── main.dart               ← ProviderScope 래핑
└── services/               ← 기존 유지 (Provider로 래핑)
```

---

### Provider 정의

**Service Providers**
```dart
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return ref.watch(apiServiceProvider).authService;
});
```

**Stream Providers**
```dart
final authStatusProvider = StreamProvider<AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.statusStream;
});
```

**StateNotifier**
```dart
class TablesNotifier extends StateNotifier<List<TableModel>> {
  TablesNotifier(this._apiService, this._wsService) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // HTTP로 초기 데이터
    state = await _apiService.getTables();
    // WebSocket으로 실시간 업데이트
    _wsService.tablesStream.listen((tables) => state = tables);
  }
}
```

---

### 위젯 변환

**Before**
```dart
class MatchingPage extends StatefulWidget { ... }

class _MatchingPageState extends State<MatchingPage> {
  StreamSubscription? _subscription;
  List<TableModel> _tables = [];

  @override
  void initState() {
    _subscription = service.stream.listen((data) {
      if (mounted) setState(() => _tables = data);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

**After**
```dart
class MatchingPage extends ConsumerStatefulWidget { ... }

class _MatchingPageState extends ConsumerState<MatchingPage> {
  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider);
    // 끝. 구독/해제 자동.
  }
}
```

---

## 해결된 문제

### 1. 초기 데이터 미사용

| Before | After |
|--------|-------|
| WebSocket만 구독 → 연결 전 빈 목록 | HTTP로 먼저 fetch → WebSocket 구독 |

### 2. 테이블 설정 후 동기화

| Before | After |
|--------|-------|
| `setupTable()` 후 다른 위젯에 반영 안됨 | `CurrentTableNotifier`로 중앙 관리 |

### 3. 선택 상태 지속

| Before | After |
|--------|-------|
| 페이지 나갔다 와도 이전 선택 유지 | `autoDispose`로 자동 정리 |

---

## 체크리스트

- [x] flutter_riverpod 패키지 추가
- [x] providers/providers.dart 생성
- [x] main.dart ProviderScope 래핑
- [x] main.dart ConsumerStatefulWidget 전환
- [x] MatchingPage 전환
- [x] SetupPage 전환 (SetupFormNotifier)
- [x] WelcomePage 전환
- [x] 데이터 누락 문제 해결
- [x] flutter analyze 검증 (에러/경고 0)

---

## 참고

- [Riverpod 공식 문서](https://riverpod.dev/)
- [Provider → Riverpod 마이그레이션](https://riverpod.dev/docs/from_provider/motivation)
- [StateNotifier 패턴](https://riverpod.dev/docs/providers/state_notifier_provider)
