import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/table_model.dart';
import 'api_service.dart';

/// WebSocket 서비스 - 실시간 테이블 데이터 수신
class WebSocketService {
  WebSocketChannel? _channel;
  final _tableStreamController = StreamController<List<TableModel>>.broadcast();
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;

  // Singleton
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Stream<List<TableModel>> get tableStream => _tableStreamController.stream;
  bool get isConnected => _isConnected;

  /// WebSocket 연결
  Future<void> connect() async {
    // 이미 연결 중이거나 연결된 상태면 스킵
    if (_isConnected || _isConnecting) return;

    // 토큰이 없으면 연결하지 않음
    final token = ApiService().token;
    if (token == null) {
      _emitDummyData();
      return;
    }

    _isConnecting = true;

    try {
      final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token');
      _channel = WebSocketChannel.connect(uri);

      // 실제 연결 완료까지 대기
      await _channel!.ready;

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0; // 연결 성공 시 재시도 횟수 리셋

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _channel = null;

      // 연결 실패 시 더미 데이터로 폴백
      _emitDummyData();

      // 재연결 시도 (최대 횟수 제한)
      _scheduleReconnect();
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

  /// 재연결 스케줄링
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      // 최대 재시도 횟수 초과 - 오프라인 모드 유지
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // 점진적 백오프: 5초, 10초, 15초...
    final delay = Duration(seconds: 5 * _reconnectAttempts);
    _reconnectTimer = Timer(delay, connect);
  }

  /// 메시지 수신 처리
  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);

      if (data['type'] == 'tables_update') {
        final List<dynamic> tablesData = data['tables'] as List<dynamic>;
        final tables = tablesData
            .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
            .toList();
        _tableStreamController.add(tables);
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
  }
}
