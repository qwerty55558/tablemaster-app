import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
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

/// WebSocket 서비스 - 실시간 테이블 데이터 수신
class WebSocketService {
  WebSocketChannel? _channel;
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

  /// WebSocket 연결
  /// 연결 결과를 반환하여 화이트리스트 검증에 활용
  Future<WebSocketConnectionResult> connect() async {
    // 이미 연결된 상태면 성공 반환
    if (_isConnected) return WebSocketConnectionResult.success;

    // 이미 연결 중이면 대기
    if (_isConnecting) {
      // 연결 결과를 기다림
      return await connectionResultStream.first;
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

    try {
      final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token');
      _channel = WebSocketChannel.connect(uri);

      // 실제 연결 완료까지 대기 (타임아웃 10초)
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('WebSocket 연결 시간 초과'),
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0; // 연결 성공 시 재시도 횟수 리셋

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      _connectionResultController.add(WebSocketConnectionResult.success);
      return WebSocketConnectionResult.success;
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _channel = null;
      _lastConnectionError = e.toString();

      // 연결 실패 시 더미 데이터로 폴백
      _emitDummyData();

      _connectionResultController.add(WebSocketConnectionResult.failed);

      // 재연결 시도 (최대 횟수 제한)
      _scheduleReconnect();

      return WebSocketConnectionResult.failed;
    }
  }

  /// WebSocket 연결 해제
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _channel?.sink.close();
    _channel = null;
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

    // 4. 새 토큰으로 WebSocket 재연결
    await connect();
  }

  /// 메시지 수신 처리
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      final type = data['type'] as String?;

      switch (type) {
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
      }
    } catch (e) {
      // 파싱 에러 무시
    }
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    _scheduleReconnect();
  }

  void _onDone() {
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    _scheduleReconnect();
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
