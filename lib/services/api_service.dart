import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/table_model.dart';
import 'auth_service.dart';

/// API 서비스 - HTTP 통신
class ApiService {
  final AuthService _authService = AuthService();

  TableModel? _currentTable;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  AuthService get authService => _authService;
  String? get token => _authService.accessToken;
  String? get deviceId => _authService.deviceId;
  TableModel? get currentTable => _currentTable;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isConnected => _authService.status == AuthStatus.authenticated;
  AuthStatus get authStatus => _authService.status;

  /// 초기화 - AuthService 초기화 및 디바이스 로그인
  Future<bool> initialize() async {
    await _authService.initialize();

    // 이미 인증된 상태면 바로 반환
    if (_authService.isAuthenticated) {
      return true;
    }

    // 디바이스 로그인 시도
    return await _authService.deviceLogin();
  }

  /// 전체 테이블 목록 조회
  Future<List<TableModel>> getTables() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tables}'),
            headers: _authHeaders,
          )
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

  /// 채팅 요청
  Future<bool> requestChat(String targetTableId) async {
    if (!isConnected) return false;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatRequest}'),
            headers: _authHeaders,
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

  Map<String, String> get _authHeaders => _authService.authHeaders;

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
