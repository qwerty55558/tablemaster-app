import 'package:flutter/material.dart';

/// TableMaster 색상 팔레트
/// 관리툴 스크린샷 기반 색상 매칭
class AppColors {
  AppColors._();

  // Background
  static const Color background = Color(0xFF0F0F0F);
  static const Color backgroundSecondary = Color(0xFF1A1A1A);
  static const Color backgroundCard = Color(0xFF1F1F23);

  // Foreground (Text)
  static const Color foreground = Color(0xFFFAFAFA);
  static const Color foregroundMuted = Color(0xFFA1A1AA);
  static const Color foregroundSubtle = Color(0xFF71717A);

  // Border
  static const Color border = Color(0xFF27272A);
  static const Color borderLight = Color(0xFF3F3F46);

  // Primary (White button style)
  static const Color primary = Color(0xFFFAFAFA);
  static const Color primaryForeground = Color(0xFF0F0F0F);

  // Table Status Colors (관리툴 매칭)
  static const Color tableOccupied = Color(0xFF4ADE80); // 이용중 - 연한 초록
  static const Color tableOccupiedBg = Color(0x264ADE80); // 이용중 배경
  static const Color tableAvailable = Color(0xFF3F3F46); // 빈테이블 - 회색
  static const Color tableAvailableBg = Color(0xFF27272A); // 빈테이블 배경
  static const Color tableReserved = Color(0xFFF59E0B); // 예약 - 주황
  static const Color tableReservedBg = Color(0x26F59E0B); // 예약 배경
  static const Color tableChatting = Color(0xFF3B82F6); // 채팅중 - 파랑
  static const Color tableChattingBg = Color(0x263B82F6); // 채팅중 배경

  // Badge Colors
  static const Color badgeLive = Color(0xFF22D3EE); // Live 뱃지 - 시안
  static const Color badgeLiveBg = Color(0x2622D3EE);
  static const Color badgeWaiting = Color(0xFFF87171); // 대기 뱃지 - 연한 빨강
  static const Color badgeWaitingBg = Color(0x26F87171);

  // Status Colors
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Overlay
  static const Color overlayLight = Color(0x4D000000);
  static const Color overlayDark = Color(0xB3000000);

  // Shadows
  static const Color shadowStrong = Color(0xCC000000);
  static const Color shadowMedium = Color(0x80000000);
  static const Color shadowLight = Color(0x66000000);
}
