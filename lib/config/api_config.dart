import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API 설정
class ApiConfig {
  static String get _apiHost => dotenv.env['API_HOST'] ?? '127.0.0.1';
  static String get _apiPort => dotenv.env['API_PORT'] ?? '8080';
  static String get _wsHost => dotenv.env['WS_HOST'] ?? _apiHost;
  static String get _wsPort => dotenv.env['WS_PORT'] ?? _apiPort;

  static bool get _useHttps => dotenv.env['USE_HTTPS'] == 'true';

  static String get baseUrl {
    final protocol = _useHttps ? 'https' : 'http';
    final portPart = (_apiPort == '80' || _apiPort == '443' || _apiPort == '') ? '' : ':$_apiPort';
    return '$protocol://$_apiHost$portPart/api/v1';
  }

  static String get origin {
    final protocol = _useHttps ? 'https' : 'http';
    final portPart = (_apiPort == '80' || _apiPort == '443' || _apiPort == '') ? '' : ':$_apiPort';
    return '$protocol://$_apiHost$portPart';
  }

  static String get wsUrl {
    final protocol = _useHttps ? 'wss' : 'ws';
    final portPart = (_wsPort == '80' || _wsPort == '443' || _wsPort == '') ? '' : ':$_wsPort';
    return '$protocol://$_wsHost$portPart/ws';
  }

  static String get wsBaseUrl {
    final protocol = _useHttps ? 'https' : 'http';
    final portPart = (_wsPort == '80' || _wsPort == '443' || _wsPort == '') ? '' : ':$_wsPort';
    return '$protocol://$_wsHost$portPart/ws';
  }


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
  static const String tableSetup = '/tables/setup';
  static const String tableReset = '/tables'; // + /{tableId}/reset
  static const String deviceChatRooms = '/device/chat/rooms';
  static const String menuItems = '/menu-items';
  static const String gifts = '/gifts';

  // Notification Endpoints
  static const String notifications = '/device/notifications';
  static const String unreadCount = '/device/notifications/unread-count';
  static const String readAllNotifications = '/device/notifications/read-all';

  static String? resolveAssetUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '$origin$value';
    }
    return '$origin/$value';
  }
}
