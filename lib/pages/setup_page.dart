import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import 'matching_page.dart';

/// 테이블 설정 페이지 - 스텝업 방식
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 0: 테이블 이름
  final TextEditingController _tableNameController = TextEditingController();

  // Step 1: 지역
  String? _selectedLocation;
  final List<String> _locations = ['서울', '부산', '인천', '대구', '광주', '대전', '울산', '경기'];

  // Step 2: 인원
  int _guestCount = 4;
  static const int _minGuests = 2;
  static const int _maxGuests = 12;

  // Step 3: 성비
  late int _femaleCount;
  late int _maleCount;

  @override
  void initState() {
    super.initState();
    _initGenderRatio();
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    super.dispose();
  }

  void _initGenderRatio() {
    _femaleCount = _guestCount ~/ 2;
    _maleCount = _guestCount - _femaleCount;
  }

  void _updateGenderRatio() {
    // 총 인원이 변경되면 성비 재조정
    if (_femaleCount + _maleCount != _guestCount) {
      _femaleCount = _guestCount ~/ 2;
      _maleCount = _guestCount - _femaleCount;
    }
  }

  void _incrementFemale() {
    if (_femaleCount < _guestCount) {
      setState(() {
        _femaleCount++;
        _maleCount--;
      });
    }
  }

  void _decrementFemale() {
    if (_femaleCount > 0) {
      setState(() {
        _femaleCount--;
        _maleCount++;
      });
    }
  }

  void _incrementMale() {
    if (_maleCount < _guestCount) {
      setState(() {
        _maleCount++;
        _femaleCount--;
      });
    }
  }

  void _decrementMale() {
    if (_maleCount > 0) {
      setState(() {
        _maleCount--;
        _femaleCount++;
      });
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _tableNameController.text.trim().isNotEmpty;
      case 1:
        return _selectedLocation != null;
      case 2:
        return _guestCount >= _minGuests;
      case 3:
        return _femaleCount + _maleCount == _guestCount;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
        if (_currentStep == 3) {
          _updateGenderRatio();
        }
      });
    } else {
      _submitSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitSetup() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService().setupTable(
        name: _tableNameController.text.trim(),
        location: _selectedLocation!,
        guestCount: _guestCount,
        femaleCount: _femaleCount,
        maleCount: _maleCount,
      );

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => SurfaceCard(
            child: Basic(
              title: const Text('설정 실패'),
              subtitle: Text(e.toString()),
              leading: const Icon(Icons.error_outline, color: AppColors.error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(),

            // 프로그레스 인디케이터
            _buildProgressIndicator(),

            // 메인 콘텐츠
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStepContent(),
              ),
            ),

            // 하단 버튼
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          _getStepTitle(),
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

  String _getStepTitle() {
    switch (_currentStep) {
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

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppColors.primary : AppColors.border,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 18, color: AppColors.primaryForeground)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? AppColors.primaryForeground
                                  : AppColors.foregroundMuted,
                            ),
                          ),
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < _currentStep
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildTableNameStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildGuestCountStep();
      case 3:
        return _buildGenderRatioStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildTableNameStep() {
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
                controller: _tableNameController,
                placeholder: const Text('예: 우리팀, 친구들, A1'),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
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
              children: _locations.map((location) {
                final isSelected = _selectedLocation == location;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedLocation = location;
                    });
                  },
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

  Widget _buildGuestCountStep() {
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
                  onPressed: _guestCount > _minGuests
                      ? () {
                          setState(() {
                            _guestCount--;
                            _updateGenderRatio();
                          });
                        }
                      : null,
                ),
                const SizedBox(width: 32),
                Text(
                  '$_guestCount',
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(width: 32),
                _CounterButton(
                  icon: Icons.add,
                  onPressed: _guestCount < _maxGuests
                      ? () {
                          setState(() {
                            _guestCount++;
                            _updateGenderRatio();
                          });
                        }
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

  Widget _buildGenderRatioStep() {
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
              '총 $_guestCount명의 성비를 조절해주세요',
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
                    count: _femaleCount,
                    color: const Color(0xFFEC4899),
                    onIncrement: _incrementFemale,
                    onDecrement: _decrementFemale,
                    canIncrement: _maleCount > 0,
                    canDecrement: _femaleCount > 0,
                  ),
                ),
                const SizedBox(width: 16),
                // 남성
                Expanded(
                  child: _GenderCard(
                    label: '남성',
                    count: _maleCount,
                    color: const Color(0xFF3B82F6),
                    onIncrement: _incrementMale,
                    onDecrement: _decrementMale,
                    canIncrement: _femaleCount > 0,
                    canDecrement: _maleCount > 0,
                  ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBottomButtons() {
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
              onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _previousStep,
              child: Text(_currentStep == 0 ? '메인으로 가기' : '이전'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              onPressed: _canProceed() && !_isLoading ? _nextStep : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryForeground,
                      ),
                    )
                  : Text(_currentStep < 3 ? '다음' : '완료'),
            ),
          ),
        ],
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
