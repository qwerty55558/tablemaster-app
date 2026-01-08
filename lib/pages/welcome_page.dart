import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../services/api_service.dart';
import '../widgets/video_background.dart';
import 'matching_page.dart';

/// 메인 환영 페이지 - 스크린세이버 역할
class WelcomePage extends StatefulWidget {
  final bool isConnected;

  const WelcomePage({super.key, required this.isConnected});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  // 미니멀 다크 파티클 영상 (Pexels 무료)
  static const String _videoUrl =
      'https://videos.pexels.com/video-files/3129671/3129671-sd_640_360_30fps.mp4';

  late AnimationController _swipeHintController;
  late Animation<double> _swipeHintAnimation;

  late bool _isConnected;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.isConnected;

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

  void _navigateToMatching() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MatchingPage(),
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

  Future<void> _retryConnection() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    final success = await ApiService().registerDevice();

    if (mounted) {
      setState(() {
        _isConnected = success;
        _isRetrying = false;
      });

      if (success) {
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
      } else {
        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              title: const Text('연결 실패'),
              subtitle: const Text('로컬 모드로 계속 진행합니다'),
              leading: const Icon(
                Icons.error_outline,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // 위로 스와이프 감지 (velocity < -300)
          if (details.velocity.pixelsPerSecond.dy < -300) {
            _navigateToMatching();
          }
        },
        child: VideoBackground(
          videoUrl: _videoUrl,
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
                        onPressed: _navigateToMatching,
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

                      // 연결 실패 시 중지 아이콘
                      if (!_isConnected)
                        GhostButton(
                          density: ButtonDensity.icon,
                          onPressed: _isRetrying ? null : _retryConnection,
                          child: _isRetrying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFF59E0B),
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_off,
                                  color: Color(0xFFEF4444),
                                ),
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
