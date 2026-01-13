import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/table_model.dart';
import 'auth_service.dart';
import 'http_client.dart';

/// API 서비스 - HTTP 통신
class ApiService {
  final AuthService _authService = AuthService();
  late final AuthenticatedClient _client;

  static const String _currentTableKey = 'current_table';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  TableModel? _currentTable;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _client = AuthenticatedClient(_authService);
  }

  AuthService get authService => _authService;
  String? get token => _authService.accessToken;
  String? get deviceId => _authService.deviceId;
  TableModel? get currentTable => _currentTable;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isConnected => _authService.status == AuthStatus.authenticated;
  AuthStatus get authStatus => _authService.status;

  /// 초기화 - AuthService 초기화 및 디바이스 상태 확인
  Future<bool> initialize() async {
    await _authService.initialize();

    // HTTP API로 디바이스 상태 확인 후 로그인
    final connected = await _authService.verifyConnection();

    // 인증 성공 시 서버에서 내 테이블 복원
    if (connected) {
      await getMyTable();
    }

    return connected;
  }

  /// 현재 테이블 정보 저장
  Future<void> _saveCurrentTable() async {
    if (_currentTable != null) {
      await _storage.write(
        key: _currentTableKey,
        value: jsonEncode(_currentTable!.toJson()),
      );
    }
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
      // 서버 연결 실패 - 빈 목록 반환
      return [];
    }
  }

  /// 내 테이블 조회 (디바이스에 연결된 테이블)
  /// - 테이블 있으면 → 저장 후 반환
  /// - 테이블 없으면 → 로컬 스토리지 비우고 null 반환
  Future<TableModel?> getMyTable() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.myTable}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
          _currentTable = TableModel.fromJson(data);
          await _saveCurrentTable();
          return _currentTable;
        }
      }
      // 테이블 없음 → 로컬 데이터 정리
      await resetCurrentTable();
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 테이블 설정 (입장 시)
  Future<void> setupTable({
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
      // 설정 성공 후 실제 테이블 정보 조회
      await getMyTable();
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

  /// 테이블 초기화 (리셋)
  Future<void> resetCurrentTable() async {
    _currentTable = null;
    await _storage.delete(key: _currentTableKey);
  }

  /// 로그아웃
  Future<void> logout() async {
    await _authService.logout();
    _currentTable = null;
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
