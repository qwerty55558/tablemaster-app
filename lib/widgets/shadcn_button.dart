import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// shadcn 스타일 버튼 위젯
class ShadcnButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isPrimary;

  const ShadcnButton({
    super.key,
    required this.text,
    this.onTap,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(6),
          border: isPrimary ? null : Border.all(color: AppColors.border),
          boxShadow: isPrimary
              ? const [
                  BoxShadow(
                    offset: Offset(0, 4),
                    blurRadius: 12,
                    color: AppColors.shadowLight,
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isPrimary
                ? AppColors.primaryForeground
                : AppColors.foreground,
          ),
        ),
      ),
    );
  }
}
