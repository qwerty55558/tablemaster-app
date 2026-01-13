import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/table_model.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

/// 매칭 페이지 - 사이드바 + 메인 콘텐츠 레이아웃
class MatchingPage extends ConsumerStatefulWidget {
  const MatchingPage({super.key});

  @override
  ConsumerState<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends ConsumerState<MatchingPage> {

  /// 테이블 삭제 이벤트 처리 - 메인으로 리다이렉트
  void _handleTableDeleted(String tableId) {
    // 1. Provider 상태 초기화
    ref.read(currentTableProvider.notifier).clear();

    // 2. 토스트 표시
    showToast(
      context: context,
      builder: (context, overlay) => SurfaceCard(
        child: Basic(
          title: const Text('테이블 삭제'),
          subtitle: const Text('관리자에 의해 테이블이 삭제되었습니다'),
          leading: const Icon(Icons.warning_amber, color: AppColors.warning),
        ),
      ),
    );

    // 3. 메인 페이지로 이동
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onTableTap(TableModel table) {
    ref.read(selectedTableProvider.notifier).state = table;
  }

  Future<void> _requestChat(TableModel table) async {
    final apiService = ref.read(apiServiceProvider);
    final success = await apiService.requestChat(table.id);

    if (success) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('채팅 요청 완료'),
            subtitle: Text('${table.name} 테이블에 요청을 보냈습니다'),
            leading: const Icon(Icons.check_circle, color: AppColors.success),
          ),
        ),
      );
    } else {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('요청 실패'),
            subtitle: const Text('다시 시도해주세요'),
            leading: const Icon(Icons.error, color: AppColors.error),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 테이블 삭제 이벤트 구독 (ref.listen으로 side effect 처리)
    ref.listen<AsyncValue<String>>(tableDeletedProvider, (previous, next) {
      next.whenData((tableId) => _handleTableDeleted(tableId));
    });

    // 테이블 목록 (HTTP fallback + WebSocket 실시간)
    final tables = ref.watch(tablesProvider);
    final currentTable = ref.watch(currentTableProvider);
    final otherTables = tables.where((t) => t.id != currentTable?.id).toList();
    final selectedTable = ref.watch(selectedTableProvider);
    final isConnected = ref.watch(currentAuthStatusProvider) == AuthStatus.authenticated;

    return Scaffold(
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Row(
                  children: [
                    // 좌측 사이드바 - 테이블 목록
                    _TableSidebar(
                      currentTable: currentTable,
                      tables: otherTables,
                      selectedTable: selectedTable,
                      onTableTap: _onTableTap,
                      onBack: () => Navigator.pop(context),
                      isConnected: isConnected,
                    ),

                    // 우측 메인 콘텐츠
                    Expanded(
                      child: _MainContent(
                        selectedTable: selectedTable,
                        currentTable: currentTable,
                        onChatRequest: selectedTable != null
                            ? () => _requestChat(selectedTable)
                            : null,
                        onClose: () =>
                            ref.read(selectedTableProvider.notifier).state = null,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 좌측 사이드바 - 테이블 목록
class _TableSidebar extends StatelessWidget {
  final TableModel? currentTable;
  final List<TableModel> tables;
  final TableModel? selectedTable;
  final void Function(TableModel) onTableTap;
  final VoidCallback onBack;
  final bool isConnected;

  const _TableSidebar({
    required this.currentTable,
    required this.tables,
    required this.selectedTable,
    required this.onTableTap,
    required this.onBack,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // 헤더
          _buildHeader(),

          // 현재 테이블 정보
          if (currentTable != null) _buildCurrentTable(currentTable!),

          const Divider(color: AppColors.border, height: 1),

          // 테이블 현황 타이틀
          _buildSectionTitle(),

          // 테이블 목록
          Expanded(child: _buildTableList()),

          // 하단 범례
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GhostButton(
            density: ButtonDensity.icon,
            onPressed: onBack,
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.foreground,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '테이블 매칭',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
          ),
          if (!isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 12, color: AppColors.error),
                  SizedBox(width: 4),
                  Text(
                    '오프라인',
                    style: TextStyle(fontSize: 10, color: AppColors.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentTable(TableModel table) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.tableOccupied.withValues(alpha: 0.15),
            AppColors.tableOccupied.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.tableOccupied.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tableOccupied.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                table.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tableOccupied,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 테이블',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.foregroundMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${table.name} 테이블',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (table.guestCount != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            size: 12,
                            color: AppColors.foregroundMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${table.guestCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            '테이블 현황',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${tables.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList() {
    if (tables.isEmpty) {
      return const Center(
        child: Text(
          '주변에 다른 테이블이 없습니다',
          style: TextStyle(fontSize: 14, color: AppColors.foregroundMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final isSelected = selectedTable?.id == table.id;
        return _TableListItem(
          table: table,
          isSelected: isSelected,
          onTap: () => onTableTap(table),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _LegendDot(color: AppColors.tableOccupied, label: '이용중'),
          _LegendDot(color: AppColors.tableAvailable, label: '빈테이블'),
          _LegendDot(color: AppColors.tableReserved, label: '예약'),
        ],
      ),
    );
  }
}

/// 테이블 목록 아이템
class _TableListItem extends StatelessWidget {
  final TableModel table;
  final bool isSelected;
  final VoidCallback onTap;

  const _TableListItem({
    required this.table,
    required this.isSelected,
    required this.onTap,
  });

  Color get _statusColor {
    switch (table.status) {
      case TableStatus.available:
        return AppColors.tableAvailable;
      case TableStatus.occupied:
        return AppColors.tableOccupied;
      case TableStatus.reserved:
        return AppColors.tableReserved;
      case TableStatus.chatting:
        return AppColors.tableChatting;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? _statusColor.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _statusColor.withValues(alpha: 0.5)
                : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // 테이블 이름
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  table.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 상태 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                        ),
                      ),
                      if (table.isChatting) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chat_bubble,
                          size: 12,
                          color: AppColors.tableChatting,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (table.guestCount != null) ...[
                        Icon(
                          Icons.people_outline,
                          size: 12,
                          color: AppColors.foregroundMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${table.guestCount}명',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.foregroundMuted,
                          ),
                        ),
                      ],
                      if (table.location != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          table.location!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.foregroundSubtle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 화살표
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isSelected ? _statusColor : AppColors.foregroundSubtle,
            ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    switch (table.status) {
      case TableStatus.available:
        return '빈테이블';
      case TableStatus.occupied:
        return '이용중';
      case TableStatus.reserved:
        return '예약';
      case TableStatus.chatting:
        return '채팅중';
    }
  }
}

/// 범례 점
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.foregroundMuted,
          ),
        ),
      ],
    );
  }
}

/// 우측 메인 콘텐츠
class _MainContent extends StatelessWidget {
  final TableModel? selectedTable;
  final TableModel? currentTable;
  final VoidCallback? onChatRequest;
  final VoidCallback onClose;

  const _MainContent({
    required this.selectedTable,
    required this.currentTable,
    required this.onChatRequest,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedTable == null) {
      return _buildEmptyState();
    }

    return _buildTableDetail(selectedTable!);
  }

  Widget _buildEmptyState() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.touch_app_outlined,
                size: 36,
                color: AppColors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '테이블을 선택하세요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '좌측 목록에서 테이블을 선택하면\n상세 정보를 확인할 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.foregroundMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableDetail(TableModel table) {
    final statusColor = _getStatusColor(table.status);
    final isInteractive = table.status != TableStatus.available;

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      table.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${table.name} 테이블',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(table.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                GhostButton(
                  density: ButtonDensity.icon,
                  onPressed: onClose,
                  child: const Icon(
                    Icons.close,
                    color: AppColors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),

          // 상세 정보
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '테이블 정보',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 정보 카드들
                  _InfoCard(
                    icon: Icons.people_outline,
                    label: '인원',
                    value: table.guestCount != null
                        ? '${table.guestCount}명'
                        : '-',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.location_on_outlined,
                    label: '지역',
                    value: table.location ?? '-',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.chat_bubble_outline,
                    label: '채팅 상태',
                    value: table.isChatting ? '채팅 중' : '대기',
                    valueColor: table.isChatting
                        ? AppColors.tableChatting
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.access_time,
                    label: '업데이트',
                    value: table.updatedAt != null
                        ? _formatTime(table.updatedAt!)
                        : '방금 전',
                  ),
                ],
              ),
            ),
          ),

          // 하단 버튼
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PrimaryButton(
                  onPressed: isInteractive ? onChatRequest : null,
                  size: ButtonSize.normal,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 16),
                      SizedBox(width: 6),
                      Text('채팅 요청'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return AppColors.tableAvailable;
      case TableStatus.occupied:
        return AppColors.tableOccupied;
      case TableStatus.reserved:
        return AppColors.tableReserved;
      case TableStatus.chatting:
        return AppColors.tableChatting;
    }
  }

  String _getStatusText(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return '빈테이블';
      case TableStatus.occupied:
        return '이용중';
      case TableStatus.reserved:
        return '예약';
      case TableStatus.chatting:
        return '채팅중';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

/// 정보 카드
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: AppColors.foregroundMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.foregroundSubtle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
