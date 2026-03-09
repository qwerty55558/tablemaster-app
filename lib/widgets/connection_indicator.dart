import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../services/auth_service.dart';

/// 연결 상태 인디케이터 위젯
/// - authenticated: 녹색 클라우드 (연결됨)
/// - pending: 회색 클라우드 + ... (승인 대기)
/// - unregistered: 회색 클라우드 + ? (미등록)
/// - failed: 빨간 클라우드 + X (연결 실패)
/// - initializing: 회색 클라우드 + 로딩 (초기화 중)
class ConnectionIndicator extends StatelessWidget {
  final AuthStatus status;
  final VoidCallback? onTap;
  final bool showLabel;

  const ConnectionIndicator({
    super.key,
    required this.status,
    this.onTap,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          if (showLabel) ...[
            const SizedBox(width: 8),
            Text(
              _getLabel(),
              style: TextStyle(
                fontSize: 12,
                color: _getColor().withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon() {
    final color = _getColor();

    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.cloud, size: 28, color: color),
        if (_getOverlayWidget() != null)
          Positioned(bottom: 2, right: 0, child: _getOverlayWidget()!),
      ],
    );
  }

  Color _getColor() {
    switch (status) {
      case AuthStatus.authenticated:
        return const Color(0xFF22C55E); // green-500
      case AuthStatus.pending:
        return const Color(0xFF71717A); // zinc-500
      case AuthStatus.unregistered:
        return const Color(0xFF71717A); // zinc-500
      case AuthStatus.failed:
        return const Color(0xFFEF4444); // red-500
      case AuthStatus.connectionLost:
        return const Color(0xFFF59E0B); // amber-500
      case AuthStatus.initializing:
        return const Color(0xFF71717A); // zinc-500
    }
  }

  Widget? _getOverlayWidget() {
    switch (status) {
      case AuthStatus.authenticated:
        return null; // 아이콘만 표시
      case AuthStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '...',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFA1A1AA),
              height: 1,
            ),
          ),
        );
      case AuthStatus.unregistered:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18181B),
                height: 1,
              ),
            ),
          ),
        );
      case AuthStatus.failed:
        return Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.close, size: 10, color: Color(0xFFFAFAFA)),
          ),
        );
      case AuthStatus.connectionLost:
        return Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFFF59E0B),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.wifi_off, size: 10, color: Color(0xFF18181B)),
          ),
        );
      case AuthStatus.initializing:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFA1A1AA),
          ),
        );
    }
  }

  String _getLabel() {
    switch (status) {
      case AuthStatus.authenticated:
        return '연결됨';
      case AuthStatus.pending:
        return '승인 대기';
      case AuthStatus.unregistered:
        return '미등록';
      case AuthStatus.failed:
        return '연결 실패';
      case AuthStatus.connectionLost:
        return '재연결 중';
      case AuthStatus.initializing:
        return '연결 중...';
    }
  }
}

/// 연결 상태에 따른 툴팁 메시지
String getConnectionTooltip(AuthStatus status) {
  switch (status) {
    case AuthStatus.authenticated:
      return '서버에 연결되었습니다';
    case AuthStatus.pending:
      return '관리자 승인을 기다리고 있습니다';
    case AuthStatus.unregistered:
      return '디바이스가 등록되지 않았습니다\n탭하여 재시도';
    case AuthStatus.failed:
      return '서버 연결에 실패했습니다\n탭하여 재시도';
    case AuthStatus.connectionLost:
      return '네트워크 연결이 끊어졌습니다\n자동 재연결 시도 중...';
    case AuthStatus.initializing:
      return '서버에 연결 중입니다...';
  }
}
