import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/info_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/shadcn_button.dart';

/// 정보 페이지 - shadcn 스타일 카드 레이아웃
class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: _InfoContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Information'),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }
}

/// 정보 페이지 콘텐츠
class _InfoContent extends StatelessWidget {
  const _InfoContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderSection(),
        SizedBox(height: 32),
        _CardListSection(),
        SizedBox(height: 32),
        _StatsSection(),
        SizedBox(height: 32),
        _UpdatesSection(),
      ],
    );
  }
}

/// 헤더 섹션
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard Overview',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Welcome to your personal dashboard. Here you can find all the information you need.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.foregroundMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 카드 목록 섹션
class _CardListSection extends StatelessWidget {
  const _CardListSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        InfoCard(
          icon: Icons.analytics_outlined,
          title: 'Analytics',
          description:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore.',
        ),
        SizedBox(height: 16),
        InfoCard(
          icon: Icons.people_outline,
          title: 'Team Members',
          description:
              'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo.',
        ),
        SizedBox(height: 16),
        InfoCard(
          icon: Icons.settings_outlined,
          title: 'Settings',
          description:
              'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
        ),
        SizedBox(height: 16),
        InfoCard(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          description:
              'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim.',
        ),
      ],
    );
  }
}

/// 통계 섹션
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Stats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(value: '2,847', label: 'Total Users'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(value: '12.5%', label: 'Growth'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(value: '98.2%', label: 'Uptime'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 업데이트 섹션
class _UpdatesSection extends StatelessWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(),
          const SizedBox(height: 12),
          const Text(
            'Latest Updates',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam euismod, nisi vel consectetur interdum, nisl nunc egestas nunc, vitae tincidunt nisl nunc euismod nunc.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.foregroundMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const ShadcnButton(text: 'Learn More'),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'New',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.success,
        ),
      ),
    );
  }
}
