import '../config/api_config.dart';

class MenuItem {
  final int id;
  final String name;
  final int price;
  final String category;
  final bool isAvailable;
  final String? imageUrl;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.imageUrl,
  });

  String? get resolvedImageUrl => ApiConfig.resolveAssetUrl(imageUrl);

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['displayName'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      category: json['category'] as String? ?? 'ETC',
      isAvailable: json['isAvailable'] as bool? ?? json['available'] as bool? ?? true,
      imageUrl: _parseImageUrl(json),
    );
  }
}

class GiftItem {
  final int id;
  final String code;
  final String displayName;
  final int price;
  final bool isAvailable;
  final String? imageUrl;

  const GiftItem({
    required this.id,
    required this.code,
    required this.displayName,
    required this.price,
    required this.isAvailable,
    this.imageUrl,
  });

  String? get resolvedImageUrl => ApiConfig.resolveAssetUrl(imageUrl);

  factory GiftItem.fromJson(Map<String, dynamic> json) {
    return GiftItem(
      id: json['id'] as int? ?? 0,
      code: json['code'] as String? ?? json['giftType'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['name'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? json['available'] as bool? ?? true,
      imageUrl: _parseImageUrl(json),
    );
  }
}

class BillOrderItem {
  final int id;
  final int menuItemId;
  final String name;
  final int price;
  final int quantity;
  final String category;
  final String? imageUrl;
  final DateTime? createdAt;

  const BillOrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.category,
    required this.imageUrl,
    required this.createdAt,
  });

  int get subtotal => price * quantity;
  String? get resolvedImageUrl => ApiConfig.resolveAssetUrl(imageUrl);

  factory BillOrderItem.fromJson(Map<String, dynamic> json) {
    return BillOrderItem(
      id: json['id'] as int? ?? 0,
      menuItemId: json['menuItemId'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 0,
      category: json['category'] as String? ?? 'ETC',
      imageUrl: _parseImageUrl(json),
      createdAt: _parseDate(json['createdAt'] as String?),
    );
  }
}

class BillGiftOrderItem {
  final int id;
  final int giftTypeId;
  final String code;
  final String displayName;
  final int price;
  final int quantity;
  final int? chatRoomId;
  final String? imageUrl;
  final DateTime? createdAt;

  const BillGiftOrderItem({
    required this.id,
    required this.giftTypeId,
    required this.code,
    required this.displayName,
    required this.price,
    required this.quantity,
    required this.chatRoomId,
    required this.imageUrl,
    required this.createdAt,
  });

  int get subtotal => price * quantity;
  String? get resolvedImageUrl => ApiConfig.resolveAssetUrl(imageUrl);

  factory BillGiftOrderItem.fromJson(Map<String, dynamic> json) {
    return BillGiftOrderItem(
      id: json['id'] as int? ?? 0,
      giftTypeId: json['giftTypeId'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      quantity: json['quantity'] as int? ?? 0,
      chatRoomId: json['chatRoomId'] as int?,
      imageUrl: _parseImageUrl(json),
      createdAt: _parseDate(json['createdAt'] as String?),
    );
  }
}

class Bill {
  final int id;
  final String deviceId;
  final String tableName;
  final String status;
  final int totalAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final List<BillOrderItem> orderItems;
  final List<BillGiftOrderItem> giftOrders;

  const Bill({
    required this.id,
    required this.deviceId,
    required this.tableName,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.closedAt,
    required this.orderItems,
    required this.giftOrders,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final orderItemsJson = json['orderItems'] as List<dynamic>? ?? const [];
    final giftOrdersJson = json['giftOrders'] as List<dynamic>? ?? const [];

    return Bill(
      id: json['id'] as int? ?? 0,
      deviceId: json['deviceId'] as String? ?? '',
      tableName: json['tableName'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      totalAmount: json['totalAmount'] as int? ?? 0,
      createdAt: _parseDate(json['createdAt'] as String?),
      updatedAt: _parseDate(json['updatedAt'] as String?),
      closedAt: _parseDate(json['closedAt'] as String?),
      orderItems: orderItemsJson
          .map((item) => BillOrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      giftOrders: giftOrdersJson
          .map((item) => BillGiftOrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String? _parseImageUrl(Map<String, dynamic> json) {
  final candidates = [
    json['imageUrl'],
    json['image'],
    json['thumbnailUrl'],
    json['thumbnail'],
    json['photoUrl'],
    json['photo'],
    json['iconUrl'],
    json['icon'],
  ];

  for (final candidate in candidates) {
    final value = candidate as String?;
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
