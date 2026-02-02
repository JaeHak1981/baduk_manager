import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/academy_model.dart';
import '../../models/student_model.dart';
import '../../providers/student_provider.dart';
import 'dart:math' as math;

class EnrollmentStatisticsDialog extends StatefulWidget {
  final AcademyModel academy;
  final int initialYear;
  final int initialMonth;

  const EnrollmentStatisticsDialog({
    super.key,
    required this.academy,
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<EnrollmentStatisticsDialog> createState() =>
      _EnrollmentStatisticsDialogState();
}

class _EnrollmentStatisticsDialogState
    extends State<EnrollmentStatisticsDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _isLoading = false;

  // 조회 기간 (개월)
  int _selectedPeriod = 12;

  // 12개월 통계 데이터 리스트
  List<_MonthlyStat> _monthlyStats = [];
  int _maxCount = 0;
  List<StudentModel> _allStudents = []; // 전체 학생 데이터 캐싱

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    // 빌드가 완료된 후 데이터 로드 시작하여 setState() 에러 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final studentProvider = context.read<StudentProvider>();

      // 모든 학생 로드
      await studentProvider.loadStudents(
        widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      _allStudents = studentProvider.students;

      // 초기 통계 계산
      _calculateMonthlyStatistics();
    } catch (e) {
      debugPrint('Error fetching enrollment stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateMonthlyStatistics() {
    List<_MonthlyStat> stats = [];
    int maxVal = 0;

    // 선택된 기간만큼 반복
    for (int i = _selectedPeriod - 1; i >= 0; i--) {
      DateTime monthDate = DateTime(_selectedYear, _selectedMonth - i, 1);
      final monthEnd = DateTime(
        monthDate.year,
        monthDate.month + 1,
        0,
        23,
        59,
        59,
      );

      // 해당 월 말 기준 누적 인원 (미배정 학생 제외)
      final activeCount = _allStudents.where((s) {
        final isAssigned = s.session != null && s.session != 0;
        final wasCreatedBefore =
            s.createdAt.isBefore(monthEnd) ||
            s.createdAt.isAtSameMomentAs(monthEnd);
        return isAssigned && wasCreatedBefore;
      }).length;

      stats.add(
        _MonthlyStat(
          year: monthDate.year,
          month: monthDate.month,
          total: activeCount,
        ),
      );

      if (activeCount > maxVal) maxVal = activeCount;
    }

    setState(() {
      _monthlyStats = stats;
      _maxCount = maxVal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStat = _monthlyStats.isNotEmpty ? _monthlyStats.last : null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.min(screenWidth * 0.9, 650.0);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('12개월 인원 변동 추이'),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                )
              else if (currentStat == null)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('데이터가 없습니다.'),
                )
              else ...[
                // 상단 요약 요약 정보
                _buildSimpleSummaryCard(
                  '총 인원',
                  '${currentStat.total}명',
                  Colors.blue.shade700,
                ),
                const SizedBox(height: 32),

                // 기간 선택 UI
                _buildPeriodSelector(),

                const SizedBox(height: 16),

                // 차트 영역
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '월별 인원 변동 추이',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '최근 $_selectedPeriod개월',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 가로 스크롤 가능하도록 수정
                Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: math.max(
                          dialogWidth - 32,
                          _selectedPeriod * 45.0 + 40,
                        ),
                      ),
                      height: 240, // 높여서 더 시원하게 보이도록 수정
                      padding: const EdgeInsets.only(bottom: 8, top: 12),
                      child: _buildChart(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // 범례
                _buildLegendItem('현재 부별 인원', Colors.blue.shade600),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '조회 기간 설정',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              _buildRoundButton(
                icon: Icons.remove,
                onPressed: _selectedPeriod > 3
                    ? () {
                        setState(() {
                          _selectedPeriod -= 1;
                          _calculateMonthlyStatistics();
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 60),
                alignment: Alignment.center,
                child: Text(
                  '$_selectedPeriod개월',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildRoundButton(
                icon: Icons.add,
                onPressed: _selectedPeriod < 36
                    ? () {
                        setState(() {
                          _selectedPeriod += 1;
                          _calculateMonthlyStatistics();
                        });
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.grey.shade100 : Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? Colors.grey.shade400
              : Colors.blue.shade700,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSimpleSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 16,
      ), // 가로 패딩 조정
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11, // 텍스트 크기 소폭 축소
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22, // 텍스트 크기 소폭 축소
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13, // 폰트 크기 확대
            color: Colors.black87, // 더 진한 색상으로 변경
            fontWeight: FontWeight.w600, // 폰트 두께 추가
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround, // 바 사이 간격 균등 분배
      children: _monthlyStats.map((stat) {
        return Container(
          width: 50, // 각 바 영역 너비 확대 (45 -> 50)
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: _buildBar(stat),
        );
      }).toList(),
    );
  }

  Widget _buildBar(_MonthlyStat stat) {
    double totalHeightRatio = _maxCount == 0 ? 0 : stat.total / _maxCount;

    return Tooltip(
      message: '${stat.year}.${stat.month}\n총 인원: ${stat.total}명',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double availableH = constraints.maxHeight - 20;
                double totalH = availableH * totalHeightRatio;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (stat.total > 0)
                      Text(
                        '${stat.total}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28, // 바 자체의 너비 확대 (22 -> 28)
                      height: math.max(totalH, 2.0), // 최소 높이 보장
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100, // 막대 영역 배경색 추가
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        border: Border.all(
                          color: Colors.blue.shade700.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: totalH,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.month == 1
                ? '${stat.year % 100}.${stat.month}월'
                : '${stat.month}월',
            style: const TextStyle(
              fontSize: 14, // 폰트 크기 추가 확대 (11 -> 14)
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyStat {
  final int year;
  final int month;
  final int total;

  _MonthlyStat({required this.year, required this.month, required this.total});
}
