import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/table_model.dart';

/// API 서비스 - 토큰 기반 인증 및 HTTP 통신
class ApiService {
  static const String _tokenKey = 'auth_token';
  static const String _deviceIdKey = 'device_id';

  String? _token;
  String? _deviceId;
  TableModel? _currentTable;
  bool _isConnected = false;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? get token => _token;
  String? get deviceId => _deviceId;
  TableModel? get currentTable => _currentTable;
  bool get isAuthenticated => _token != null;
  bool get isConnected => _isConnected;

  /// 디바이스 고유 ID 획득
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        // 기타 플랫폼 (웹, 데스크톱 등)
        _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }

    // 로컬에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, _deviceId!);

    return _deviceId!;
  }

  /// 디바이스 ID로 자동 등록 및 토큰 발급
  Future<bool> registerDevice() async {
    final deviceId = await getDeviceId();

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authDevice}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);

        _token = authResponse.token;
        _currentTable = authResponse.tableInfo;
        _isConnected = true;

        // 토큰 로컬 저장
        await _saveToken(authResponse.token);

        return true;
      }
      _isConnected = false;
      return false;
    } catch (e) {
      // 서버 연결 실패 - 로컬 모드로 진행
      _isConnected = false;
      _setDummyData(deviceId);
      return false;
    }
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
    if (!_isConnected) return false;

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

  /// 저장된 토큰 삭제 (앱 시작 시 호출)
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    _currentTable = null;
    _isConnected = false;
  }

  /// 토큰 로컬 저장
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// 더미 데이터 설정 (로컬 모드)
  void _setDummyData(String deviceId) {
    _token = 'local_token_${DateTime.now().millisecondsSinceEpoch}';
    _currentTable = TableModel(
      id: deviceId.substring(0, 6).toUpperCase(),
      name: 'T${deviceId.substring(0, 2).toUpperCase()}',
      status: TableStatus.occupied,
      guestCount: 4,
      location: '로컬',
      isChatting: false,
      updatedAt: DateTime.now(),
    );
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
