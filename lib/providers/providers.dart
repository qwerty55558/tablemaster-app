import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../repositories/table_repository.dart';
import '../repositories/chat_repository.dart';
import '../models/bill_model.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';
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
    error: (error, stackTrace) => AuthStatus.failed,
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

/// 알림 스트림
final notificationStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.notificationStream;
});

// ============================================================
// Repository Provider
// ============================================================

/// TableRepository Provider (싱글톤, WS 델타 수신 + 상태 관리)
final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final wsService = ref.watch(webSocketServiceProvider);
  return TableRepository(apiService: apiService, wsService: wsService);
});

// ============================================================
// Chat Repository Provider
// ============================================================

/// ChatRepository Provider (싱글톤, WS 채팅 이벤트 수신 + 상태 관리)
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return ChatRepository(wsService: wsService);
});

// ============================================================
// Chat State Providers
// ============================================================

/// 전체 채팅방 목록 Provider (roomId → ChatRoom)
final chatRoomsProvider =
    StateNotifierProvider<_ChatRoomsNotifier, Map<int, ChatRoom>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return _ChatRoomsNotifier(repo);
});

class _ChatRoomsNotifier extends StateNotifier<Map<int, ChatRoom>> {
  late final StreamSubscription<Map<int, ChatRoom>> _sub;

  _ChatRoomsNotifier(ChatRepository repo) : super(repo.rooms) {
    _sub = repo.roomsStream.listen((rooms) => state = rooms);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// 현재 활성 채팅방 Provider
final activeChatRoomProvider =
    StateNotifierProvider<_ActiveChatRoomNotifier, ChatRoom?>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return _ActiveChatRoomNotifier(repo);
});

class _ActiveChatRoomNotifier extends StateNotifier<ChatRoom?> {
  late final StreamSubscription<ChatRoom?> _sub;

  _ActiveChatRoomNotifier(ChatRepository repo) : super(repo.activeRoom) {
    _sub = repo.activeRoomStream.listen((room) => state = room);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// 수신된 채팅 요청 (수락/거절 대기)
final pendingChatRequestProvider =
    StateNotifierProvider<_PendingRequestNotifier, ChatEvent?>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return _PendingRequestNotifier(repo);
});

class _PendingRequestNotifier extends StateNotifier<ChatEvent?> {
  late final StreamSubscription<ChatEvent?> _sub;

  _PendingRequestNotifier(ChatRepository repo) : super(repo.pendingRequest) {
    _sub = repo.requestStream.listen((req) => state = req);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// 채팅 토스트 이벤트 스트림 (거절, 실패, 에러)
final chatToastStreamProvider = StreamProvider<ChatEvent>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.toastStream;
});

// ============================================================
// Table State Providers (Repository 스트림 → StateNotifier 래핑)
// ============================================================

/// 테이블 목록 Provider
final tablesProvider =
    StateNotifierProvider<_TablesNotifier, List<TableModel>>((ref) {
  final repo = ref.watch(tableRepositoryProvider);
  return _TablesNotifier(repo);
});

class _TablesNotifier extends StateNotifier<List<TableModel>> {
  late final StreamSubscription<List<TableModel>> _sub;

  _TablesNotifier(TableRepository repo) : super(repo.tables) {
    _sub = repo.tablesStream.listen((tables) => state = tables);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// 현재 내 테이블 Provider
final currentTableProvider =
    StateNotifierProvider<_CurrentTableNotifier, TableModel?>((ref) {
  final repo = ref.watch(tableRepositoryProvider);
  return _CurrentTableNotifier(repo);
});

class _CurrentTableNotifier extends StateNotifier<TableModel?> {
  late final StreamSubscription<TableModel?> _sub;

  _CurrentTableNotifier(TableRepository repo) : super(repo.currentTable) {
    _sub = repo.currentTableStream.listen((table) => state = table);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// 선택된 테이블 ID (autoDispose로 페이지 이탈 시 초기화)
final selectedTableIdProvider = StateProvider.autoDispose<String?>((ref) => null);

/// 선택된 테이블 (tablesProvider에서 실시간 데이터 조회)
final selectedTableProvider = Provider.autoDispose<TableModel?>((ref) {
  final selectedId = ref.watch(selectedTableIdProvider);
  if (selectedId == null) return null;
  final tables = ref.watch(tablesProvider);
  return tables.where((t) => t.id == selectedId).firstOrNull;
});

/// 내 테이블 선택 여부 Provider
final isMyTableSelectedProvider = StateProvider.autoDispose<bool>((ref) => false);

// ============================================================
// Notification Providers
// ============================================================

/// 알림 목록 Provider
final notificationsProvider =
    StateNotifierProvider.autoDispose<NotificationsNotifier, List<NotificationModel>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return NotificationsNotifier(apiService);
});

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  final ApiService _apiService;

  NotificationsNotifier(this._apiService) : super([]);

  Future<void> fetch() async {
    final notifications = await _apiService.getNotifications();
    if (mounted) state = notifications;
  }

  Future<void> markRead(int id) async {
    final success = await _apiService.markNotificationRead(id);
    if (success && mounted) {
      state = [
        for (final n in state)
          if (n.id == id)
            NotificationModel(
              id: n.id,
              title: n.title,
              body: n.body,
              category: n.category,
              data: n.data,
              isRead: true,
              createdAt: n.createdAt,
            )
          else
            n,
      ];
    }
  }

  Future<void> markAllRead() async {
    final success = await _apiService.markAllNotificationsRead();
    if (success && mounted) {
      state = [
        for (final n in state)
          NotificationModel(
            id: n.id,
            title: n.title,
            body: n.body,
            category: n.category,
            data: n.data,
            isRead: true,
            createdAt: n.createdAt,
          ),
      ];
    }
  }
}

/// 읽지 않은 알림 개수 Provider
final unreadCountProvider =
    StateNotifierProvider.autoDispose<UnreadCountNotifier, int>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UnreadCountNotifier(apiService);
});

class CatalogResourcesState {
  final bool isLoading;
  final bool isLoaded;
  final List<MenuItem> menuItems;
  final List<GiftItem> giftItems;

  const CatalogResourcesState({
    this.isLoading = false,
    this.isLoaded = false,
    this.menuItems = const [],
    this.giftItems = const [],
  });

  CatalogResourcesState copyWith({
    bool? isLoading,
    bool? isLoaded,
    List<MenuItem>? menuItems,
    List<GiftItem>? giftItems,
  }) {
    return CatalogResourcesState(
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      menuItems: menuItems ?? this.menuItems,
      giftItems: giftItems ?? this.giftItems,
    );
  }
}

final catalogResourcesProvider =
    StateNotifierProvider<CatalogResourcesNotifier, CatalogResourcesState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return CatalogResourcesNotifier(apiService);
});

class CatalogResourcesNotifier extends StateNotifier<CatalogResourcesState> {
  final ApiService _apiService;
  Future<void>? _loadFuture;

  CatalogResourcesNotifier(this._apiService)
      : super(const CatalogResourcesState());

  Future<void> load({bool force = false}) async {
    if (state.isLoaded && !force) return;
    if (_loadFuture != null && !force) return _loadFuture;

    final future = _load(force: force);
    _loadFuture = future;
    await future;
  }

  Future<void> _load({required bool force}) async {
    state = state.copyWith(isLoading: true);

    final results = await Future.wait([
      _apiService.getMenuItems(),
      _apiService.getGifts(),
    ]);

    state = state.copyWith(
      isLoading: false,
      isLoaded: true,
      menuItems: results[0] as List<MenuItem>,
      giftItems: results[1] as List<GiftItem>,
    );

    _loadFuture = null;
  }
}

class UnreadCountNotifier extends StateNotifier<int> {
  final ApiService _apiService;

  UnreadCountNotifier(this._apiService) : super(0) {
    _init();
  }

  Future<void> _init() async {
    final count = await _apiService.getUnreadCount();
    if (mounted) state = count;
  }

  Future<void> refresh() async {
    final count = await _apiService.getUnreadCount();
    if (mounted) state = count;
  }

  void clear() {
    if (mounted) state = 0;
  }
}

enum OrderPanelTab { order, bill }

class OrderPanelState {
  final bool isOpen;
  final bool isLoading;
  final bool isSubmitting;
  final String? identifier;
  final OrderPanelTab activeTab;
  final List<MenuItem> menuItems;
  final List<GiftItem> giftItems;
  final Bill? bill;
  final Map<int, int> selectedQuantities;

  const OrderPanelState({
    this.isOpen = false,
    this.isLoading = false,
    this.isSubmitting = false,
    this.identifier,
    this.activeTab = OrderPanelTab.order,
    this.menuItems = const [],
    this.giftItems = const [],
    this.bill,
    this.selectedQuantities = const {},
  });

  OrderPanelState copyWith({
    bool? isOpen,
    bool? isLoading,
    bool? isSubmitting,
    String? identifier,
    bool clearIdentifier = false,
    OrderPanelTab? activeTab,
    List<MenuItem>? menuItems,
    List<GiftItem>? giftItems,
    Bill? bill,
    bool clearBill = false,
    Map<int, int>? selectedQuantities,
  }) {
    return OrderPanelState(
      isOpen: isOpen ?? this.isOpen,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      identifier: clearIdentifier ? null : (identifier ?? this.identifier),
      activeTab: activeTab ?? this.activeTab,
      menuItems: menuItems ?? this.menuItems,
      giftItems: giftItems ?? this.giftItems,
      bill: clearBill ? null : (bill ?? this.bill),
      selectedQuantities: selectedQuantities ?? this.selectedQuantities,
    );
  }

  int get selectedCount =>
      selectedQuantities.values.fold(0, (sum, quantity) => sum + quantity);
}

final orderPanelProvider =
    StateNotifierProvider<OrderPanelNotifier, OrderPanelState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return OrderPanelNotifier(ref, apiService);
});

class OrderPanelNotifier extends StateNotifier<OrderPanelState> {
  final Ref _ref;
  final ApiService _apiService;

  OrderPanelNotifier(this._ref, this._apiService) : super(const OrderPanelState());

  Future<void> open(String identifier, {OrderPanelTab tab = OrderPanelTab.order}) async {
    final catalogNotifier = _ref.read(catalogResourcesProvider.notifier);
    await catalogNotifier.load();
    final catalog = _ref.read(catalogResourcesProvider);

    state = state.copyWith(
      isOpen: true,
      isLoading: true,
      identifier: identifier,
      activeTab: tab,
    );

    final billFuture = _apiService.getCurrentOrders(identifier);

    final bill = await billFuture;

    if (!mounted) return;

    state = state.copyWith(
      isLoading: false,
      menuItems: catalog.menuItems,
      giftItems: catalog.giftItems,
      bill: bill,
    );
  }

  void close() {
    state = state.copyWith(isOpen: false, selectedQuantities: const {});
  }

  void setTab(OrderPanelTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setQuantity(int menuItemId, int quantity) {
    final next = Map<int, int>.from(state.selectedQuantities);
    if (quantity <= 0) {
      next.remove(menuItemId);
    } else {
      next[menuItemId] = quantity;
    }
    state = state.copyWith(selectedQuantities: next);
  }

  Future<bool> submitOrder() async {
    final identifier = state.identifier;
    if (identifier == null || state.selectedQuantities.isEmpty) return false;

    state = state.copyWith(isSubmitting: true);
    final success = await _apiService.createOrder(
      identifier,
      state.selectedQuantities.entries
          .map((entry) => {
                'menuItemId': entry.key,
                'quantity': entry.value,
              })
          .toList(),
    );

    if (!mounted) return success;

    if (success) {
      final bill = await _apiService.getCurrentOrders(identifier);
      if (!mounted) return success;
      _ref.invalidate(currentOrdersProvider(identifier));
      state = state.copyWith(
        isSubmitting: false,
        bill: bill,
        selectedQuantities: const {},
        activeTab: OrderPanelTab.bill,
      );
    } else {
      state = state.copyWith(isSubmitting: false);
    }
    return success;
  }

  Future<void> refreshBill() async {
    final identifier = state.identifier;
    if (identifier == null) return;
    final bill = await _apiService.getCurrentOrders(identifier);
    if (!mounted) return;
    _ref.invalidate(currentOrdersProvider(identifier));
    state = state.copyWith(bill: bill);
  }

  Future<void> refreshBillFor(String identifier) async {
    final bill = await _apiService.getCurrentOrders(identifier);
    if (!mounted) return;
    _ref.invalidate(currentOrdersProvider(identifier));
    state = state.copyWith(
      identifier: identifier,
      bill: bill,
    );
  }
}

final currentOrdersProvider =
    FutureProvider.autoDispose.family<Bill?, String>((ref, identifier) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getCurrentOrders(identifier);
});

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
      final success = await apiService.setupTable(
        tableId: state.tableName.trim(),
        location: state.selectedLocation!,
        guestCount: state.guestCount,
        femaleCount: state.femaleCount,
        maleCount: state.maleCount,
      );
      // currentTable은 WS 브로드캐스트에서 자동 동기화
      return success;
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
