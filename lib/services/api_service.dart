import 'dart:convert';
import '../config/api_config.dart';
import '../models/bill_model.dart';
import '../models/notification_model.dart';
import '../models/table_model.dart';
import 'auth_service.dart';
import 'http_client.dart';
import 'server_time.dart';

/// API 서비스 - 순수 HTTP 통신만 담당 (상태 저장 X)
class ApiService {
  final AuthService _authService = AuthService();
  late final AuthenticatedClient _client;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _client = AuthenticatedClient(_authService);
  }

  AuthService get authService => _authService;
  String? get token => _authService.accessToken;
  String? get deviceId => _authService.deviceId;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isConnected => _authService.status == AuthStatus.authenticated;
  AuthStatus get authStatus => _authService.status;

  /// 초기화 - AuthService 초기화 및 디바이스 상태 확인
  Future<bool> initialize() async {
    await _authService.initialize();
    return await _authService.verifyConnection();
  }

  /// 전체 테이블 목록 조회
  Future<List<TableModel>> getTables() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tables}'))
          .timeout(const Duration(seconds: 10));

      // 서버 시간 동기화 (Date 헤더)
      ServerTime.syncFromHttpDate(response.headers['date']);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 테이블 설정 (입장 시)
  Future<bool> setupTable({
    required String tableId,
    required String location,
    required int guestCount,
    required int femaleCount,
    required int maleCount,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tableSetup}'),
          body: jsonEncode({
            'tableId': tableId,
            'location': location,
            'guestCount': guestCount,
            'femaleCount': femaleCount,
            'maleCount': maleCount,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('테이블 설정 실패: ${response.statusCode}');
    }
  }

  /// 테이블 수정 (채팅 상태 등)
  Future<bool> updateTable(String deviceId, Map<String, dynamic> fields) async {
    try {
      final response = await _client
          .patch(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tables}/$deviceId'),
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 채팅 신고
  Future<bool> reportChatRoom({
    required int roomId,
    required String reportedDeviceId,
    required String reason,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.deviceChatRooms}/$roomId/reports',
            ),
            body: jsonEncode({
              'reportedDeviceId': reportedDeviceId,
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<MenuItem>> getMenuItems() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.menuItems}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
            .where((item) => item.isAvailable)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<GiftItem>> getGifts() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.gifts}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((json) => GiftItem.fromJson(json as Map<String, dynamic>))
            .where((item) => item.isAvailable)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Bill?> getCurrentBill(String identifier) async {
    return _getBill('/tables/$identifier/bill');
  }

  Future<Bill?> getCurrentOrders(String identifier) async {
    return _getBill('/tables/$identifier/orders');
  }

  Future<bool> createOrder(
    String identifier,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/tables/$identifier/orders'),
            body: jsonEncode({'items': items}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// 알림 목록 조회
  Future<List<NotificationModel>> getNotifications({int page = 0, int size = 20}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}')
          .replace(queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> content = data['content'] as List<dynamic>? ?? [];
        return content
            .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 읽지 않은 알림 개수 조회
  Future<int> getUnreadCount() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.unreadCount}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unreadCount'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 알림 읽음 처리
  Future<bool> markNotificationRead(int id) async {
    try {
      final response = await _client
          .post(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}/$id/read'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 모든 알림 읽음 처리
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await _client
          .post(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.readAllNotifications}'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Bill?> _getBill(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Bill.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

}
