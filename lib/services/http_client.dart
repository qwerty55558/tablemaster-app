import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// 인증 인터셉터가 적용된 HTTP 클라이언트
/// 모든 요청에 Authorization 헤더 자동 추가
/// 401 응답 시 토큰 갱신 후 재요청
class AuthenticatedClient {
  final AuthService _authService;

  AuthenticatedClient(this._authService);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authService.accessToken != null)
      'Authorization': 'Bearer ${_authService.accessToken}',
  };

  /// GET 요청 (401 시 자동 재발급)
  Future<http.Response> get(Uri url) async {
    var response = await http.get(url, headers: _headers);

    if (response.statusCode == 401) {
      if (await _refreshAndRetry()) {
        response = await http.get(url, headers: _headers);
      }
    }

    return response;
  }

  /// POST 요청 (401 시 자동 재발급)
  Future<http.Response> post(Uri url, {Object? body}) async {
    var response = await http.post(url, headers: _headers, body: body);

    if (response.statusCode == 401) {
      if (await _refreshAndRetry()) {
        response = await http.post(url, headers: _headers, body: body);
      }
    }

    return response;
  }

  /// 토큰 갱신 시도
  Future<bool> _refreshAndRetry() async {
    // 1. 액세스 토큰 갱신 시도
    bool success = await _authService.refreshAccessToken();

    // 2. 실패 시 (리프레시 토큰 만료) → 디바이스 재로그인
    if (!success) {
      success = await _authService.deviceLogin();
    }

    return success;
  }
}
