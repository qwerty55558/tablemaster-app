/// 테이블 상태 enum
enum TableStatus {
  available, // 빈테이블
  occupied, // 이용중
  reserved, // 예약
  chatting, // 채팅중
  inactive, // 연결 끊김
}

/// 테이블 모델
class TableModel {
  final String id;
  final String name;
  final String? deviceName;
  final TableStatus status;
  final int? guestCount;
  final int? femaleCount;
  final int? maleCount;
  final String? location;
  final bool isChatEnabled;
  final bool isChatting;
  final int? chatRoomId;
  final String? chatSanctionType;
  final bool isChatMuted;
  final DateTime? chatSanctionExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TableModel({
    required this.id,
    required this.name,
    this.deviceName,
    required this.status,
    this.guestCount,
    this.femaleCount,
    this.maleCount,
    this.location,
    this.isChatEnabled = false,
    this.isChatting = false,
    this.chatRoomId,
    this.chatSanctionType,
    this.isChatMuted = false,
    this.chatSanctionExpiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceName: json['deviceName'] as String?,
      status: _parseStatus(json['status'] as String?),
      guestCount: json['guestCount'] as int?,
      femaleCount: json['femaleCount'] as int?,
      maleCount: json['maleCount'] as int?,
      location: json['location'] as String?,
      isChatEnabled: json['isChatEnabled'] as bool? ?? false,
      isChatting: json['isChatting'] as bool? ?? false,
      chatRoomId: json['chatRoomId'] as int?,
      chatSanctionType: json['chatSanctionType'] as String?,
      isChatMuted: json['isChatMuted'] as bool? ?? false,
      chatSanctionExpiresAt: json['chatSanctionExpiresAt'] != null
          ? _parseUtc(json['chatSanctionExpiresAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? _parseUtc(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? _parseUtc(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceName': deviceName,
      'status': status.name,
      'guestCount': guestCount,
      'femaleCount': femaleCount,
      'maleCount': maleCount,
      'location': location,
      'isChatEnabled': isChatEnabled,
      'isChatting': isChatting,
      'chatRoomId': chatRoomId,
      'chatSanctionType': chatSanctionType,
      'isChatMuted': isChatMuted,
      'chatSanctionExpiresAt': chatSanctionExpiresAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// 서버 시간을 UTC로 파싱 후 로컬 변환
  static DateTime _parseUtc(String dateStr) {
    final parsed = DateTime.parse(dateStr);
    // 이미 Z 또는 +offset이 포함되어 있으면 그대로, 아니면 UTC로 간주
    return parsed.isUtc ? parsed.toLocal() : DateTime.utc(
      parsed.year, parsed.month, parsed.day,
      parsed.hour, parsed.minute, parsed.second, parsed.millisecond,
    ).toLocal();
  }

  static TableStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return TableStatus.available;
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.occupied;
      case 'chatting':
        return TableStatus.chatting;
      case 'inactive':
        return TableStatus.inactive;
      default:
        return TableStatus.available;
    }
  }

  TableModel copyWith({
    String? id,
    String? name,
    String? deviceName,
    TableStatus? status,
    int? guestCount,
    int? femaleCount,
    int? maleCount,
    String? location,
    bool? isChatEnabled,
    bool? isChatting,
    int? chatRoomId,
    String? chatSanctionType,
    bool? isChatMuted,
    DateTime? chatSanctionExpiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceName: deviceName ?? this.deviceName,
      status: status ?? this.status,
      guestCount: guestCount ?? this.guestCount,
      femaleCount: femaleCount ?? this.femaleCount,
      maleCount: maleCount ?? this.maleCount,
      location: location ?? this.location,
      isChatEnabled: isChatEnabled ?? this.isChatEnabled,
      isChatting: isChatting ?? this.isChatting,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      chatSanctionType: chatSanctionType ?? this.chatSanctionType,
      isChatMuted: isChatMuted ?? this.isChatMuted,
      chatSanctionExpiresAt: chatSanctionExpiresAt ?? this.chatSanctionExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 인증 응답 모델
class AuthResponse {
  final String token;
  final TableModel tableInfo;

  const AuthResponse({required this.token, required this.tableInfo});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      tableInfo: TableModel.fromJson(json['tableInfo'] as Map<String, dynamic>),
    );
  }
}
