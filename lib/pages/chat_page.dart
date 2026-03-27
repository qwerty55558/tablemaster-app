import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/chat_model.dart';
import '../models/bill_model.dart';
import '../models/table_model.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';
import '../widgets/order_overlay.dart';

/// 채팅 페이지 - 좌측 사이드바(내 테이블 + 채팅방 탭) + 우측 채팅 뷰
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const List<String> _reportReasons = [
    '욕설/비하',
    '성희롱/불쾌한 발언',
    '도배/스팸',
    '사칭/허위 정보',
    '기타',
  ];

  void _confirmLeave(int roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('채팅방을 나가시겠습니까?\n대화 내용이 삭제됩니다.'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          DestructiveButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(chatRepositoryProvider).leaveChat(roomId);
            },
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportDialog(ChatRoom room) async {
    final customReasonController = TextEditingController();
    String? selectedReason;
    bool isSubmitting = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final customReason = customReasonController.text.trim();
            final effectiveReason = selectedReason == '기타'
                ? customReason
                : (selectedReason ?? customReason);
            final canSubmit =
                !isSubmitting && effectiveReason.trim().isNotEmpty;

            Future<void> submit() async {
              if (!canSubmit) return;

              setDialogState(() => isSubmitting = true);
              final success = await ref.read(apiServiceProvider).reportChatRoom(
                    roomId: room.roomId,
                    reportedDeviceId: room.partnerDeviceId,
                    reason: effectiveReason.trim(),
                  );

              if (!dialogContext.mounted) return;
              if (!mounted) return;
              Navigator.of(dialogContext).pop();

              showToast(
                context: this.context,
                builder: (context, overlay) => SurfaceCard(
                  child: Basic(
                    title: Text(success ? '신고 완료' : '신고 실패'),
                    subtitle: Text(
                      success
                          ? '${room.partnerTableName} 테이블을 신고했습니다'
                          : '신고 요청을 처리하지 못했습니다',
                    ),
                    leading: Icon(
                      success ? Icons.flag : Icons.error_outline,
                      color: success ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              title: const Text('신고하기'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${room.partnerTableName} 테이블 신고 사유를 선택하세요.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.foregroundMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reportReasons.map((reason) {
                        final isSelected = selectedReason == reason;
                        return GestureDetector(
                          onTap: isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedReason = reason;
                                    if (reason != '기타') {
                                      customReasonController.text = '';
                                    }
                                  });
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.error.withValues(alpha: 0.14)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.error
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected
                                    ? AppColors.error
                                    : AppColors.foreground,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: customReasonController,
                      enabled: !isSubmitting,
                      placeholder: Text(
                        selectedReason == '기타'
                            ? '신고 사유를 직접 입력하세요'
                            : '필요하면 추가 설명을 입력하세요',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlineButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                DestructiveButton(
                  onPressed: canSubmit ? submit : null,
                  child: Text(isSubmitting ? '신고 중...' : '신고'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      customReasonController.dispose();
    }
  }

  Future<void> _showGiftDialog(ChatRoom room) async {
    await ref.read(catalogResourcesProvider.notifier).load();
    if (!mounted) return;

    final gifts = ref.read(catalogResourcesProvider).giftItems;
    if (!mounted) return;

    if (gifts.isEmpty) {
      showToast(
        context: context,
        builder: (context, overlay) => const SurfaceCard(
          child: Basic(
            title: Text('선물 없음'),
            subtitle: Text('판매 가능한 선물이 없습니다'),
            leading: Icon(Icons.card_giftcard, color: AppColors.warning),
          ),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('선물하기'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: gifts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final gift = gifts[index];
              return _GiftSelectionTile(
                gift: gift,
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _showGiftConfirmDialog(room, gift);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showGiftConfirmDialog(ChatRoom room, GiftItem gift) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('선물 보내기'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${room.partnerTableName} 테이블에 아래 선물을 보냅니다.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.foregroundMuted,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tableChatting.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        size: 20,
                        color: AppColors.tableChatting,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gift.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gift.code,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatAmount(gift.price),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          PrimaryButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              ref.read(webSocketServiceProvider).sendChatGift(
                    room.roomId,
                    gift.code,
                  );
              final currentTable = ref.read(currentTableProvider);
              if (currentTable != null) {
                await ref
                    .read(orderPanelProvider.notifier)
                    .refreshBillFor(currentTable.id);
              }
              if (!mounted) return;
              showToast(
                context: context,
                builder: (context, overlay) => SurfaceCard(
                  child: Basic(
                    title: const Text('선물 전송'),
                    subtitle: Text('${gift.displayName}을 보냈습니다'),
                    leading: const Icon(
                      Icons.card_giftcard,
                      color: AppColors.tableChatting,
                    ),
                  ),
                ),
              );
            },
            child: const Text('보내기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTable = ref.watch(currentTableProvider);
    final chatRooms = ref.watch(chatRoomsProvider);
    final activeRoom = ref.watch(activeChatRoomProvider);

    // 모든 채팅방이 없어지면 자동으로 뒤로가기
    ref.listen<Map<int, ChatRoom>>(chatRoomsProvider, (previous, next) {
      if (next.isEmpty && (previous?.isNotEmpty ?? false)) {
        if (mounted) Navigator.pop(context);
      }
    });

    return Scaffold(
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  _ChatSidebar(
                    currentTable: currentTable,
                    chatRooms: chatRooms,
                    activeRoomId: activeRoom?.roomId,
                    onSwitchRoom: (roomId) {
                      ref.read(chatRepositoryProvider).setActiveRoom(roomId);
                    },
                    onLeaveRoom: (roomId) => _confirmLeave(roomId),
                    onBack: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: activeRoom != null
                        ? _ChatContent(
                            chatRoom: activeRoom,
                            myDeviceId: currentTable?.id,
                            onSend: (content) {
                              ref.read(chatRepositoryProvider).sendMessage(
                                activeRoom.roomId,
                                content,
                              );
                            },
                            onGift: () => _showGiftDialog(activeRoom),
                            onReport: () => _showReportDialog(activeRoom),
                            onLeave: () => _confirmLeave(activeRoom.roomId),
                          )
                        : _buildEmptyState(),
                  ),
                ],
              ),
              const OrderOverlay(),
            ],
          ),
        ),
      ),
    );
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
                Icons.chat_bubble_outline,
                size: 36,
                color: AppColors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '채팅방을 선택하세요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '좌측 목록에서 채팅방을 선택하면\n대화를 이어갈 수 있습니다',
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
}

/// 좌측 사이드바 - 내 테이블 정보 + 채팅방 목록
class _ChatSidebar extends StatelessWidget {
  final TableModel? currentTable;
  final Map<int, ChatRoom> chatRooms;
  final int? activeRoomId;
  final void Function(int roomId) onSwitchRoom;
  final void Function(int roomId) onLeaveRoom;
  final VoidCallback onBack;

  const _ChatSidebar({
    required this.currentTable,
    required this.chatRooms,
    required this.activeRoomId,
    required this.onSwitchRoom,
    required this.onLeaveRoom,
    required this.onBack,
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

          // 내 테이블 정보
          if (currentTable != null) _buildMyTableInfo(currentTable!),

          const Divider(color: AppColors.border, height: 1),

          // 채팅방 목록 타이틀
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '채팅방',
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
                    '${chatRooms.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 채팅방 목록
          Expanded(child: _buildRoomList()),
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
              '채팅',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTableInfo(TableModel table) {
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

  Widget _buildRoomList() {
    if (chatRooms.isEmpty) {
      return const Center(
        child: Text(
          '활성 채팅방이 없습니다',
          style: TextStyle(fontSize: 14, color: AppColors.foregroundMuted),
        ),
      );
    }

    final rooms = chatRooms.values.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final isActive = room.roomId == activeRoomId;
        final lastMessage = room.messages.isNotEmpty ? room.messages.last : null;

        return GestureDetector(
          onTap: () => onSwitchRoom(room.roomId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.tableChatting.withValues(alpha: 0.15)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? AppColors.tableChatting.withValues(alpha: 0.5)
                    : AppColors.border,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: room.isSanctioned
                            ? (room.isBanned
                                ? AppColors.error.withValues(alpha: 0.15)
                                : AppColors.warning.withValues(alpha: 0.15))
                            : AppColors.tableChatting.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          room.partnerTableName.isNotEmpty
                              ? room.partnerTableName[0]
                              : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: room.isSanctioned
                                ? (room.isBanned
                                    ? AppColors.error
                                    : AppColors.warning)
                                : AppColors.tableChatting,
                          ),
                        ),
                      ),
                    ),
                    if (room.isSanctioned)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: room.isBanned
                                ? AppColors.error
                                : AppColors.warning,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.backgroundSecondary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            room.isBanned
                                ? Icons.block
                                : Icons.volume_off,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room.partnerTableName} 테이블',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: AppColors.foreground,
                        ),
                      ),
                      if (lastMessage != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _buildLastMessagePreview(lastMessage),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.foregroundMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!room.isBanned)
                  GhostButton(
                    density: ButtonDensity.icon,
                    size: ButtonSize.small,
                    onPressed: () => onLeaveRoom(room.roomId),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.foregroundSubtle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildLastMessagePreview(ChatMessage message) {
    switch (message.messageType) {
      case 'GIFT':
        return '선물: ${message.content}';
      case 'WARNING':
        return '관리자 경고';
      default:
        return message.content;
    }
  }
}

/// 우측 채팅 콘텐츠
class _ChatContent extends StatefulWidget {
  final ChatRoom chatRoom;
  final String? myDeviceId;
  final void Function(String content) onSend;
  final VoidCallback onGift;
  final VoidCallback onReport;
  final VoidCallback onLeave;

  const _ChatContent({
    required this.chatRoom,
    required this.myDeviceId,
    required this.onSend,
    required this.onGift,
    required this.onReport,
    required this.onLeave,
  });

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ChatContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatRoom.messages.length > oldWidget.chatRoom.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  Widget _buildSanctionBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chatRoom.messages;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // 상단 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.backgroundSecondary,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tableChatting.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    size: 20,
                    color: AppColors.tableChatting,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.chatRoom.partnerTableName} 테이블',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.chatRoom.isBanned
                            ? '이용 제한됨'
                            : widget.chatRoom.isMuted
                                ? '뮤트됨'
                                : '채팅 중',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.chatRoom.isBanned
                              ? AppColors.error
                              : widget.chatRoom.isMuted
                                  ? AppColors.warning
                                  : AppColors.tableChatting,
                        ),
                      ),
                    ],
                  ),
                ),
                GhostButton(
                  onPressed: widget.onReport,
                  size: ButtonSize.small,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 16),
                      SizedBox(width: 4),
                      Text('신고'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  onPressed: widget.chatRoom.isBanned ? null : widget.onLeave,
                  size: ButtonSize.small,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.exit_to_app, size: 16),
                      SizedBox(width: 4),
                      Text('나가기'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 메시지 리스트
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      '메시지가 없습니다.\n첫 메시지를 보내보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.foregroundMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      if (msg.messageType == 'WARNING') {
                        return _WarningNotice(message: msg);
                      }
                      final isMine = msg.senderDeviceId == widget.myDeviceId;
                      if (msg.messageType == 'GIFT') {
                        return _GiftNotice(message: msg, isMine: isMine);
                      }
                      return _ChatBubble(
                        message: msg,
                        isMine: isMine,
                      );
                    },
                  ),
          ),

          // 하단 입력창 / 제재 배너
          if (widget.chatRoom.isBanned)
            _buildSanctionBanner(
              icon: Icons.block,
              color: AppColors.error,
              text: '관리자에 의해 채팅이 제한되었습니다',
            )
          else if (widget.chatRoom.isMuted)
            _buildSanctionBanner(
              icon: Icons.volume_off,
              color: AppColors.warning,
              text: widget.chatRoom.mutedUntil != null
                  ? '뮤트 상태입니다 (해제: ${_formatTime(widget.chatRoom.mutedUntil!)})'
                  : '뮤트 상태입니다',
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: GhostButton(
                      onPressed: widget.onGift,
                      density: ButtonDensity.icon,
                      child: const Icon(Icons.card_giftcard, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      placeholder: const Text('메시지를 입력하세요...'),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: PrimaryButton(
                      onPressed: _handleSend,
                      density: ButtonDensity.icon,
                      child: const Icon(Icons.send, size: 20),
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

class _GiftSelectionTile extends StatelessWidget {
  final GiftItem gift;
  final VoidCallback onTap;

  const _GiftSelectionTile({
    required this.gift,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GiftImage(imageUrl: gift.resolvedImageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gift.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gift.code,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.foregroundSubtle,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatAmount(gift.price),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftImage extends StatelessWidget {
  final String? imageUrl;

  const _GiftImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: AppColors.backgroundSecondary,
        child: imageUrl == null
            ? const Icon(
                Icons.card_giftcard,
                color: AppColors.tableChatting,
              )
            : imageUrl!.endsWith('.svg')
                ? SvgPicture.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    placeholderBuilder: (_) => const Icon(
                      Icons.card_giftcard,
                      color: AppColors.tableChatting,
                    ),
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.card_giftcard,
                      color: AppColors.tableChatting,
                    ),
                  ),
      ),
    );
  }
}

String _formatAmount(int amount) {
  final reversed = amount.toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(reversed[i]);
  }
  return '${buffer.toString().split('').reversed.join()}원';
}

/// 관리자 경고 알림 (채팅 내 시스템 메시지)
class _WarningNotice extends StatelessWidget {
  final ChatMessage message;

  const _WarningNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.foregroundSubtle.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.foregroundMuted.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '관리자 경고',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foregroundMuted.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message.content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.foregroundMuted.withValues(alpha: 0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftNotice extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _GiftNotice({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final text = isMine
        ? '${message.content} 선물을 보냈습니다'
        : '${message.senderTableName} 테이블에게서 ${message.content} 선물을 받았습니다';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.tableChatting.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.tableChatting.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.tableChatting.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 16,
                  color: AppColors.tableChatting,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 채팅 말풍선
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.tableChatting.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  message.senderTableName.isNotEmpty
                      ? message.senderTableName[0]
                      : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.tableChatting,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.tableChatting
                    : AppColors.backgroundSecondary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isMine
                    ? null
                    : Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderTableName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tableChatting,
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMine ? Colors.white : AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
