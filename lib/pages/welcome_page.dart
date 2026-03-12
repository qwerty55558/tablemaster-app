import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../providers/providers.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/video_background.dart';
import 'matching_page.dart';
import 'setup_page.dart';

/// 메인 환영 페이지 - 스크린세이버 역할
class WelcomePage extends ConsumerStatefulWidget {
  final AuthStatus authStatus;

  const WelcomePage({super.key, required this.authStatus});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with SingleTickerProviderStateMixin {
  static const String _videoAsset = 'assets/videos/bg.mp4';

  late AnimationController _swipeHintController;
  late Animation<double> _swipeHintAnimation;

  @override
  void initState() {
    super.initState();

    _swipeHintController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _swipeHintAnimation = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _swipeHintController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _swipeHintController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextPage() async {
    final authStatus = ref.read(currentAuthStatusProvider);
    final wasDisconnected = authStatus == AuthStatus.connectionLost ||
        authStatus == AuthStatus.failed;

    // 인증되지 않은 상태 → 인증 시도 후 진행
    if (authStatus != AuthStatus.authenticated) {
      await _handleConnectionTap();
      // 인증 실패 시 진행 차단
      final newStatus = ref.read(authServiceProvider).status;
      if (newStatus != AuthStatus.authenticated) return;
    }

    // 재연결 시 reconnect 델타 전송
    if (wasDisconnected) {
      WebSocketService().sendReconnectDelta();
    }

    final currentTable = ref.read(currentTableProvider);

    // 재연결인데 테이블이 없으면 → 네비게이션 안 함 (연결 확인만)
    if (wasDisconnected && currentTable == null) return;

    // 테이블 있으면 MatchingPage, 없으면 SetupPage
    final Widget destination = currentTable != null
        ? const MatchingPage()
        : const SetupPage();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _handleConnectionTap() async {
    final isRetrying = ref.read(isRetryingProvider);
    if (isRetrying) return;

    final authService = ref.read(authServiceProvider);
    final currentStatus = authService.status;

    ref.read(isRetryingProvider.notifier).state = true;

    bool success = false;

    switch (currentStatus) {
      case AuthStatus.unregistered:
        // 미등록 → 등록 요청
        success = await authService.requestDeviceRegistration();
        break;

      case AuthStatus.pending:
        // 대기 중 → 상태 확인
        success = await authService.checkDeviceStatus();
        break;

      case AuthStatus.failed:
        // 실패 → 재로그인 시도
        success = await authService.deviceLogin();
        break;

      case AuthStatus.connectionLost:
        // 연결 끊김 → 재로그인 + WS 연결 + 테이블 동기화 완료까지 대기
        success = await authService.deviceLogin();
        if (success) {
          final wsResult = await WebSocketService().connectAndSync();
          success = wsResult == WebSocketConnectionResult.success;
        }
        break;

      case AuthStatus.authenticated:
        // 연결 상태 재확인 (HTTP API로)
        success = await authService.verifyConnection();
        break;

      default:
        break;
    }

    ref.read(isRetryingProvider.notifier).state = false;
    _showStatusToast(success);
  }

  void _showStatusToast(bool success) {
    final authService = ref.read(authServiceProvider);

    if (success && authService.status == AuthStatus.authenticated) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('연결 성공'),
            subtitle: const Text('서버에 연결되었습니다'),
            leading: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
          ),
        ),
      );
    } else if (authService.status == AuthStatus.pending) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('등록 요청됨'),
            subtitle: const Text('관리자 승인을 기다리고 있습니다'),
            leading: const Icon(
              Icons.hourglass_empty,
              color: Color(0xFFF59E0B),
            ),
          ),
        ),
      );
    } else if (authService.status == AuthStatus.failed) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('연결 실패'),
            subtitle: Text(authService.errorMessage ?? '서버에 연결할 수 없습니다'),
            leading: const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetrying = ref.watch(isRetryingProvider);

    return Scaffold(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // 위로 스와이프 감지 (velocity < -300)
          if (details.velocity.pixelsPerSecond.dy < -300) {
            _navigateToNextPage();
          }
        },
        child: VideoBackground(
          assetPath: _videoAsset,
          child: SafeArea(
            child: Stack(
              children: [
                // 메인 콘텐츠
                SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // 환영합니다 텍스트
                      const _WelcomeTitle(),

                      const SizedBox(height: 48),

                      // 시작하기 버튼
                      PrimaryButton(
                        onPressed: _navigateToNextPage,
                        size: ButtonSize.large,
                        child: const Text('시작하기'),
                      ),

                      const Spacer(flex: 2),

                      // 스와이프 힌트
                      AnimatedBuilder(
                        animation: _swipeHintAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _swipeHintAnimation.value),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.keyboard_arrow_up,
                              size: 32,
                              color: const Color(
                                0xFFA1A1AA,
                              ).withValues(alpha: 0.7),
                            ),
                            Text(
                              '위로 스와이프',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(
                                  0xFFA1A1AA,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),

                // 상단 우측 아이콘들
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    children: [
                      // 알림 아이콘
                      GhostButton(
                        density: ButtonDensity.icon,
                        onPressed: () {},
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Color(0xFFFAFAFA),
                        ),
                      ),

                      // 연결 상태 인디케이터
                      GhostButton(
                        density: ButtonDensity.icon,
                        onPressed: isRetrying ? null : _handleConnectionTap,
                        child: isRetrying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFA1A1AA),
                                ),
                              )
                            : ConnectionIndicator(status: widget.authStatus),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 환영 타이틀 텍스트
class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '환영합니다',
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFAFAFA),
        letterSpacing: -1.5,
        shadows: [
          Shadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0xCC000000)),
          Shadow(
            offset: Offset(0, 4),
            blurRadius: 16,
            color: Color(0x80000000),
          ),
        ],
      ),
    );
  }
}
