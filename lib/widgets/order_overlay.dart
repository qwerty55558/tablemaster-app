import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart'
    hide AlertDialog, CircularProgressIndicator, MenuItem, showDialog;

import '../models/bill_model.dart';
import '../providers/providers.dart';
import '../theme/app_colors.dart';

class OrderOverlay extends ConsumerWidget {
  const OrderOverlay({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderPanelProvider);

    return Stack(
      children: [
        if (state.isOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => ref.read(orderPanelProvider.notifier).close(),
              child: Container(
                color: AppColors.overlayDark,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: _OrderPanel(
                onClose: () => ref.read(orderPanelProvider.notifier).close(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderPanel extends ConsumerWidget {
  final VoidCallback onClose;

  const _OrderPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderPanelProvider);
    final notifier = ref.read(orderPanelProvider.notifier);
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width > 520 ? 440.0 : width;

    return Material(
      color: AppColors.backgroundSecondary,
      child: SizedBox(
        width: panelWidth,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '주문 / 사용내역',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  GhostButton(
                    density: ButtonDensity.icon,
                    onPressed: onClose,
                    child: const Icon(Icons.close, color: AppColors.foregroundMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: '주문하기',
                      isActive: state.activeTab == OrderPanelTab.order,
                      onTap: () => notifier.setTab(OrderPanelTab.order),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabButton(
                      label: '사용내역',
                      isActive: state.activeTab == OrderPanelTab.bill,
                      onTap: () => notifier.setTab(OrderPanelTab.bill),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.activeTab == OrderPanelTab.order
                      ? const _OrderTab()
                      : const _BillTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.tableChatting.withValues(alpha: 0.16)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.tableChatting : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.tableChatting : AppColors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}

class _OrderTab extends ConsumerWidget {
  const _OrderTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderPanelProvider);
    final notifier = ref.read(orderPanelProvider.notifier);

    final totalPrice = state.selectedQuantities.entries.fold<int>(0, (sum, entry) {
      final item = state.menuItems.where((menu) => menu.id == entry.key).firstOrNull;
      if (item == null) return sum;
      return sum + item.price * entry.value;
    });
    final cartItems = state.selectedQuantities.entries
        .map((entry) => (
              item: state.menuItems.where((menu) => menu.id == entry.key).firstOrNull,
              quantity: entry.value,
            ))
        .where((entry) => entry.item != null)
        .toList();
    final groupedMenuItems = _groupMenuItems(state.menuItems);

    return Column(
      children: [
        Expanded(
          child: state.menuItems.isEmpty
              ? const Center(
                  child: Text(
                    '판매 가능한 메뉴가 없습니다',
                    style: TextStyle(color: AppColors.foregroundMuted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    const Text(
                      '메뉴 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...groupedMenuItems.entries.expand((entry) sync* {
                      yield _MenuCategoryHeader(title: _menuCategoryLabel(entry.key));
                      yield const SizedBox(height: 10);
                      for (final item in entry.value) {
                        final quantity = state.selectedQuantities[item.id] ?? 0;
                        yield _MenuItemCard(
                          item: item,
                          quantity: quantity,
                          onChanged: (next) => notifier.setQuantity(item.id, next),
                        );
                      }
                      yield const SizedBox(height: 6);
                    }),
                    const SizedBox(height: 8),
                    _CartSection(
                      cartItems: cartItems,
                      onChanged: (menuItemId, quantity) =>
                          notifier.setQuantity(menuItemId, quantity),
                    ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '선택 ${state.selectedCount}개',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.foregroundMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatAmount(totalPrice),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  onPressed: state.selectedQuantities.isEmpty || state.isSubmitting
                      ? null
                      : () => _showOrderConfirmDialog(
                            context,
                            ref,
                            cartItems,
                            totalPrice,
                          ),
                  child: Text(state.isSubmitting ? '주문 중...' : '주문 추가'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showOrderConfirmDialog(
  BuildContext context,
  WidgetRef ref,
  List<({MenuItem? item, int quantity})> cartItems,
  int totalPrice,
) async {
  if (cartItems.isEmpty) return;

  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('장바구니 확인'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '아래 항목으로 주문을 진행합니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cartItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = cartItems[index];
                  final item = entry.item!;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatAmount(item.price)} x ${entry.quantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatAmount(item.price * entry.quantity),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '총 주문 금액',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.foregroundMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatAmount(totalPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ],
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
            final success = await ref.read(orderPanelProvider.notifier).submitOrder();
            if (!context.mounted) return;
            showToast(
              context: context,
              builder: (context, overlay) => SurfaceCard(
                child: Basic(
                  title: Text(success ? '주문 완료' : '주문 실패'),
                  subtitle: Text(
                    success
                        ? '주문이 사용내역에 반영되었습니다'
                        : '주문 요청을 처리하지 못했습니다',
                  ),
                  leading: Icon(
                    success ? Icons.check_circle : Icons.error_outline,
                    color: success ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            );
          },
          child: const Text('최종 주문'),
        ),
      ],
    ),
  );
}

class _CartSection extends StatelessWidget {
  final List<({MenuItem? item, int quantity})> cartItems;
  final void Function(int menuItemId, int quantity) onChanged;

  const _CartSection({
    required this.cartItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '장바구니',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          if (cartItems.isEmpty)
            const Text(
              '선택한 메뉴가 없습니다',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.foregroundMuted,
              ),
            )
          else
            ...cartItems.map((entry) {
              final item = entry.item!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatAmount(item.price * entry.quantity),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GhostButton(
                      density: ButtonDensity.icon,
                      onPressed: () => onChanged(item.id, entry.quantity - 1),
                      child: const Icon(Icons.remove, size: 16),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${entry.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    GhostButton(
                      density: ButtonDensity.icon,
                      onPressed: () => onChanged(item.id, entry.quantity + 1),
                      child: const Icon(Icons.add, size: 16),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final ValueChanged<int> onChanged;

  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogImage(
            imageUrl: item.resolvedImageUrl,
            icon: Icons.restaurant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '선택한 수량만 주문에 반영됩니다',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.foregroundSubtle,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GhostButton(
                    density: ButtonDensity.icon,
                    onPressed: quantity > 0 ? () => onChanged(quantity - 1) : null,
                    child: const Icon(Icons.remove, size: 16),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  GhostButton(
                    density: ButtonDensity.icon,
                    onPressed: () => onChanged(quantity + 1),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatAmount(item.price),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foregroundMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuCategoryHeader extends StatelessWidget {
  final String title;

  const _MenuCategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.foregroundMuted,
      ),
    );
  }
}

class _CatalogImage extends StatelessWidget {
  final String? imageUrl;
  final IconData icon;

  const _CatalogImage({
    required this.imageUrl,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: AppColors.backgroundSecondary,
        child: imageUrl == null
            ? Icon(icon, size: 20, color: AppColors.foregroundMuted)
            : imageUrl!.endsWith('.svg')
                ? SvgPicture.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    placeholderBuilder: (_) =>
                        Icon(icon, size: 20, color: AppColors.foregroundMuted),
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(icon, size: 20, color: AppColors.foregroundMuted),
                  ),
      ),
    );
  }
}

Map<String, List<MenuItem>> _groupMenuItems(List<MenuItem> items) {
  final sorted = [...items]..sort((a, b) {
    final priorityCompare = _menuCategoryPriority(a.category)
        .compareTo(_menuCategoryPriority(b.category));
    if (priorityCompare != 0) return priorityCompare;
    return a.name.compareTo(b.name);
  });

  final grouped = <String, List<MenuItem>>{};
  for (final item in sorted) {
    grouped.putIfAbsent(item.category, () => []).add(item);
  }
  return grouped;
}

int _menuCategoryPriority(String category) {
  final normalized = category.toUpperCase();
  if (normalized.contains('FOOD') || normalized.contains('음식')) return 0;
  if (normalized.contains('ALCOHOL') ||
      normalized.contains('LIQUOR') ||
      normalized.contains('주류')) {
    return 1;
  }
  if (normalized.contains('DRINK') ||
      normalized.contains('BEVERAGE') ||
      normalized.contains('음료')) {
    return 2;
  }
  return 3;
}

String _menuCategoryLabel(String category) {
  final normalized = category.toUpperCase();
  if (normalized.contains('FOOD')) return '음식';
  if (normalized.contains('ALCOHOL') || normalized.contains('LIQUOR')) return '주류';
  if (normalized.contains('DRINK') || normalized.contains('BEVERAGE')) return '음료';
  return category;
}

class _BillTab extends ConsumerWidget {
  const _BillTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderPanelProvider);
    final bill = state.bill;

    if (bill == null) {
      return const Center(
        child: Text(
          '사용내역이 없습니다',
          style: TextStyle(color: AppColors.foregroundMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _BillSummaryCard(bill: bill),
        const SizedBox(height: 16),
        _BillSection<BillOrderItem>(
          title: '주문 항목',
          items: bill.orderItems,
          itemBuilder: (item) => _BillLine(
            title: item.name,
            subtitle: item.category,
            quantity: item.quantity,
            amount: item.subtotal,
          ),
        ),
        const SizedBox(height: 16),
        _BillSection<BillGiftOrderItem>(
          title: '선물 항목',
          items: bill.giftOrders,
          itemBuilder: (item) => _BillLine(
            title: item.displayName,
            subtitle: item.code,
            quantity: item.quantity,
            amount: item.subtotal,
          ),
        ),
      ],
    );
  }
}

class _BillSummaryCard extends StatelessWidget {
  final Bill bill;

  const _BillSummaryCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${bill.tableName} 사용내역',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tableChatting.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  bill.status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tableChatting,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatAmount(bill.totalAmount),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bill.updatedAt != null
                ? '최근 반영 ${_formatDateTime(bill.updatedAt!)}'
                : '최근 반영 시각 없음',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillSection<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(T item) itemBuilder;

  const _BillSection({
    required this.title,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              '항목이 없습니다',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.foregroundMuted,
              ),
            )
          else
            ...items.map(itemBuilder),
        ],
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final int quantity;
  final int amount;

  const _BillLine({
    required this.title,
    required this.subtitle,
    required this.quantity,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.foregroundSubtle,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$quantity개',
            style: const TextStyle(fontSize: 12, color: AppColors.foregroundMuted),
          ),
          const SizedBox(width: 12),
          Text(
            _formatAmount(amount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ],
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

String _formatDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
