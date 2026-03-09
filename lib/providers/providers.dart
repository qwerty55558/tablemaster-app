import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../models/table_model.dart';

// ============================================================
// Service Providers (싱글톤 서비스 래핑)
// ============================================================

/// ApiService Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// AuthService Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return ref.watch(apiServiceProvider).authService;
});

/// WebSocketService Provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

// ============================================================
// Auth State Providers
// ============================================================

/// 인증 상태 스트림 Provider
final authStatusProvider = StreamProvider<AuthStatus>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.statusStream;
});

/// 현재 인증 상태 (동기)
final currentAuthStatusProvider = Provider<AuthStatus>((ref) {
  final asyncStatus = ref.watch(authStatusProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => ref.read(authServiceProvider).status,
    error: (_, __) => AuthStatus.failed,
  );
});

/// 인증 에러 메시지
final authErrorProvider = Provider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.errorMessage;
});

// ============================================================
// WebSocket State Providers
// ============================================================

/// WebSocket 연결 상태 스트림
final wsConnectionProvider = StreamProvider<WebSocketConnectionResult>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.connectionResultStream;
});

/// 테이블 목록 스트림 Provider (WebSocket)
final tablesStreamProvider = StreamProvider<List<TableModel>>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.tablesStream;
});


/// 알림 스트림
final notificationStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.notificationStream;
});

// ============================================================
// Table State Providers (Riverpod = 단일 소스)
// ============================================================

/// 테이블 목록 Provider (HTTP fallback + WebSocket 실시간)
final tablesProvider = StateNotifierProvider<TablesNotifier, List<TableModel>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  return TablesNotifier(apiService, wsService, ref);
});

class TablesNotifier extends StateNotifier<List<TableModel>> {
  final ApiService _apiService;
  final WebSocketService _wsService;
  final Ref _ref;
  StreamSubscription? _wsSub;

  TablesNotifier(this._apiService, this._wsService, this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // 1. HTTP로 초기 데이터 fetch
    final initialTables = await _apiService.getTables();
    state = initialTables;

    // 2. 브로드캐스트 스트림 구독 → 내 테이블 자동 동기화/삭제
    _wsSub = _wsService.tablesStream.listen((tables) {
      state = tables;

      final currentTable = _ref.read(currentTableProvider);
      final deviceId = _apiService.deviceId;

      if (currentTable != null) {
        final match = tables.where((t) => t.id == currentTable.id).firstOrNull;
        if (match == null) {
          // 브로드캐스트에서 삭제됨 → currentTable 초기화
          _ref.read(currentTableProvider.notifier).clear();
        } else if (match != currentTable) {
          // 데이터 변경 → currentTable 갱신
          _ref.read(currentTableProvider.notifier).update(match);
        }
      } else if (deviceId != null) {
        // currentTable이 null인 상태에서 내 디바이스 테이블이 추가되면 자동 세팅
        final myTable = tables.where((t) => t.id == deviceId).firstOrNull;
        if (myTable != null) {
          _ref.read(currentTableProvider.notifier).update(myTable);
        }
      }
    });
  }

  void refresh() async {
    final tables = await _apiService.getTables();
    if (tables.isNotEmpty) {
      state = tables;
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}

/// 현재 테이블 Provider (순수 상태 홀더)
/// 갱신/삭제는 TablesNotifier 브로드캐스트에서 자동 처리
/// DEVICE_DELETED만 직접 구독
final currentTableProvider = StateNotifierProvider<CurrentTableNotifier, TableModel?>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return CurrentTableNotifier(wsService);
});

class CurrentTableNotifier extends StateNotifier<TableModel?> {
  StreamSubscription? _deviceDeletedSub;

  CurrentTableNotifier(WebSocketService wsService) : super(null) {
    _deviceDeletedSub = wsService.notificationStream.listen((data) {
      if (data['type'] == 'DEVICE_DELETED') {
        print('[Provider] DEVICE_DELETED → currentTable 초기화');
        state = null;
      }
    });
  }

  void update(TableModel? table) {
    state = table;
  }

  void clear() {
    state = null;
  }

  @override
  void dispose() {
    _deviceDeletedSub?.cancel();
    super.dispose();
  }
}

/// 선택된 테이블 Provider (autoDispose로 페이지 이탈 시 초기화)
final selectedTableProvider = StateProvider.autoDispose<TableModel?>((ref) => null);

// ============================================================
// Setup Form State (StateNotifier)
// ============================================================

/// SetupPage 폼 상태
class SetupFormState {
  final int currentStep;
  final String tableName;
  final String? selectedLocation;
  final int guestCount;
  final int femaleCount;
  final int maleCount;
  final bool isLoading;

  const SetupFormState({
    this.currentStep = 0,
    this.tableName = '',
    this.selectedLocation,
    this.guestCount = 4,
    this.femaleCount = 2,
    this.maleCount = 2,
    this.isLoading = false,
  });

  SetupFormState copyWith({
    int? currentStep,
    String? tableName,
    String? selectedLocation,
    int? guestCount,
    int? femaleCount,
    int? maleCount,
    bool? isLoading,
  }) {
    return SetupFormState(
      currentStep: currentStep ?? this.currentStep,
      tableName: tableName ?? this.tableName,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      guestCount: guestCount ?? this.guestCount,
      femaleCount: femaleCount ?? this.femaleCount,
      maleCount: maleCount ?? this.maleCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool canProceed() {
    switch (currentStep) {
      case 0:
        return tableName.trim().isNotEmpty;
      case 1:
        return selectedLocation != null;
      case 2:
        return guestCount >= 2;
      case 3:
        return femaleCount + maleCount == guestCount;
      default:
        return false;
    }
  }
}

final setupFormProvider = StateNotifierProvider.autoDispose<SetupFormNotifier, SetupFormState>((ref) {
  return SetupFormNotifier(ref);
});

class SetupFormNotifier extends StateNotifier<SetupFormState> {
  final Ref _ref;

  SetupFormNotifier(this._ref) : super(const SetupFormState());

  void setTableName(String name) {
    state = state.copyWith(tableName: name);
  }

  void setLocation(String location) {
    state = state.copyWith(selectedLocation: location);
  }

  void setGuestCount(int count) {
    final femaleCount = count ~/ 2;
    final maleCount = count - femaleCount;
    state = state.copyWith(
      guestCount: count,
      femaleCount: femaleCount,
      maleCount: maleCount,
    );
  }

  void incrementFemale() {
    if (state.femaleCount < state.guestCount && state.maleCount > 0) {
      state = state.copyWith(
        femaleCount: state.femaleCount + 1,
        maleCount: state.maleCount - 1,
      );
    }
  }

  void decrementFemale() {
    if (state.femaleCount > 0 && state.maleCount < state.guestCount) {
      state = state.copyWith(
        femaleCount: state.femaleCount - 1,
        maleCount: state.maleCount + 1,
      );
    }
  }

  void incrementMale() {
    if (state.maleCount < state.guestCount && state.femaleCount > 0) {
      state = state.copyWith(
        maleCount: state.maleCount + 1,
        femaleCount: state.femaleCount - 1,
      );
    }
  }

  void decrementMale() {
    if (state.maleCount > 0 && state.femaleCount < state.guestCount) {
      state = state.copyWith(
        maleCount: state.maleCount - 1,
        femaleCount: state.femaleCount + 1,
      );
    }
  }

  void nextStep() {
    if (state.currentStep < 3) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  Future<bool> submit() async {
    setLoading(true);
    try {
      final apiService = _ref.read(apiServiceProvider);
      final table = await apiService.setupTable(
        tableId: state.tableName.trim(),
        location: state.selectedLocation!,
        guestCount: state.guestCount,
        femaleCount: state.femaleCount,
        maleCount: state.maleCount,
      );
      // Riverpod으로 상태 관리
      _ref.read(currentTableProvider.notifier).update(table);
      return table != null;
    } catch (e) {
      return false;
    } finally {
      setLoading(false);
    }
  }
}

// ============================================================
// UI State Providers
// ============================================================

/// WelcomePage 재시도 상태
final isRetryingProvider = StateProvider.autoDispose<bool>((ref) => false);
