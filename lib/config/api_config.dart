import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API 설정
class ApiConfig {
  static String get _apiHost => dotenv.env['API_HOST'] ?? '127.0.0.1';
  static String get _apiPort => dotenv.env['API_PORT'] ?? '8080';
  static String get _wsHost => dotenv.env['WS_HOST'] ?? _apiHost;
  static String get _wsPort => dotenv.env['WS_PORT'] ?? _apiPort;

  static String get baseUrl => 'http://$_apiHost:$_apiPort/api/v1';
  static String get wsUrl => 'ws://$_wsHost:$_wsPort/ws';
  static String get wsBaseUrl => 'http://$_wsHost:$_wsPort/ws';  // STOMP + SockJS용

  // App Secret (디바이스 인증용)
  static String get appSecret => dotenv.env['APP_SECRET'] ?? '';

  // Auth Endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';
  static const String signup = '/auth/signup';
  static const String checkEmail = '/auth/check-email';

  // Device Auth Endpoints
  static const String deviceLogin = '/auth/device/login';
  static const String deviceRegister = '/auth/device/register';
  static const String deviceStatus = '/auth/device/status'; // + /{deviceId}

  // Business Endpoints
  static const String tables = '/tables';
  static const String myTable = '/tables/my';
  static const String tableSetup = '/tables/setup';
  static const String tableReset = '/tables'; // + /{tableId}/reset
  static const String chatRequest = '/chat/request';
}
