/// API 설정
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api/v1';
  static const String wsUrl = 'ws://localhost:3000/ws';

  // Endpoints
  static const String authDevice = '/auth/device';
  static const String tables = '/tables';
  static const String chatRequest = '/chat/request';
}
