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

  // Singleton
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Stream<List<TableModel>> get tableStream => _tableStreamController.stream;
  bool get isConnected => _isConnected;

  /// WebSocket 연결
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = ApiService().token;
      final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token');

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);
    } catch (e) {
      _isConnected = false;
      // 연결 실패 시 더미 데이터로 폴백
      _emitDummyData();
    }
  }

  /// WebSocket 연결 해제
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
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
  }

  void _onDone() {
    _isConnected = false;
    // 재연결 로직 (5초 후)
    Future.delayed(const Duration(seconds: 5), connect);
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
