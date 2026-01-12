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
    await _loadCurrentTable();

    // HTTP API로 디바이스 상태 확인 후 로그인
    return await _authService.verifyConnection();
  }

  /// 저장된 테이블 정보 로드
  Future<void> _loadCurrentTable() async {
    try {
      final json = await _storage.read(key: _currentTableKey);
      if (json != null) {
        _currentTable = TableModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      // 로드 실패 시 무시
    }
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
      return _getDummyTables();
    } catch (e) {
      // 서버 연결 실패 - 더미 데이터 반환
      return _getDummyTables();
    }
  }

  /// 테이블 설정 (입장 시)
  Future<void> setupTable({
    required String name,
    required String location,
    required int guestCount,
    required int femaleCount,
    required int maleCount,
  }) async {
    // 테이블 ID = 디바이스 ID (PK)
    final tableId = deviceId ?? 'T${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tableSetup}'),
            body: jsonEncode({
              'tableId': tableId,
              'name': name,
              'location': location,
              'guestCount': guestCount,
              'femaleCount': femaleCount,
              'maleCount': maleCount,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _currentTable = TableModel.fromJson(data);
      } else {
        throw Exception('테이블 설정 실패: ${response.statusCode}');
      }
    } catch (e) {
      // 서버 연결 실패 시 로컬에만 저장
      _currentTable = TableModel(
        id: tableId,
        name: name,
        status: TableStatus.occupied,
        guestCount: guestCount,
        location: location,
        isChatting: false,
      );
    }

    // 테이블 정보 영속화
    await _saveCurrentTable();
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

  /// 더미 테이블 목록 (개발용)
  List<TableModel> _getDummyTables() {
    return [
      const TableModel(
        id: 'A1',
        name: 'A1',
        status: TableStatus.occupied,
        guestCount: 4,
        location: '서울',
        isChatting: false,
      ),
      const TableModel(
        id: 'A2',
        name: 'A2',
        status: TableStatus.occupied,
        guestCount: 3,
        location: '부산',
        isChatting: true,
      ),
      const TableModel(id: 'A3', name: 'A3', status: TableStatus.available),
      const TableModel(
        id: 'B1',
        name: 'B1',
        status: TableStatus.occupied,
        guestCount: 6,
        location: '서울',
        isChatting: false,
      ),
      const TableModel(
        id: 'B2',
        name: 'B2',
        status: TableStatus.occupied,
        guestCount: 2,
        location: '인천',
        isChatting: false,
      ),
      const TableModel(id: 'B3', name: 'B3', status: TableStatus.available),
      const TableModel(
        id: 'C1',
        name: 'C1',
        status: TableStatus.occupied,
        guestCount: 5,
        location: '대구',
        isChatting: true,
      ),
      const TableModel(id: 'C2', name: 'C2', status: TableStatus.reserved),
      const TableModel(
        id: 'D1',
        name: 'D1',
        status: TableStatus.occupied,
        guestCount: 2,
        location: '광주',
        isChatting: false,
      ),
      const TableModel(
        id: 'D2',
        name: 'D2',
        status: TableStatus.occupied,
        guestCount: 4,
        location: '대전',
        isChatting: false,
      ),
    ];
  }
}
