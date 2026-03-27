import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'websocket_service.dart';

/// 인증 상태
enum AuthStatus {
  /// 초기화 중
  initializing,

  /// 미등록 디바이스 (서버에 등록 필요)
  unregistered,

  /// 등록 대기 중 (관리자 승인 필요)
  pending,

  /// 인증 완료
  authenticated,

  /// 인증 실패 (네트워크 오류 등)
  failed,

  /// 연결 끊김 (일시적 네트워크 단절, 데이터 유지)
  connectionLost,
}

/// 인증 응답 모델
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;
  final String? tokenType;
  final String? deviceName;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
    this.tokenType,
    this.deviceName,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int?,
      tokenType: json['tokenType'] as String?,
      deviceName: json['deviceName'] as String?,
    );
  }
}

/// 인증 서비스 - 디바이스 기반 자동 로그인
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _deviceIdKey = 'device_id';

  // Secure Storage 설정
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;
  String? _deviceName;
  AuthStatus _status = AuthStatus.initializing;
  String? _errorMessage;
  int? _pendingTtl; // 등록 대기 TTL (초)
  Completer<bool>? _refreshLock;
  Timer? _pendingPollTimer; // pending 상태 polling

  // 상태 변경 스트림
  final _statusController = StreamController<AuthStatus>.broadcast();

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Getters
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  int? get pendingTtl => _pendingTtl;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  Stream<AuthStatus> get statusStream => _statusController.stream;

  /// 상태 변경
  void _setStatus(AuthStatus status, [String? error]) {
    _status = status;
    _errorMessage = error;
    _statusController.add(status);
  }

  /// 초기화 - 저장된 토큰 로드 및 디바이스 ID 획득
  /// 토큰이 있어도 서버 검증 전까지는 initializing 상태 유지
  Future<void> initialize() async {
    _setStatus(AuthStatus.initializing);

    try {
      // 저장된 토큰 로드
      _accessToken = await _storage.read(key: _accessTokenKey);
      _refreshToken = await _storage.read(key: _refreshTokenKey);

      // 디바이스 ID 획득
      _deviceId = await _getDeviceId();

      // 토큰이 있어도 서버 검증 전까지는 initializing 유지
      // verifyWebSocketConnection()에서 실제 검증 후 상태 변경
    } catch (e) {
      _setStatus(AuthStatus.failed, '초기화 실패: $e');
    }
  }

  /// 디바이스 ID 획득
  Future<String> _getDeviceId() async {
    // 저장된 ID가 있으면 사용
    final savedId = await _storage.read(key: _deviceIdKey);
    if (savedId != null) return savedId;

    // 새로 획득
    final deviceInfo = DeviceInfoPlugin();
    String deviceId;

    if (kIsWeb) {
      // 웹: UUID 생성하여 사용
      // 브라우저 정보 기반 + UUID로 고유 ID 생성
      deviceId = 'web_${const Uuid().v4()}';
    } else {
      // 네이티브 플랫폼
      final info = await deviceInfo.deviceInfo;
      if (info is AndroidDeviceInfo) {
        deviceId = info.id;
      } else if (info is IosDeviceInfo) {
        deviceId = info.identifierForVendor ?? 'unknown_ios';
      } else {
        deviceId = 'unknown_${const Uuid().v4()}';
      }
    }

    // 저장
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  /// 디바이스 로그인 - 앱 시작 시 자동 호출
  Future<bool> deviceLogin() async {
    if (_deviceId == null) {
      await initialize();
    }

    if (_deviceId == null) {
      _setStatus(AuthStatus.failed, '디바이스 ID를 가져올 수 없습니다');
      return false;
    }

    final appSecret = ApiConfig.appSecret;
    if (appSecret.isEmpty) {
      _setStatus(AuthStatus.failed, 'APP_SECRET이 설정되지 않았습니다');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deviceLogin}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': _deviceId, 'appSecret': appSecret}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tokens = AuthTokens.fromJson(data);

        _deviceName = tokens.deviceName;
        await _saveTokens(tokens);
        _setStatus(AuthStatus.authenticated);
        return true;
      }

      // 401/403: 미등록 또는 비활성화된 디바이스 → 등록 요청
      if (response.statusCode == 401 || response.statusCode == 403) {
        _setStatus(AuthStatus.unregistered, '등록되지 않은 디바이스입니다');
        return false;
      }

      // 기타 에러
      final errorBody = jsonDecode(response.body);
      final message = errorBody['message'] ?? '로그인 실패';
      _setStatus(AuthStatus.failed, message);
      return false;
    } on TimeoutException {
      _setStatus(AuthStatus.failed, '서버 연결 시간 초과');
      return false;
    } catch (e) {
      _setStatus(AuthStatus.failed, '로그인 실패: $e');
      return false;
    }
  }

  /// 디바이스 등록 요청 - 미등록 디바이스일 때 호출
  Future<bool> requestDeviceRegistration({String? deviceName}) async {
    if (_deviceId == null) {
      _setStatus(AuthStatus.failed, '디바이스 ID가 없습니다');
      return false;
    }

    final appSecret = ApiConfig.appSecret;
    if (appSecret.isEmpty) {
      _setStatus(AuthStatus.failed, 'APP_SECRET이 설정되지 않았습니다');
      return false;
    }

    try {
      final body = <String, dynamic>{
        'deviceId': _deviceId,
        'appSecret': appSecret,
      };
      if (deviceName != null) {
        body['deviceName'] = deviceName;
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deviceRegister}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[AUTH] 등록 요청 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ttl = data['ttl'];
        _pendingTtl = ttl is int ? ttl : int.tryParse(ttl?.toString() ?? '');
        _setStatus(AuthStatus.pending, '관리자 승인 대기 중');
        _startPendingPoll();
        return true;
      }

      // 이미 등록된 경우
      if (response.statusCode == 409) {
        // 이미 등록 요청됨 → 상태 확인
        return await checkDeviceStatus();
      }

      String message = '등록 요청 실패';
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        message = errorBody['message'] as String? ?? '등록 요청 실패';
      } catch (_) {}
      _setStatus(AuthStatus.failed, message);
      return false;
    } on TimeoutException {
      _setStatus(AuthStatus.failed, '서버 연결 시간 초과');
      return false;
    } catch (e) {
      _setStatus(AuthStatus.failed, '등록 요청 실패: $e');
      return false;
    }
  }

  /// 디바이스 등록 상태 확인
  Future<bool> checkDeviceStatus() async {
    if (_deviceId == null) {
      return false;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.deviceStatus}/$_deviceId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;

        switch (status) {
          case 'approved':
            // 승인됨 → polling 중지 후 로그인
            _stopPendingPoll();
            return await deviceLogin();

          case 'pending':
            final ttl = data['ttl'];
            _pendingTtl = ttl is int ? ttl : int.tryParse(ttl?.toString() ?? '');
            _setStatus(AuthStatus.pending, '관리자 승인 대기 중');
            // polling은 이미 실행 중이면 유지
            return false;

          case 'not_found':
          default:
            _stopPendingPoll();
            _setStatus(AuthStatus.unregistered, '등록 정보가 없습니다');
            return false;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 디바이스 상태 확인 및 로그인
  Future<bool> verifyConnection() async {
    if (_deviceId == null) {
      _setStatus(AuthStatus.failed, '디바이스 ID가 없습니다');
      return false;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.deviceStatus}/$_deviceId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _setStatus(AuthStatus.failed, '서버 연결 실패');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      switch (status) {
        case 'approved':
          // 승인됨 → 로그인
          return await deviceLogin();

        case 'pending':
          // 대기 중 → polling 시작
          final ttl = data['ttl'];
          _pendingTtl = ttl is int ? ttl : int.tryParse(ttl?.toString() ?? '');
          _setStatus(AuthStatus.pending, '관리자 승인 대기 중');
          _startPendingPoll();
          return false;

        default:
          // 미등록 또는 삭제됨
          await _clearTokens();
          _setStatus(AuthStatus.unregistered, '등록되지 않은 디바이스입니다');
          return false;
      }
    } on TimeoutException {
      _setStatus(AuthStatus.failed, '서버 연결 시간 초과');
      return false;
    } catch (e) {
      _setStatus(AuthStatus.failed, '연결 확인 실패: $e');
      return false;
    }
  }

  /// WebSocket 연결 끊김 알림 (일시적 네트워크 단절)
  /// 재연결 실패 시 호출 - 데이터는 유지하고 재연결을 계속 시도
  void notifyConnectionLost() {
    _setStatus(AuthStatus.connectionLost, 'WebSocket 연결이 끊어졌습니다');
  }

  /// WebSocket 연결로 화이트리스트 검증
  /// HTTP 로그인 성공 후 호출하여 실제 연결 가능 여부 확인
  Future<bool> verifyWebSocketConnection() async {
    if (_accessToken == null) {
      _setStatus(AuthStatus.failed, '토큰이 없습니다');
      return false;
    }

    final wsService = WebSocketService();
    final result = await wsService.connect();

    switch (result) {
      case WebSocketConnectionResult.success:
        // WebSocket 연결 성공 = 화이트리스트 검증 완료
        _setStatus(AuthStatus.authenticated);
        return true;

      case WebSocketConnectionResult.noToken:
        _setStatus(AuthStatus.unregistered, '인증 토큰이 없습니다');
        return false;

      case WebSocketConnectionResult.failed:
        // WebSocket 연결 실패 = 화이트리스트 미등록 또는 네트워크 오류
        final error = wsService.lastConnectionError ?? 'WebSocket 연결 실패';
        _setStatus(AuthStatus.failed, error);
        return false;
    }
  }

  /// 토큰 갱신 (동시 호출 시 하나만 실행)
  Future<bool> refreshAccessToken() async {
    if (_refreshLock != null) return _refreshLock!.future;

    _refreshLock = Completer<bool>();
    try {
      final result = await _doRefreshAccessToken();
      _refreshLock!.complete(result);
      return result;
    } catch (e) {
      _refreshLock!.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }

  Future<bool> _doRefreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refresh}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tokens = AuthTokens.fromJson(data);

        await _saveTokens(tokens);
        _setStatus(AuthStatus.authenticated);
        return true;
      }

      // 리프레시 토큰도 만료된 경우 다시 디바이스 로그인
      if (response.statusCode == 401) {
        return await deviceLogin();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    try {
      if (_accessToken != null) {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      // 서버 연결 실패해도 로컬 토큰은 삭제
    }

    await _clearTokens();
    _setStatus(AuthStatus.initializing);
  }

  /// 디바이스 삭제 처리 (서버에서 DEVICE_DELETED 수신 시)
  Future<void> handleDeviceDeleted() async {
    debugPrint('[AUTH] 디바이스 삭제 감지 → 토큰 초기화 후 재등록 요청');
    await _clearTokens();
    _setStatus(AuthStatus.unregistered, '디바이스가 삭제되었습니다');
    // 자동 재등록 요청 → pending 상태로 전환 후 관리자 승인 polling 시작
    await requestDeviceRegistration();
  }

  /// 토큰 저장
  Future<void> _saveTokens(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;

    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }

  /// 토큰 삭제
  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;

    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Authorization 헤더 반환
  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  /// pending 상태 polling 시작 (5초마다 상태 확인)
  void _startPendingPoll() {
    _stopPendingPoll();
    debugPrint('[AUTH] pending polling 시작');
    _pendingPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        if (_status == AuthStatus.pending) {
          debugPrint('[AUTH] pending 상태 확인 중...');
          await checkDeviceStatus();
        } else {
          _stopPendingPoll();
        }
      },
    );
  }

  /// pending 상태 polling 중지
  void _stopPendingPoll() {
    if (_pendingPollTimer != null) {
      debugPrint('[AUTH] pending polling 중지');
      _pendingPollTimer?.cancel();
      _pendingPollTimer = null;
    }
  }

  /// 리소스 해제
  void dispose() {
    _stopPendingPoll();
    _statusController.close();
  }
}
