import 'package:flutter/material.dart';

/// shadcn 스타일 색상 팔레트
/// https://ui.shadcn.com/colors
class AppColors {
  AppColors._();

  // Background
  static const Color background = Color(0xFF09090B);
  static const Color backgroundSecondary = Color(0xFF18181B); // zinc-900

  // Foreground (Text)
  static const Color foreground = Color(0xFFFAFAFA); // zinc-50
  static const Color foregroundMuted = Color(0xFFA1A1AA); // zinc-400
  static const Color foregroundSubtle = Color(0xFF71717A); // zinc-500

  // Border
  static const Color border = Color(0xFF27272A); // zinc-800

  // Primary (White button style)
  static const Color primary = Color(0xFFFAFAFA);
  static const Color primaryForeground = Color(0xFF09090B);

  // Accent colors
  static const Color success = Color(0xFF22C55E); // green-500
  static const Color successBackground = Color(0x2622C55E); // 15% opacity

  // Overlay
  static const Color overlayLight = Color(0x4D000000); // 30%
  static const Color overlayDark = Color(0xB3000000); // 70%

  // Shadows
  static const Color shadowStrong = Color(0xCC000000); // 80%
  static const Color shadowMedium = Color(0x80000000); // 50%
  static const Color shadowLight = Color(0x66000000); // 40%
}
