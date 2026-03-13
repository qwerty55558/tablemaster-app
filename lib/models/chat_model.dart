/// 채팅 이벤트 타입
enum ChatEventType {
  chatRequest,
  chatAccepted,
  chatRejected,
  chatRequestFailed,
  chatError,
  chatClosed,
  chatRoomsSnapshot,
  chatMessage,
}

/// 서버→클라이언트 채팅 이벤트 (WS 수신)
class ChatEvent {
  final ChatEventType type;
  final String? fromDeviceId;
  final String? fromTableName;
  final int? roomId;
  final String? partnerDeviceId;
  final String? partnerTableName;
  final String? reason;
  final ChatMessage? message;
  final List<ChatRoom>? rooms;

  const ChatEvent({
    required this.type,
    this.fromDeviceId,
    this.fromTableName,
    this.roomId,
    this.partnerDeviceId,
    this.partnerTableName,
    this.reason,
    this.message,
    this.rooms,
  });

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = _parseEventType(typeStr);

    ChatMessage? message;
    if (type == ChatEventType.chatMessage) {
      message = ChatMessage.fromJson(json);
    }

    List<ChatRoom>? rooms;
    if (type == ChatEventType.chatRoomsSnapshot) {
      final roomsJson = json['rooms'] as List<dynamic>?;
      if (roomsJson != null) {
        rooms = roomsJson
            .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    }

    return ChatEvent(
      type: type,
      fromDeviceId: json['fromDeviceId'] as String?,
      fromTableName: json['fromTableName'] as String?,
      roomId: json['roomId'] as int?,
      partnerDeviceId: json['partnerDeviceId'] as String?,
      partnerTableName: json['partnerTableName'] as String?,
      reason: json['reason'] as String?,
      message: message,
      rooms: rooms,
    );
  }

  static ChatEventType _parseEventType(String? type) {
    switch (type) {
      case 'CHAT_REQUEST':
        return ChatEventType.chatRequest;
      case 'CHAT_ACCEPTED':
        return ChatEventType.chatAccepted;
      case 'CHAT_REJECTED':
        return ChatEventType.chatRejected;
      case 'CHAT_REQUEST_FAILED':
        return ChatEventType.chatRequestFailed;
      case 'CHAT_ERROR':
        return ChatEventType.chatError;
      case 'CHAT_CLOSED':
        return ChatEventType.chatClosed;
      case 'CHAT_ROOMS_SNAPSHOT':
        return ChatEventType.chatRoomsSnapshot;
      default:
        return ChatEventType.chatMessage;
    }
  }
}

/// 채팅 메시지
class ChatMessage {
  final int? id;
  final int? roomId;
  final String senderDeviceId;
  final String senderTableName;
  final String content;
  final String messageType;
  final DateTime timestamp;

  const ChatMessage({
    this.id,
    this.roomId,
    required this.senderDeviceId,
    required this.senderTableName,
    required this.content,
    required this.messageType,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int?,
      roomId: json['roomId'] as int?,
      senderDeviceId: json['senderDeviceId'] as String? ?? '',
      senderTableName: json['senderTableName'] as String? ?? '',
      content: json['content'] as String? ?? json['message'] as String? ?? '',
      messageType: json['messageType'] as String? ?? json['type'] as String? ?? 'MESSAGE',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now()),
    );
  }
}

/// 채팅방 상태
class ChatRoom {
  final int roomId;
  final String partnerDeviceId;
  final String partnerTableName;
  final List<ChatMessage> messages;

  const ChatRoom({
    required this.roomId,
    required this.partnerDeviceId,
    required this.partnerTableName,
    this.messages = const [],
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final messagesJson = json['messages'] as List<dynamic>? ?? [];
    return ChatRoom(
      roomId: json['roomId'] as int,
      partnerDeviceId: json['partnerDeviceId'] as String? ?? '',
      partnerTableName: json['partnerTableName'] as String? ?? '',
      messages: messagesJson
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  ChatRoom copyWith({
    int? roomId,
    String? partnerDeviceId,
    String? partnerTableName,
    List<ChatMessage>? messages,
  }) {
    return ChatRoom(
      roomId: roomId ?? this.roomId,
      partnerDeviceId: partnerDeviceId ?? this.partnerDeviceId,
      partnerTableName: partnerTableName ?? this.partnerTableName,
      messages: messages ?? this.messages,
    );
  }
}
