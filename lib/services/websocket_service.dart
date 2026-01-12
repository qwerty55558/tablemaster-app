import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../config/api_config.dart';
import '../models/table_model.dart';
import 'api_service.dart';

/// 테이블 초기화 이벤트
class TableResetEvent {
  final String tableId;
  final String timestamp;

  TableResetEvent({required this.tableId, required this.timestamp});
}

/// WebSocket 연결 결과
enum WebSocketConnectionResult {
  /// 연결 성공
  success,

  /// 토큰 없음 (로그인 필요)
  noToken,

  /// 연결 실패 (화이트리스트 미등록 또는 네트워크 오류)
  failed,
}

/// STOMP WebSocket 서비스 - 실시간 테이블 데이터 수신
class WebSocketService {
  StompClient? _stompClient;
  final _tableStreamController = StreamController<List<TableModel>>.broadcast();
  final _resetStreamController = StreamController<TableResetEvent>.broadcast();
  final _connectionResultController =
      StreamController<WebSocketConnectionResult>.broadcast();
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  String? _lastConnectionError;
  Completer<WebSocketConnectionResult>? _connectCompleter;

  // Singleton
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Stream<List<TableModel>> get tableStream => _tableStreamController.stream;
  Stream<TableResetEvent> get resetStream => _resetStreamController.stream;
  Stream<WebSocketConnectionResult> get connectionResultStream =>
      _connectionResultController.stream;
  bool get isConnected => _isConnected;
  String? get lastConnectionError => _lastConnectionError;

  /// STOMP 연결
  /// 연결 결과를 반환하여 화이트리스트 검증에 활용
  Future<WebSocketConnectionResult> connect() async {
    // 이미 연결된 상태면 성공 반환
    if (_isConnected) return WebSocketConnectionResult.success;

    // 이미 연결 중이면 대기
    if (_isConnecting && _connectCompleter != null) {
      return await _connectCompleter!.future;
    }

    // 토큰이 없으면 연결하지 않음
    final token = ApiService().token;
    if (token == null) {
      _lastConnectionError = '토큰이 없습니다';
      _emitDummyData();
      _connectionResultController.add(WebSocketConnectionResult.noToken);
      return WebSocketConnectionResult.noToken;
    }

    _isConnecting = true;
    _lastConnectionError = null;
    _connectCompleter = Completer<WebSocketConnectionResult>();

    print('[WS] STOMP 연결 시도: ${ApiConfig.wsBaseUrl}');
    print('[WS] Token: ${token.substring(0, 20)}...');

    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: ApiConfig.wsBaseUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onStompError,
        onWebSocketError: _onWebSocketError,
        onDebugMessage: (msg) => print('[WS-DEBUG] $msg'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _stompClient!.activate();

    // 타임아웃 설정 (10초)
    return await _connectCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _isConnecting = false;
        _lastConnectionError = 'STOMP 연결 시간 초과';
        _stompClient?.deactivate();
        _stompClient = null;
        _emitDummyData();
        final result = WebSocketConnectionResult.failed;
        _connectionResultController.add(result);
        if (!_connectCompleter!.isCompleted) {
          _connectCompleter!.complete(result);
        }
        _scheduleReconnect();
        return result;
      },
    );
  }

  /// STOMP 연결 성공 콜백
  void _onConnect(StompFrame frame) {
    print('[WS] STOMP 연결 성공');
    _isConnected = true;
    _isConnecting = false;
    _reconnectAttempts = 0;

    final result = WebSocketConnectionResult.success;
    _connectionResultController.add(result);
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(result);
    }

    // /user/queue/notifications 구독 (Spring이 세션 기반으로 라우팅)
    print('[WS] /user/queue/notifications 구독');
    _stompClient!.subscribe(
      destination: '/user/queue/notifications',
      callback: _onNotificationMessage,
    );

    // /user/queue/chat 구독
    print('[WS] /user/queue/chat 구독');
    _stompClient!.subscribe(
      destination: '/user/queue/chat',
      callback: _onChatMessage,
    );
  }

  /// STOMP 연결 해제 콜백
  void _onDisconnect(StompFrame frame) {
    print('[WS] 연결 해제됨: ${frame.body}');
    _isConnected = false;
    _isConnecting = false;
    _scheduleReconnect();
  }

  /// STOMP 에러 콜백
  void _onStompError(StompFrame frame) {
    print('[WS] STOMP 에러: ${frame.command} - ${frame.body}');
    print('[WS] STOMP 헤더: ${frame.headers}');
    _isConnected = false;
    _isConnecting = false;
    _lastConnectionError = frame.body ?? 'STOMP 에러';

    final result = WebSocketConnectionResult.failed;
    _connectionResultController.add(result);
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(result);
    }

    _emitDummyData();
    _scheduleReconnect();
  }

  /// WebSocket 에러 콜백
  void _onWebSocketError(dynamic error) {
    print('[WS] WebSocket 에러: $error');
    _isConnected = false;
    _isConnecting = false;
    _lastConnectionError = error.toString();

    final result = WebSocketConnectionResult.failed;
    _connectionResultController.add(result);
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(result);
    }

    _emitDummyData();
    _scheduleReconnect();
  }

  /// STOMP 연결 해제
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnected = false;
    _isConnecting = false;
  }

  /// 재연결 스케줄링 (토큰 갱신 후 재연결)
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      // 최대 재시도 횟수 초과 - AuthStatus를 failed로 변경
      ApiService().authService.notifyConnectionLost();
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // 점진적 백오프: 5초, 10초, 15초...
    final delay = Duration(seconds: 5 * _reconnectAttempts);
    _reconnectTimer = Timer(delay, _reconnectWithTokenRefresh);
  }

  /// 토큰 갱신 후 재연결 시도
  Future<void> _reconnectWithTokenRefresh() async {
    final authService = ApiService().authService;

    // 1. 토큰 갱신 시도
    bool tokenRefreshed = await authService.refreshAccessToken();

    // 2. 갱신 실패 시 디바이스 재로그인 시도
    if (!tokenRefreshed) {
      tokenRefreshed = await authService.deviceLogin();
    }

    // 3. 재로그인도 실패 시 중단
    if (!tokenRefreshed) {
      authService.notifyConnectionLost();
      return;
    }

    // 4. 새 토큰으로 STOMP 재연결
    await connect();
  }

  /// 알림 메시지 수신 처리
  void _onNotificationMessage(StompFrame frame) {
    print('[WS] 메시지 수신: ${frame.body}');

    if (frame.body == null) return;

    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      print('[WS] 메시지 타입: $type');

      switch (type) {
        case 'DEVICE_DELETED':
          print('[WS] DEVICE_DELETED 처리 시작');
          _handleDeviceDeleted(data);
          break;

        case 'tables_update':
          final List<dynamic> tablesData = data['tables'] as List<dynamic>;
          final tables = tablesData
              .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _tableStreamController.add(tables);
          break;

        case 'table_reset':
          final tableId = data['tableId'] as String;
          final timestamp = data['timestamp'] as String? ?? '';
          _resetStreamController.add(TableResetEvent(
            tableId: tableId,
            timestamp: timestamp,
          ));
          break;

        default:
          print('[WS] 알 수 없는 메시지 타입: $type');
      }
    } catch (e) {
      print('[WS] 메시지 파싱 에러: $e');
    }
  }

  /// 채팅 메시지 수신 처리
  void _onChatMessage(StompFrame frame) {
    if (frame.body == null) return;

    // TODO: 채팅 메시지 처리 로직 추가
  }

  /// 디바이스 삭제 처리
  void _handleDeviceDeleted(Map<String, dynamic> data) {
    print('[WS] _handleDeviceDeleted 호출됨');

    // 1. STOMP 연결 해제
    disconnect();

    // 2. AuthService에 알림 → 토큰 삭제 + unregistered 상태
    print('[WS] authService.handleDeviceDeleted 호출');
    ApiService().authService.handleDeviceDeleted();
  }

  /// 더미 데이터 emit (개발용)
  void _emitDummyData() {
    final dummyTables = ApiService().getTables();
    dummyTables.then((tables) {
      _tableStreamController.add(tables);
    });
  }

  void dispose() {
    disconnect();
    _tableStreamController.close();
    _resetStreamController.close();
    _connectionResultController.close();
  }
}
