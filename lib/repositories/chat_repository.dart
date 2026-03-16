import 'dart:async';
import '../models/chat_model.dart';
import '../services/websocket_service.dart';

/// 채팅 데이터 Repository (단일 진실원)
/// - 1:N 채팅 지원 — 한 테이블이 여러 1:1 채팅방 동시 참여 가능
/// - WS chatStream 수신 → 상태 적용
/// - 스트림으로 외부에 상태 노출
class ChatRepository {
  final WebSocketService _wsService;

  /// 활성 채팅방 (roomId → ChatRoom)
  final Map<int, ChatRoom> _rooms = {};

  /// 현재 보고 있는 채팅방 ID
  int? _activeRoomId;

  ChatEvent? _pendingRequest;

  final _roomsController = StreamController<Map<int, ChatRoom>>.broadcast();
  final _activeRoomController = StreamController<ChatRoom?>.broadcast();
  final _requestController = StreamController<ChatEvent?>.broadcast();
  final _toastController = StreamController<ChatEvent>.broadcast();

  StreamSubscription<ChatEvent>? _chatSub;

  // Singleton
  static ChatRepository? _instance;
  factory ChatRepository({required WebSocketService wsService}) {
    _instance ??= ChatRepository._internal(wsService);
    return _instance!;
  }

  ChatRepository._internal(this._wsService) {
    _chatSub = _wsService.chatStream.listen(_handleEvent);
  }

  Map<int, ChatRoom> get rooms => Map.unmodifiable(_rooms);
  ChatRoom? get activeRoom => _activeRoomId != null ? _rooms[_activeRoomId] : null;
  int? get activeRoomId => _activeRoomId;
  ChatEvent? get pendingRequest => _pendingRequest;

  Stream<Map<int, ChatRoom>> get roomsStream => _roomsController.stream;
  Stream<ChatRoom?> get activeRoomStream => _activeRoomController.stream;
  Stream<ChatEvent?> get requestStream => _requestController.stream;
  Stream<ChatEvent> get toastStream => _toastController.stream;

  void _handleEvent(ChatEvent event) {
    print('[ChatRepo] 이벤트 수신: ${event.type}');

    switch (event.type) {
      case ChatEventType.chatRequest:
        _pendingRequest = event;
        _requestController.add(event);
        break;

      case ChatEventType.chatAccepted:
        _pendingRequest = null;
        _requestController.add(null);

        final roomId = event.roomId;
        if (roomId != null) {
          final room = ChatRoom(
            roomId: roomId,
            partnerDeviceId: event.partnerDeviceId ?? event.fromDeviceId ?? '',
            partnerTableName: event.partnerTableName ?? event.fromTableName ?? '',
          );
          _rooms[roomId] = room;
          _roomsController.add(rooms);

          _wsService.subscribeToChatRoom(roomId);

          // 자동으로 새 채팅방을 활성화
          _activeRoomId = roomId;
          _activeRoomController.add(room);
        }
        break;

      case ChatEventType.chatRejected:
        _pendingRequest = null;
        _requestController.add(null);
        _toastController.add(event);
        break;

      case ChatEventType.chatRequestFailed:
        _toastController.add(event);
        break;

      case ChatEventType.chatError:
        _toastController.add(event);
        break;

      case ChatEventType.chatRoomsSnapshot:
        final snapshotRooms = event.rooms;
        if (snapshotRooms != null) {
          // 기존 구독 정리
          _wsService.unsubscribeFromAllChatRooms();
          _rooms.clear();

          for (final room in snapshotRooms) {
            _rooms[room.roomId] = room;
            _wsService.subscribeToChatRoom(room.roomId);
          }
          _roomsController.add(rooms);

          // 활성 방 복원: 기존 활성 방이 유효하면 유지, 아니면 첫 번째 방
          if (_activeRoomId == null || !_rooms.containsKey(_activeRoomId)) {
            _activeRoomId = _rooms.isNotEmpty ? _rooms.keys.first : null;
          }
          _activeRoomController.add(activeRoom);
        }
        break;

      case ChatEventType.chatClosed:
        final roomId = event.roomId;
        if (roomId != null) {
          _wsService.unsubscribeFromChatRoom(roomId);
          _rooms.remove(roomId);
          _roomsController.add(rooms);

          if (_activeRoomId == roomId) {
            _activeRoomId = _rooms.isNotEmpty ? _rooms.keys.first : null;
            _activeRoomController.add(activeRoom);
          }
        }
        _toastController.add(event);
        break;

      case ChatEventType.chatWarning:
        // 경고 메시지를 채팅방 메시지 리스트에 시스템 메시지로 추가
        final warningRoomId = event.roomId;
        if (warningRoomId != null && _rooms.containsKey(warningRoomId)) {
          final warningMsg = ChatMessage(
            senderDeviceId: '',
            senderTableName: '',
            content: event.warningMessage ?? event.reason ?? '경고가 발생했습니다',
            messageType: 'WARNING',
            timestamp: DateTime.now(),
          );
          _rooms[warningRoomId] = _rooms[warningRoomId]!.copyWith(
            messages: [..._rooms[warningRoomId]!.messages, warningMsg],
          );
          _roomsController.add(rooms);
          if (_activeRoomId == warningRoomId) {
            _activeRoomController.add(_rooms[warningRoomId]);
          }
        }
        _toastController.add(event);
        break;

      case ChatEventType.chatMutedByStaff:
        final roomId = event.roomId;
        if (roomId != null && _rooms.containsKey(roomId)) {
          _rooms[roomId] = _rooms[roomId]!.copyWith(
            sanctionType: SanctionType.mute,
            mutedUntil: event.mutedUntil != null
                ? DateTime.tryParse(event.mutedUntil!)
                : null,
          );
          _roomsController.add(rooms);
          if (_activeRoomId == roomId) {
            _activeRoomController.add(_rooms[roomId]);
          }
        }
        _toastController.add(event);
        break;

      case ChatEventType.chatSanctioned:
        final roomId = event.roomId;
        if (roomId != null && _rooms.containsKey(roomId)) {
          _rooms[roomId] = _rooms[roomId]!.copyWith(
            sanctionType: SanctionType.ban,
          );
          _roomsController.add(rooms);
          if (_activeRoomId == roomId) {
            _activeRoomController.add(_rooms[roomId]);
          }
        }
        _toastController.add(event);
        break;

      case ChatEventType.chatMuted:
        _toastController.add(event);
        break;

      case ChatEventType.chatSanctionLifted:
        final roomId = event.roomId;
        if (roomId != null && _rooms.containsKey(roomId)) {
          _rooms[roomId] = _rooms[roomId]!.copyWith(
            sanctionType: SanctionType.none,
            clearMutedUntil: true,
          );
          _roomsController.add(rooms);
          if (_activeRoomId == roomId) {
            _activeRoomController.add(_rooms[roomId]);
          }
        }
        _toastController.add(event);
        break;

      case ChatEventType.chatMessage:
        final msg = event.message;
        if (msg == null) break;

        // roomId로 해당 채팅방 찾기
        final roomId = msg.roomId;
        if (roomId != null && _rooms.containsKey(roomId)) {
          _rooms[roomId] = _rooms[roomId]!.copyWith(
            messages: [..._rooms[roomId]!.messages, msg],
          );
          _roomsController.add(rooms);

          // 활성 채팅방이면 activeRoom도 갱신
          if (_activeRoomId == roomId) {
            _activeRoomController.add(_rooms[roomId]);
          }
        }
        break;
    }
  }

  /// 현재 보고 있는 채팅방 변경
  void setActiveRoom(int roomId) {
    if (_rooms.containsKey(roomId)) {
      _activeRoomId = roomId;
      _activeRoomController.add(_rooms[roomId]);
    }
  }

  void acceptRequest(String targetTableId) {
    _wsService.sendChatAccept(targetTableId);
    _pendingRequest = null;
    _requestController.add(null);
  }

  void rejectRequest(String targetTableId) {
    _wsService.sendChatReject(targetTableId);
    _pendingRequest = null;
    _requestController.add(null);
  }

  void sendMessage(int roomId, String content) {
    final room = _rooms[roomId];
    if (room != null && room.isSanctioned) return;
    _wsService.sendChatMessage(roomId, content);
  }

  void leaveChat(int roomId) {
    final room = _rooms[roomId];
    if (room == null) return;
    // BAN 상태에서는 나가기 차단 (MUTE는 퇴장 가능)
    if (room.isBanned) return;

    // room topic 구독 먼저 해제 (LEAVE 브로드캐스트 중복 수신 방지)
    _wsService.unsubscribeFromChatRoom(roomId);
    // 서버에 퇴장 요청
    _wsService.sendChatLeave(roomId);
    // 로컬 상태 즉시 정리 (서버 CHAT_CLOSED 응답 전에 UI 반영)
    _rooms.remove(roomId);
    _roomsController.add(rooms);

    if (_activeRoomId == roomId) {
      _activeRoomId = _rooms.isNotEmpty ? _rooms.keys.first : null;
      _activeRoomController.add(activeRoom);
    }
  }

  void dispose() {
    _chatSub?.cancel();
    _roomsController.close();
    _activeRoomController.close();
    _requestController.close();
    _toastController.close();
  }
}
