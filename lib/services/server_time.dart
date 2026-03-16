/// 서버 시간 동기화 유틸리티
///
/// 디바이스 시계가 틀어져도 서버 시간 기준으로 정확한 경과 시간을 계산한다.
/// HTTP 응답의 Date 헤더 또는 서버 타임스탬프로 오프셋을 보정한다.
class ServerTime {
  ServerTime._();

  /// 서버 시간 - 디바이스 시간 (밀리초)
  /// 양수 = 서버가 디바이스보다 빠름, 음수 = 디바이스가 서버보다 빠름
  static int _offsetMs = 0;

  /// 동기화 완료 여부
  static bool _synced = false;

  bool get isSynced => _synced;

  /// HTTP Date 헤더로 오프셋 보정
  static void syncFromHttpDate(String? dateHeader) {
    if (dateHeader == null) return;
    try {
      final serverTime = _parseHttpDate(dateHeader);
      _offsetMs = serverTime.millisecondsSinceEpoch -
          DateTime.now().millisecondsSinceEpoch;
      _synced = true;
      print('[ServerTime] 동기화 완료: offset=${_offsetMs}ms '
          '(${_offsetMs > 0 ? "디바이스가 느림" : "디바이스가 빠름"})');
    } catch (e) {
      print('[ServerTime] Date 헤더 파싱 실패: $e');
    }
  }

  /// 서버 타임스탬프로 오프셋 보정 (ISO8601)
  static void syncFromTimestamp(DateTime serverTime) {
    _offsetMs = serverTime.toUtc().millisecondsSinceEpoch -
        DateTime.now().toUtc().millisecondsSinceEpoch;
    _synced = true;
  }

  /// 보정된 현재 시간 (서버 시간 기준)
  static DateTime now() {
    return DateTime.now().add(Duration(milliseconds: _offsetMs));
  }

  /// HTTP Date 헤더 파싱 (RFC 7231)
  /// 예: "Sun, 16 Mar 2026 00:30:55 GMT"
  static DateTime _parseHttpDate(String dateStr) {
    return _parseRfc7231(dateStr);
  }

  static DateTime _parseRfc7231(String dateStr) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };

    // "Sun, 16 Mar 2026 00:30:55 GMT"
    final parts = dateStr.split(' ');
    if (parts.length >= 5) {
      final day = int.parse(parts[1]);
      final month = months[parts[2]] ?? 1;
      final year = int.parse(parts[3]);
      final timeParts = parts[4].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = int.parse(timeParts[2]);
      return DateTime.utc(year, month, day, hour, minute, second);
    }

    throw FormatException('Invalid HTTP date: $dateStr');
  }
}
