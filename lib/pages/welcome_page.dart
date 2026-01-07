import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/video_background.dart';
import '../widgets/shadcn_button.dart';
import 'info_page.dart';

/// 메인 환영 페이지
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const String _videoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackground(
        videoUrl: _videoUrl,
        child: Center(
          child: _WelcomeContent(
            onStartPressed: () => _navigateToInfo(context),
          ),
        ),
      ),
    );
  }

  void _navigateToInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InfoPage()),
    );
  }
}

/// 환영 페이지 콘텐츠 (StatelessWidget)
class _WelcomeContent extends StatelessWidget {
  final VoidCallback onStartPressed;

  const _WelcomeContent({required this.onStartPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _WelcomeTitle(),
        const SizedBox(height: 16),
        const _WelcomeSubtitle(),
        const SizedBox(height: 48),
        ShadcnButton(text: '시작하기', onTap: onStartPressed),
      ],
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
        color: AppColors.foreground,
        letterSpacing: -1.5,
        shadows: [
          Shadow(
            offset: Offset(0, 2),
            blurRadius: 8,
            color: AppColors.shadowStrong,
          ),
          Shadow(
            offset: Offset(0, 4),
            blurRadius: 16,
            color: AppColors.shadowMedium,
          ),
        ],
      ),
    );
  }
}

/// 환영 서브타이틀 텍스트
class _WelcomeSubtitle extends StatelessWidget {
  const _WelcomeSubtitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'shadcn 스타일의 Flutter 앱입니다',
      style: TextStyle(
        fontSize: 18,
        color: Color(0xFFE4E4E7),
        fontWeight: FontWeight.w400,
        shadows: [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 4,
            color: AppColors.shadowStrong,
          ),
        ],
      ),
    );
  }
}
