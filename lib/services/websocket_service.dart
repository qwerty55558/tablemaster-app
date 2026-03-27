import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../config/api_config.dart';
import '../models/chat_model.dart';
import '../models/table_delta_event.dart';
import '../models/table_model.dart';
import 'api_service.dart';

/// WebSocket 연결 결과
enum WebSocketConnectionResult {
  /// 연결 성공
  success,

  /// 토큰 없음 (로그인 필요)
  noToken,

  /// 연결 실패 (화이트리스트 미등록 또는 네트워크 오류)
  failed,
}

/// STOMP WebSocket 서비스 - 실시간 데이터 수신
class WebSocketService {
  StompClient? _stompClient;
  final _connectionResultController =
      StreamController<WebSocketConnectionResult>.broadcast();
  final _deviceStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _tablesStreamController = StreamController<TableDeltaEvent>.broadcast();
  final _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatStreamController = StreamController<ChatEvent>.broadcast();

  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  String? _lastConnectionError;
  Completer<WebSocketConnectionResult>? _connectCompleter;
  Completer<void>? _syncCompleter;

  // 채팅방 동적 구독 (roomId → unsubscribe)
  final Map<int, StompUnsubscribe> _chatRoomSubscriptions = {};

  // Singleton
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Stream<WebSocketConnectionResult> get connectionResultStream =>
      _connectionResultController.stream;
  Stream<Map<String, dynamic>> get deviceStream => _deviceStreamController.stream;
  Stream<TableDeltaEvent> get tablesStream => _tablesStreamController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;
  Stream<ChatEvent> get chatStream => _chatStreamController.stream;
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
      _connectionResultController.add(WebSocketConnectionResult.noToken);
      return WebSocketConnectionResult.noToken;
    }

    _isConnecting = true;
    _lastConnectionError = null;
    _connectCompleter = Completer<WebSocketConnectionResult>();

    debugPrint('[WS] STOMP 연결 시도: ${ApiConfig.wsBaseUrl}');
    debugPrint('[WS] Token: ${token.substring(0, 20)}...');

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
        onDebugMessage: (msg) => debugPrint('[WS-DEBUG] $msg'),
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
    debugPrint('[WS] STOMP 연결 성공');
    _isConnected = true;
    _isConnecting = false;

    final result = WebSocketConnectionResult.success;
    _connectionResultController.add(result);
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(result);
    }

    // 재연결 시 stale 채팅방 구독 정리
    _chatRoomSubscriptions.clear();

    // 도메인별 구독 채널
    debugPrint('[WS] /user/queue/device 구독');
    _stompClient!.subscribe(
      destination: '/user/queue/device',
      callback: _onDeviceMessage,
    );

    debugPrint('[WS] /user/queue/tables 구독');
    _stompClient!.subscribe(
      destination: '/user/queue/tables',
      callback: _onTablesMessage,
    );

    // 브로드캐스트 채널 - 실시간 테이블 데이터
    debugPrint('[WS] /topic/tables 구독');
    _stompClient!.subscribe(
      destination: '/topic/tables',
      callback: _onTablesMessage,
    );

    debugPrint('[WS] /user/queue/notifications 구독');
    _stompClient!.subscribe(
      destination: '/user/queue/notifications',
      callback: _onNotificationMessage,
    );

    debugPrint('[WS] /user/queue/chat 구독');
    _stompClient!.subscribe(
      destination: '/user/queue/chat',
      callback: _onChatMessage,
    );

    // 연결 후 동기화 요청
    _requestSync();
  }

  /// STOMP 연결 해제 콜백
  void _onDisconnect(StompFrame frame) {
    debugPrint('[WS] 연결 해제됨: ${frame.body}');
    _isConnected = false;
    _isConnecting = false;
    _scheduleReconnect();
  }

  /// STOMP 에러 콜백
  void _onStompError(StompFrame frame) {
    debugPrint('[WS] STOMP 에러: ${frame.command} - ${frame.body}');
    debugPrint('[WS] STOMP 헤더: ${frame.headers}');
    _isConnected = false;
    _isConnecting = false;
    _lastConnectionError = frame.body ?? 'STOMP 에러';

    final result = WebSocketConnectionResult.failed;
    _connectionResultController.add(result);
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(result);
    }

    _scheduleReconnect();
  }

  /// WebSocket 에러 콜백
  void _onWebSocketError(dynamic error) {
    debugPrint('[WS] WebSocket 에러: $error');
    _isConnected = false;
    _isConnecting = false;
    _lastConnectionError = error.toString();

    final result = WebSocketConnectionResult.failed;
    _connectionResultController.add(result);
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(result);
    }

    _scheduleReconnect();
  }

  /// STOMP 연결 해제
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    // 채팅방 구독 참조 정리 (연결 끊기면 무효)
    _chatRoomSubscriptions.clear();
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnected = false;
    _isConnecting = false;
  }

  /// 재연결 스케줄링 (토큰 갱신 후 재연결)
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    if (_reconnectAttempts == _maxReconnectAttempts) {
      // 빠른 재시도 소진 → connectionLost 상태로 전환 (데이터 유지)
      ApiService().authService.notifyConnectionLost();
    }

    // 빠른 단계: 5초, 10초, 15초 / 느린 단계: 30초 간격
    final delay = _reconnectAttempts <= _maxReconnectAttempts
        ? Duration(seconds: 5 * _reconnectAttempts)
        : const Duration(seconds: 30);
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

  /// 연결 + 동기화 완료까지 대기
  /// connect() 후 TABLES_SNAPSHOT 수신까지 기다림
  Future<WebSocketConnectionResult> connectAndSync() async {
    _syncCompleter = Completer<void>();
    final result = await connect();
    if (result != WebSocketConnectionResult.success) {
      _syncCompleter = null;
      return result;
    }

    // TABLES_SNAPSHOT 수신 대기 (최대 10초)
    try {
      await _syncCompleter!.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      debugPrint('[WS] 동기화 타임아웃 - 연결은 유지');
    }
    _syncCompleter = null;
    return result;
  }

  /// 연결 후 동기화 요청
  void _requestSync() {
    debugPrint('[WS] 동기화 요청');

    _stompClient?.send(
      destination: '/app/sync',
      body: jsonEncode({}),
    );
  }

  /// INACTIVE 테이블 재연결 델타 전송
  void sendReconnectDelta() {
    debugPrint('[WS] 재연결 델타 전송');

    _stompClient?.send(
      destination: '/app/table/reconnect',
    );
  }

  /// 채팅 요청
  void sendChatRequest(String targetTableId) {
    debugPrint('[WS] 채팅 요청: $targetTableId');
    _stompClient?.send(
      destination: '/app/chat/request',
      body: jsonEncode({'targetTableId': targetTableId}),
    );
  }

  /// 채팅 수락
  void sendChatAccept(String targetTableId) {
    debugPrint('[WS] 채팅 수락: $targetTableId');
    _stompClient?.send(
      destination: '/app/chat/accept',
      body: jsonEncode({'targetTableId': targetTableId}),
    );
  }

  /// 채팅 거절
  void sendChatReject(String targetTableId) {
    debugPrint('[WS] 채팅 거절: $targetTableId');
    _stompClient?.send(
      destination: '/app/chat/reject',
      body: jsonEncode({'targetTableId': targetTableId}),
    );
  }

  /// 채팅 퇴장
  void sendChatLeave(int roomId) {
    debugPrint('[WS] 채팅 퇴장: roomId=$roomId');
    _stompClient?.send(
      destination: '/app/chat/leave',
      body: jsonEncode({'roomId': roomId}),
    );
  }

  /// 메시지 전송
  void sendChatMessage(int roomId, String content) {
    debugPrint('[WS] 메시지 전송: roomId=$roomId');
    _stompClient?.send(
      destination: '/app/chat/send',
      body: jsonEncode({'roomId': roomId, 'content': content}),
    );
  }

  /// 선물 전송
  void sendChatGift(int roomId, String giftType) {
    debugPrint('[WS] 선물 전송: roomId=$roomId');
    _stompClient?.send(
      destination: '/app/chat/gift',
      body: jsonEncode({
        'roomId': roomId,
        'giftType': giftType,
      }),
    );
  }

  /// 디바이스 메시지 수신 처리
  void _onDeviceMessage(StompFrame frame) {
    debugPrint('[WS] 디바이스 메시지 수신: ${frame.body}');

    if (frame.body == null) return;

    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      debugPrint('[WS] 디바이스 메시지 타입: $type');

      _deviceStreamController.add(data);
    } catch (e) {
      debugPrint('[WS] 디바이스 메시지 파싱 에러: $e');
    }
  }

  /// 테이블 메시지 수신 → raw 델타 이벤트 emit (상태 관리는 Riverpod에서)
  void _onTablesMessage(StompFrame frame) {
    if (frame.body == null) return;

    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      debugPrint('[WS] 테이블 메시지: $type');

      switch (type) {
        case 'TABLES_SNAPSHOT':
          final tablesJson = data['data'] as List<dynamic>?;
          if (tablesJson != null) {
            final tables = tablesJson
                .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
                .toList();
            _tablesStreamController.add(TableDeltaEvent.snapshot(tables));
            debugPrint('[WS] TABLES_SNAPSHOT: ${tables.length}개 테이블');

            // 연결 안정 확인 → backoff 리셋
            _reconnectAttempts = 0;

            if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
              _syncCompleter!.complete();
            }
          }
          break;

        case 'TABLE_ADDED':
          final tableJson = data['data'] as Map<String, dynamic>?;
          if (tableJson != null) {
            final table = TableModel.fromJson(tableJson);
            _tablesStreamController.add(TableDeltaEvent.added(table));
            debugPrint('[WS] TABLE_ADDED: ${table.id}');
          }
          break;

        case 'TABLE_REMOVED':
          final tableId = data['id'] as String?;
          if (tableId != null) {
            _tablesStreamController.add(TableDeltaEvent.removed(tableId));
            debugPrint('[WS] TABLE_REMOVED: $tableId');
          }
          break;

        case 'TABLE_UPDATED':
          final tableJson = data['data'] as Map<String, dynamic>?;
          if (tableJson != null) {
            final table = TableModel.fromJson(tableJson);
            _tablesStreamController.add(TableDeltaEvent.updated(table));
            debugPrint('[WS] TABLE_UPDATED: ${table.id}');
          }
          break;

        default:
          debugPrint('[WS] 알 수 없는 테이블 메시지: $type');
      }
    } catch (e) {
      debugPrint('[WS] 테이블 메시지 파싱 에러: $e');
    }
  }

  /// 알림 메시지 수신 처리
  void _onNotificationMessage(StompFrame frame) {
    debugPrint('[WS] 알림 메시지 수신: ${frame.body}');

    if (frame.body == null) return;

    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final type = data['type'] as String?;
      debugPrint('[WS] 알림 메시지 타입: $type');

      if (type == 'DEVICE_DELETED') {
        debugPrint('[WS] DEVICE_DELETED 수신');
        disconnect();
        ApiService().authService.handleDeviceDeleted();
        return;
      }

      _notificationStreamController.add(data);
    } catch (e) {
      debugPrint('[WS] 알림 메시지 파싱 에러: $e');
    }
  }

  /// 채팅 메시지 수신 처리 (/user/queue/chat)
  void _onChatMessage(StompFrame frame) {
    debugPrint('[WS] 채팅 메시지 수신: ${frame.body}');
    if (frame.body == null) return;

    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final event = ChatEvent.fromJson(data);
      debugPrint('[WS] 채팅 이벤트 타입: ${event.type}');
      _chatStreamController.add(event);
    } catch (e) {
      debugPrint('[WS] 채팅 메시지 파싱 에러: $e');
    }
  }

  /// 채팅방 메시지 브로드캐스트 수신 처리 (/topic/chat.room.{roomId})
  /// 서버에서 MESSAGE, GIFT, LEAVE 타입을 보냄
  void _onChatRoomMessage(StompFrame frame) {
    debugPrint('[WS] 채팅방 메시지 수신: ${frame.body}');
    if (frame.body == null) return;

    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final type = data['type'] as String? ?? data['messageType'] as String?;

      if (type == 'LEAVE' || type == 'CHAT_CLOSED') {
        // 퇴장 이벤트 → chatClosed로 변환
        final event = ChatEvent(
          type: ChatEventType.chatClosed,
          roomId: data['roomId'] as int?,
        );
        _chatStreamController.add(event);
      } else {
        // MESSAGE, GIFT 등 → 일반 채팅 메시지
        final message = ChatMessage.fromJson(data);
        final event = ChatEvent(
          type: ChatEventType.chatMessage,
          message: message,
        );
        _chatStreamController.add(event);
      }
    } catch (e) {
      debugPrint('[WS] 채팅방 메시지 파싱 에러: $e');
    }
  }

  /// 채팅방 동적 구독
  void subscribeToChatRoom(int roomId) {
    if (_chatRoomSubscriptions.containsKey(roomId)) return;
    final destination = '/topic/chat.room.$roomId';
    debugPrint('[WS] $destination 구독');
    final unsub = _stompClient?.subscribe(
      destination: destination,
      callback: _onChatRoomMessage,
    );
    if (unsub != null) {
      _chatRoomSubscriptions[roomId] = unsub;
    }
  }

  /// 특정 채팅방 구독 해제
  void unsubscribeFromChatRoom(int roomId) {
    final unsub = _chatRoomSubscriptions.remove(roomId);
    if (unsub != null) {
      debugPrint('[WS] 채팅방 구독 해제: roomId=$roomId');
      unsub(unsubscribeHeaders: {});
    }
  }

  /// 모든 채팅방 구독 해제
  void unsubscribeFromAllChatRooms() {
    for (final entry in _chatRoomSubscriptions.entries) {
      debugPrint('[WS] 채팅방 구독 해제: roomId=${entry.key}');
      try {
        entry.value(unsubscribeHeaders: {});
      } catch (_) {
        // 연결 끊긴 후 stale 구독 무시
      }
    }
    _chatRoomSubscriptions.clear();
  }

  void dispose() {
    disconnect();
    _connectionResultController.close();
    _deviceStreamController.close();
    _tablesStreamController.close();
    _notificationStreamController.close();
    _chatStreamController.close();
  }
}
