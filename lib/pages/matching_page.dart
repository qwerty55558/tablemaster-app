import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/chat_model.dart';
import '../models/notification_model.dart';
import '../models/table_model.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import 'chat_page.dart';

/// 매칭 페이지 - 사이드바 + 메인 콘텐츠 레이아웃
class MatchingPage extends ConsumerStatefulWidget {
  const MatchingPage({super.key});

  @override
  ConsumerState<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends ConsumerState<MatchingPage> {

  /// 테이블 삭제 이벤트 처리 - 메인으로 리다이렉트
  void _handleTableDeleted(String tableId) {
    // 1. Repository 상태 초기화
    ref.read(tableRepositoryProvider).clearCurrentTable();

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
    ref.read(selectedTableIdProvider.notifier).state = table.id;
  }

  void _showChatRequestDialog(ChatEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅 요청'),
        content: Text('${event.fromTableName ?? "알 수 없는 테이블"}에서 채팅을 요청했습니다.\n수락하시겠습니까?'),
        actions: [
          OutlineButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(chatRepositoryProvider).rejectRequest(
                event.fromDeviceId ?? '',
              );
            },
            child: const Text('거절'),
          ),
          PrimaryButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(chatRepositoryProvider).acceptRequest(
                event.fromDeviceId ?? '',
              );
            },
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }

  void _requestChat(TableModel table) {
    final ws = WebSocketService();
    if (!ws.isConnected) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('요청 실패'),
            subtitle: const Text('서버에 연결되어 있지 않습니다'),
            leading: const Icon(Icons.error, color: AppColors.error),
          ),
        ),
      );
      return;
    }

    if (!table.isChatEnabled) {
      showToast(
        context: context,
        builder: (context, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('채팅 불가'),
            subtitle: Text('${table.name} 테이블은 채팅을 허용하지 않습니다'),
            leading: const Icon(Icons.block, color: AppColors.warning),
          ),
        ),
      );
      return;
    }

    ws.sendChatRequest(table.id);
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
  }

  @override
  Widget build(BuildContext context) {
    // currentTable이 null로 변경되면 (삭제 등) 메인으로 이동
    ref.listen<TableModel?>(currentTableProvider, (previous, next) {
      if (previous != null && next == null) {
        _handleTableDeleted(previous.id);
      }
    });

    // INACTIVE 상태 감지 → 재연결 델타 전송
    ref.listen<List<TableModel>>(tablesProvider, (previous, next) {
      final currentTable = ref.read(currentTableProvider);
      if (currentTable == null) return;

      final match = next.where((t) => t.id == currentTable.id).firstOrNull;
      if (match != null && match.status == TableStatus.inactive) {
        WebSocketService().sendReconnectDelta();
      }
    });

    // 채팅 요청 수신 → 다이얼로그 표시
    ref.listen<ChatEvent?>(pendingChatRequestProvider, (previous, next) {
      if (next != null && next.type == ChatEventType.chatRequest) {
        _showChatRequestDialog(next);
      }
    });

    // 채팅 토스트 이벤트 (거절, 실패, 에러)
    ref.listen<AsyncValue<ChatEvent>>(chatToastStreamProvider, (previous, next) {
      next.whenData((event) {
        String title;
        String subtitle;
        IconData icon;
        Color color;

        switch (event.type) {
          case ChatEventType.chatRejected:
            title = '채팅 거절';
            subtitle = '${event.fromTableName ?? "상대방"}이 채팅을 거절했습니다';
            icon = Icons.close;
            color = AppColors.warning;
            break;
          case ChatEventType.chatRequestFailed:
            title = '요청 실패';
            subtitle = event.reason ?? '채팅 요청에 실패했습니다';
            icon = Icons.error_outline;
            color = AppColors.error;
            break;
          case ChatEventType.chatError:
            title = '채팅 오류';
            subtitle = event.reason ?? '알 수 없는 오류가 발생했습니다';
            icon = Icons.error;
            color = AppColors.error;
            break;
          default:
            return;
        }

        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              title: Text(title),
              subtitle: Text(subtitle),
              leading: Icon(icon, color: color),
            ),
          ),
        );
      });
    });

    // 테이블 목록 (HTTP fallback + WebSocket 실시간)
    final tables = ref.watch(tablesProvider);
    final currentTable = ref.watch(currentTableProvider);
    final selectedTable = ref.watch(selectedTableProvider);
    final authStatus = ref.watch(currentAuthStatusProvider);
    final isConnected = authStatus == AuthStatus.authenticated;

    // 채팅 수락 시 ChatPage로 이동
    ref.listen<ChatRoom?>(activeChatRoomProvider, (previous, next) {
      if (previous == null && next != null) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ChatPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });

    final otherTables = tables.where((t) => t.id != currentTable?.id).toList();
    final isMyTableSelected = ref.watch(isMyTableSelectedProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final chatRooms = ref.watch(chatRoomsProvider);
    final chattingPartnerIds = chatRooms.values
        .map((r) => r.partnerDeviceId)
        .toSet();

    return Scaffold(
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  // 좌측 사이드바 - 테이블 목록
                  _TableSidebar(
                    currentTable: currentTable,
                    tables: otherTables,
                    selectedTable: selectedTable,
                    isMyTableSelected: isMyTableSelected,
                    unreadCount: unreadCount,
                    chatRoomCount: chatRooms.length,
                    chattingPartnerIds: chattingPartnerIds,
                    onTableTap: (table) {
                      ref.read(isMyTableSelectedProvider.notifier).state = false;
                      _onTableTap(table);
                    },
                    onMyTableTap: () {
                      ref.read(selectedTableIdProvider.notifier).state = null;
                      ref.read(isMyTableSelectedProvider.notifier).state = true;
                      ref.read(notificationsProvider.notifier).fetch();
                    },
                    onBack: () => Navigator.pop(context),
                    isConnected: isConnected,
                  ),

                  // 우측 메인 콘텐츠
                  Expanded(
                    child: isMyTableSelected && currentTable != null
                        ? _MyTableContent(
                            currentTable: currentTable,
                            onClose: () => ref
                                .read(isMyTableSelectedProvider.notifier)
                                .state = false,
                          )
                        : _MainContent(
                            selectedTable: selectedTable,
                            currentTable: currentTable,
                            onChatRequest: selectedTable != null
                                ? () => _requestChat(selectedTable)
                                : null,
                            onClose: () => ref
                                .read(selectedTableIdProvider.notifier)
                                .state = null,
                          ),
                  ),
                ],
              ),
              // 플로팅 채팅 아이콘
              if (chatRooms.isNotEmpty)
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: _ChatFloatingButton(
                    chatRoomCount: chatRooms.length,
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const ChatPage(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: Tween(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 플로팅 채팅 버튼
class _ChatFloatingButton extends StatelessWidget {
  final int chatRoomCount;
  final VoidCallback onTap;

  const _ChatFloatingButton({
    required this.chatRoomCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tableChatting,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.tableChatting.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (chatRoomCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Text(
                  '$chatRoomCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 좌측 사이드바 - 테이블 목록
class _TableSidebar extends StatelessWidget {
  final TableModel? currentTable;
  final List<TableModel> tables;
  final TableModel? selectedTable;
  final bool isMyTableSelected;
  final int unreadCount;
  final int chatRoomCount;
  final Set<String> chattingPartnerIds;
  final void Function(TableModel) onTableTap;
  final VoidCallback onMyTableTap;
  final VoidCallback onBack;
  final bool isConnected;

  const _TableSidebar({
    required this.currentTable,
    required this.tables,
    required this.selectedTable,
    required this.isMyTableSelected,
    required this.unreadCount,
    required this.chatRoomCount,
    required this.chattingPartnerIds,
    required this.onTableTap,
    required this.onMyTableTap,
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

          // 현재 테이블 정보 (탭 가능)
          if (currentTable != null)
            GestureDetector(
              onTap: onMyTableTap,
              child: _buildCurrentTable(currentTable!),
            ),

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.tableOccupied.withValues(alpha: isMyTableSelected ? 0.25 : 0.15),
            AppColors.tableOccupied.withValues(alpha: isMyTableSelected ? 0.12 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.tableOccupied.withValues(alpha: isMyTableSelected ? 0.6 : 0.3),
          width: isMyTableSelected ? 1.5 : 1,
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
                Row(
                  children: [
                    const Text(
                      '내 테이블',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.foregroundMuted,
                      ),
                    ),
                    if (chatRoomCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.tableChatting,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble, size: 8, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              '채팅 중',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
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
          Icon(
            Icons.chevron_right,
            size: 18,
            color: isMyTableSelected
                ? AppColors.tableOccupied
                : AppColors.foregroundSubtle,
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
          isChattingWithMe: chattingPartnerIds.contains(table.id),
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
  final bool isChattingWithMe;
  final VoidCallback onTap;

  const _TableListItem({
    required this.table,
    required this.isSelected,
    required this.isChattingWithMe,
    required this.onTap,
  });

  Color get _statusColor {
    switch (table.status) {
      case TableStatus.available:
      case TableStatus.inactive:
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
                      if (isChattingWithMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.tableChatting.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble, size: 9, color: AppColors.tableChatting),
                              const SizedBox(width: 3),
                              Text(
                                '채팅 중',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.tableChatting,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (table.isChatting) ...[
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
      case TableStatus.inactive:
        return '연결 끊김';
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
                    value: _buildGuestText(table),
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
                    label: '이용 시간',
                    value: table.createdAt != null
                        ? _formatElapsed(table.createdAt!)
                        : '-',
                  ),
                ],
              ),
            ),
          ),

          // 하단 버튼
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: PrimaryButton(
                onPressed: isInteractive ? onChatRequest : null,
                size: ButtonSize.large,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '채팅 요청',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildGuestText(TableModel table) {
    if (table.guestCount == null) return '-';
    final buffer = StringBuffer('${table.guestCount}명');
    if (table.femaleCount != null && table.maleCount != null) {
      buffer.write(' (여 ${table.femaleCount} / 남 ${table.maleCount})');
    }
    return buffer.toString();
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
      case TableStatus.inactive:
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
      case TableStatus.inactive:
        return '연결 끊김';
    }
  }

  String _formatElapsed(DateTime since) {
    final diff = DateTime.now().difference(since);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0) return '$hours시간 $minutes분';
    if (minutes > 0) return '$minutes분';
    return '방금 전';
  }
}

/// 내 테이블 상세 콘텐츠
class _MyTableContent extends ConsumerWidget {
  final TableModel currentTable;
  final VoidCallback onClose;

  const _MyTableContent({
    required this.currentTable,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final statusColor = AppColors.tableOccupied;

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
                      currentTable.name,
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
                        '${currentTable.name} 테이블',
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
                              '내 테이블',
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
                  // 테이블 정보 섹션
                  const Text(
                    '테이블 정보',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _InfoCard(
                    icon: Icons.people_outline,
                    label: '인원',
                    value: _buildGuestText(),
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.location_on_outlined,
                    label: '지역',
                    value: currentTable.location ?? '-',
                  ),
                  const SizedBox(height: 12),
                  _ChatToggleCard(
                    currentTable: currentTable,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.access_time,
                    label: '이용 시간',
                    value: currentTable.createdAt != null
                        ? _formatElapsed(currentTable.createdAt!)
                        : '-',
                  ),

                  const SizedBox(height: 32),

                  // 알림 섹션
                  Row(
                    children: [
                      const Text(
                        '알림',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (notifications.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${notifications.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foregroundMuted,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (notifications.any((n) => !n.isRead))
                        GhostButton(
                          size: ButtonSize.small,
                          onPressed: () {
                            ref.read(notificationsProvider.notifier).markAllRead();
                            ref.read(unreadCountProvider.notifier).clear();
                          },
                          child: const Text(
                            '모두 읽음',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.foregroundMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (notifications.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          '알림이 없습니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.foregroundMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    ...notifications.map((n) => _NotificationItem(
                          notification: n,
                          onTap: () {
                            if (!n.isRead) {
                              ref.read(notificationsProvider.notifier).markRead(n.id);
                              ref.read(unreadCountProvider.notifier).refresh();
                            }
                          },
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildGuestText() {
    if (currentTable.guestCount == null) return '-';
    final buffer = StringBuffer('${currentTable.guestCount}명');
    if (currentTable.femaleCount != null && currentTable.maleCount != null) {
      buffer.write(' (여 ${currentTable.femaleCount} / 남 ${currentTable.maleCount})');
    }
    return buffer.toString();
  }

  String _formatElapsed(DateTime since) {
    final diff = DateTime.now().difference(since);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0) return '$hours시간 $minutes분';
    if (minutes > 0) return '$minutes분';
    return '방금 전';
  }
}

/// 알림 아이템
class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppColors.backgroundSecondary
              : AppColors.tableChatting.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead
                ? AppColors.border
                : AppColors.tableChatting.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _categoryIcon,
                size: 18,
                color: _categoryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.tableChatting,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.foregroundMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.foregroundSubtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _categoryColor {
    switch (notification.category) {
      case 'ORDER':
        return AppColors.warning;
      case 'CHAT':
        return AppColors.tableChatting;
      default:
        return AppColors.foregroundMuted;
    }
  }

  IconData get _categoryIcon {
    switch (notification.category) {
      case 'ORDER':
        return Icons.receipt_long;
      case 'CHAT':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

/// 채팅 온오프 토글 카드
class _ChatToggleCard extends ConsumerWidget {
  final TableModel currentTable;

  const _ChatToggleCard({required this.currentTable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChatting = currentTable.isChatting;
    final isChatEnabled = currentTable.isChatEnabled;

    String statusText;
    Color statusColor;
    if (isChatting) {
      statusText = '채팅 중';
      statusColor = AppColors.tableChatting;
    } else if (isChatEnabled) {
      statusText = '채팅 가능';
      statusColor = AppColors.success;
    } else {
      statusText = '대기';
      statusColor = AppColors.foregroundMuted;
    }

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
            child: const Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.foregroundMuted),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '채팅',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.foregroundSubtle,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isChatEnabled,
            onChanged: isChatting
                ? null
                : (value) async {
                    final apiService = ref.read(apiServiceProvider);
                    await apiService.updateTable(
                      currentTable.id,
                      {'isChatEnabled': value},
                    );
                  },
          ),
        ],
      ),
    );
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
