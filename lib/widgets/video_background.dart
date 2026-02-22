import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';

/// 비디오 배경 위젯
/// [assetPath] : 로컬 asset 경로 (예: 'assets/videos/bg.mp4') — 네이티브/웹 공통
/// [networkUrl] : 네트워크 URL — assetPath 로드 실패 시 web 전용 폴백
class VideoBackground extends StatefulWidget {
  final String assetPath;
  final Widget child;

  const VideoBackground({
    super.key,
    required this.assetPath,
    required this.child,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(
      widget.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await _controller.initialize();
      _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('[VideoBackground] 영상 로드 실패: $e');
      // 실패 시 그냥 단색 배경으로 폴백
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 비디오 레이어 (로드 전/실패 시 단색 배경)
        if (_isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          Container(color: AppColors.background),

        // 어두운 오버레이
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.overlayLight, AppColors.overlayDark],
            ),
          ),
        ),

        widget.child,
      ],
    );
  }
}
