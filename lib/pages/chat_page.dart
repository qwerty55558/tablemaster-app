import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/chat_model.dart';
import '../models/table_model.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';

/// 채팅 페이지 - 좌측 사이드바(내 테이블 + 채팅방 탭) + 우측 채팅 뷰
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
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
          child: Row(
            children: [
              // 좌측 사이드바
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

              // 우측 채팅 뷰
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
                        onLeave: () => _confirmLeave(activeRoom.roomId),
                      )
                    : _buildEmptyState(),
              ),
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
                          lastMessage.content,
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
}

/// 우측 채팅 콘텐츠
class _ChatContent extends StatefulWidget {
  final ChatRoom chatRoom;
  final String? myDeviceId;
  final void Function(String content) onSend;
  final VoidCallback onLeave;

  const _ChatContent({
    required this.chatRoom,
    required this.myDeviceId,
    required this.onSend,
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
                OutlineButton(
                  onPressed: widget.onLeave,
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
                      final isMine = msg.senderDeviceId == widget.myDeviceId;
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
