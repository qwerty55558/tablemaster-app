import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../theme/app_colors.dart';
import '../providers/providers.dart';
import 'matching_page.dart';

/// 테이블 설정 페이지 - 스텝업 방식
class SetupPage extends ConsumerWidget {
  const SetupPage({super.key});

  static const List<String> _locations = ['서울', '부산', '인천', '대구', '광주', '대전', '울산', '경기'];
  static const int _minGuests = 2;
  static const int _maxGuests = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(setupFormProvider);
    final formNotifier = ref.read(setupFormProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(formState.currentStep),

            // 프로그레스 인디케이터
            _buildProgressIndicator(formState.currentStep),

            // 메인 콘텐츠
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepContent(context, ref, formState, formNotifier),
              ),
            ),

            // 하단 버튼
            _buildBottomButtons(context, ref, formState, formNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int currentStep) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          _getStepTitle(currentStep),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return '테이블 이름';
      case 1:
        return '지역 선택';
      case 2:
        return '인원 선택';
      case 3:
        return '성비 선택';
      default:
        return '';
    }
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (index) {
          // 짝수 인덱스 = 원 (0, 2, 4, 6 → step 1, 2, 3, 4)
          // 홀수 인덱스 = 선 (1, 3, 5)
          if (index.isEven) {
            final stepIndex = index ~/ 2;
            final isActive = stepIndex <= currentStep;
            final isCompleted = stepIndex < currentStep;
            return Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.primary : AppColors.border,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check, size: 18, color: AppColors.primaryForeground)
                  : Text(
                      '${stepIndex + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? AppColors.primaryForeground
                            : AppColors.foregroundMuted,
                      ),
                    ),
            );
          } else {
            final lineIndex = index ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: lineIndex < currentStep
                    ? AppColors.primary
                    : AppColors.border,
              ),
            );
          }
        }),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    WidgetRef ref,
    SetupFormState formState,
    SetupFormNotifier formNotifier,
  ) {
    switch (formState.currentStep) {
      case 0:
        return _TableNameStep(
          tableName: formState.tableName,
          onChanged: formNotifier.setTableName,
        );
      case 1:
        return _LocationStep(
          locations: _locations,
          selectedLocation: formState.selectedLocation,
          onSelected: formNotifier.setLocation,
        );
      case 2:
        return _GuestCountStep(
          guestCount: formState.guestCount,
          minGuests: _minGuests,
          maxGuests: _maxGuests,
          onChanged: formNotifier.setGuestCount,
        );
      case 3:
        return _GenderRatioStep(
          guestCount: formState.guestCount,
          femaleCount: formState.femaleCount,
          maleCount: formState.maleCount,
          onIncrementFemale: formNotifier.incrementFemale,
          onDecrementFemale: formNotifier.decrementFemale,
          onIncrementMale: formNotifier.incrementMale,
          onDecrementMale: formNotifier.decrementMale,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomButtons(
    BuildContext context,
    WidgetRef ref,
    SetupFormState formState,
    SetupFormNotifier formNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GhostButton(
              onPressed: formState.currentStep == 0
                  ? () => Navigator.pop(context)
                  : formNotifier.previousStep,
              child: Text(formState.currentStep == 0 ? '메인으로 가기' : '이전'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              onPressed: formState.canProceed() && !formState.isLoading
                  ? () => _handleNext(context, ref, formState, formNotifier)
                  : null,
              child: formState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryForeground,
                      ),
                    )
                  : Text(formState.currentStep < 3 ? '다음' : '완료'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNext(
    BuildContext context,
    WidgetRef ref,
    SetupFormState formState,
    SetupFormNotifier formNotifier,
  ) async {
    if (formState.currentStep < 3) {
      formNotifier.nextStep();
    } else {
      final success = await formNotifier.submit();
      if (success && context.mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MatchingPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else if (context.mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              title: const Text('설정 실패'),
              subtitle: const Text('다시 시도해주세요'),
              leading: const Icon(Icons.error_outline, color: AppColors.error),
            ),
          ),
        );
      }
    }
  }
}

/// Step 0: 테이블 이름 입력
class _TableNameStep extends StatefulWidget {
  final String tableName;
  final void Function(String) onChanged;

  const _TableNameStep({
    required this.tableName,
    required this.onChanged,
  });

  @override
  State<_TableNameStep> createState() => _TableNameStepState();
}

class _TableNameStepState extends State<_TableNameStep> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tableName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('tableName'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '테이블 이름을 입력해주세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '다른 테이블에서 보이는 이름입니다',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.foregroundMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _controller,
                placeholder: const Text('예: 우리팀, 친구들, A1'),
                onChanged: widget.onChanged,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 1: 지역 선택
class _LocationStep extends StatelessWidget {
  final List<String> locations;
  final String? selectedLocation;
  final void Function(String) onSelected;

  const _LocationStep({
    required this.locations,
    required this.selectedLocation,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('location'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '어디에서 오셨나요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '지역을 선택해주세요',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.foregroundMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: locations.map((location) {
                final isSelected = selectedLocation == location;
                return GestureDetector(
                  onTap: () => onSelected(location),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryForeground
                            : AppColors.foreground,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2: 인원 선택
class _GuestCountStep extends StatelessWidget {
  final int guestCount;
  final int minGuests;
  final int maxGuests;
  final void Function(int) onChanged;

  const _GuestCountStep({
    required this.guestCount,
    required this.minGuests,
    required this.maxGuests,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('guestCount'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '몇 분이세요?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '총 인원 수를 선택해주세요',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.foregroundMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CounterButton(
                  icon: Icons.remove,
                  onPressed: guestCount > minGuests
                      ? () => onChanged(guestCount - 1)
                      : null,
                ),
                const SizedBox(width: 32),
                Text(
                  '$guestCount',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(width: 32),
                _CounterButton(
                  icon: Icons.add,
                  onPressed: guestCount < maxGuests
                      ? () => onChanged(guestCount + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '명',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 3: 성비 선택
class _GenderRatioStep extends StatelessWidget {
  final int guestCount;
  final int femaleCount;
  final int maleCount;
  final VoidCallback onIncrementFemale;
  final VoidCallback onDecrementFemale;
  final VoidCallback onIncrementMale;
  final VoidCallback onDecrementMale;

  const _GenderRatioStep({
    required this.guestCount,
    required this.femaleCount,
    required this.maleCount,
    required this.onIncrementFemale,
    required this.onDecrementFemale,
    required this.onIncrementMale,
    required this.onDecrementMale,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('genderRatio'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '성비를 알려주세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '총 $guestCount명의 성비를 조절해주세요',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.foregroundMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                // 여성
                Expanded(
                  child: _GenderCard(
                    label: '여성',
                    count: femaleCount,
                    color: const Color(0xFFEC4899),
                    onIncrement: onIncrementFemale,
                    onDecrement: onDecrementFemale,
                    canIncrement: maleCount > 0,
                    canDecrement: femaleCount > 0,
                  ),
                ),
                const SizedBox(width: 16),
                // 남성
                Expanded(
                  child: _GenderCard(
                    label: '남성',
                    count: maleCount,
                    color: const Color(0xFF3B82F6),
                    onIncrement: onIncrementMale,
                    onDecrement: onDecrementMale,
                    canIncrement: femaleCount > 0,
                    canDecrement: maleCount > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CounterButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled ? AppColors.border : AppColors.backgroundCard,
          border: Border.all(
            color: isDisabled ? AppColors.border : AppColors.borderLight,
          ),
        ),
        child: Icon(
          icon,
          size: 28,
          color: isDisabled ? AppColors.foregroundSubtle : AppColors.foreground,
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool canIncrement;
  final bool canDecrement;

  const _GenderCard({
    required this.label,
    required this.count,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
    required this.canIncrement,
    required this.canDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CounterButton(
                icon: Icons.remove,
                onPressed: canDecrement ? onDecrement : null,
              ),
              const SizedBox(width: 16),
              _CounterButton(
                icon: Icons.add,
                onPressed: canIncrement ? onIncrement : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
