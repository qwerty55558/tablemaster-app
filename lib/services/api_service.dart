import 'dart:convert';
import '../config/api_config.dart';
import '../models/table_model.dart';
import 'auth_service.dart';
import 'http_client.dart';

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

  /// 내 테이블 조회 (디바이스에 연결된 테이블)
  Future<TableModel?> getMyTable() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.myTable}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
          return TableModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 테이블 설정 (입장 시) - 설정된 테이블 반환
  Future<TableModel?> setupTable({
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
      return await getMyTable();
    } else {
      throw Exception('테이블 설정 실패: ${response.statusCode}');
    }
  }

  /// 채팅 요청
  Future<bool> requestChat(String targetTableId) async {
    if (!isConnected) return false;

    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatRequest}'),
            body: jsonEncode({'targetTableId': targetTableId}),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    await _authService.logout();
  }

  /// 재로그인 (토큰 만료 시)
  Future<bool> refreshToken() async {
    return await _authService.refreshAccessToken();
  }

  /// 디바이스 재로그인
  Future<bool> retryLogin() async {
    return await _authService.deviceLogin();
  }
}
