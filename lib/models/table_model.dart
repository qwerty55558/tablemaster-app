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
  final String? location;
  final bool isChatting;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TableModel({
    required this.id,
    required this.name,
    this.deviceName,
    required this.status,
    this.guestCount,
    this.location,
    this.isChatting = false,
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
      location: json['location'] as String?,
      isChatting: json['isChatting'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
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
      'location': location,
      'isChatting': isChatting,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static TableStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return TableStatus.available;
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.reserved;
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
    String? location,
    bool? isChatting,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceName: deviceName ?? this.deviceName,
      status: status ?? this.status,
      guestCount: guestCount ?? this.guestCount,
      location: location ?? this.location,
      isChatting: isChatting ?? this.isChatting,
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
