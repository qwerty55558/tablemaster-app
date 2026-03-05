import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/table_model.dart';
import '../theme/app_colors.dart';

/// 테이블 카드 위젯
class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback? onTap;

  const TableCard({super.key, required this.table, this.onTap});

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
      case TableStatus.inactive:
        return AppColors.tableAvailable;
    }
  }

  Color get _backgroundColor {
    switch (table.status) {
      case TableStatus.available:
        return AppColors.tableAvailableBg;
      case TableStatus.occupied:
        return AppColors.tableOccupiedBg;
      case TableStatus.reserved:
        return AppColors.tableReservedBg;
      case TableStatus.chatting:
        return AppColors.tableChattingBg;
      case TableStatus.inactive:
        return AppColors.tableAvailableBg;
    }
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

  @override
  Widget build(BuildContext context) {
    final isInteractive = table.status != TableStatus.available;

    return GestureDetector(
      onTap: isInteractive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_backgroundColor, _statusColor.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: isInteractive
              ? [
                  BoxShadow(
                    color: _statusColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 테이블 아이콘/이름
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  table.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 상태 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: _statusColor),
                  const SizedBox(width: 6),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),

            // 추가 정보 (이용중인 경우만)
            if (table.status == TableStatus.occupied ||
                table.status == TableStatus.chatting) ...[
              const SizedBox(height: 12),

              // 인원수 + 채팅 아이콘
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (table.guestCount != null) ...[
                    Icon(Icons.people_outline, size: 14, color: _statusColor),
                    const SizedBox(width: 4),
                    Text(
                      '${table.guestCount}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ],
                  if (table.isChatting) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.tableChatting.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        size: 12,
                        color: AppColors.tableChatting,
                      ),
                    ),
                  ],
                ],
              ),

              // 지역
              if (table.location != null) ...[
                const SizedBox(height: 6),
                Text(
                  table.location!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.foregroundMuted,
                  ),
                ),
              ],
            ],

            // 빈 테이블 표시
            if (table.status == TableStatus.available) ...[
              const SizedBox(height: 12),
              const Text(
                '---',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.foregroundSubtle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
