import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/academy_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../utils/holiday_helper.dart';

class StatisticsDialog extends StatefulWidget {
  final List<dynamic> students;
  final AcademyModel academy;
  final int currentYear;
  final int currentMonth;

  const StatisticsDialog({
    super.key,
    required this.students,
    required this.academy,
    required this.currentYear,
    required this.currentMonth,
  });

  @override
  State<StatisticsDialog> createState() => _StatisticsDialogState();
}

class _StatisticsDialogState extends State<StatisticsDialog> {
  int _selectedPeriod = 0; // 0: 1개월, 1: 3개월, 2: 직접 입력

  // 직접 입력을 위한 날짜 (월 단위)
  late DateTime _startDate;
  late DateTime _endDate;

  bool _isLoading = false;

  // 계산된 통계 데이터
  int _totalPresent = 0;
  int _totalAbsent = 0;
  double _attendanceRate = 0.0;
  int _totalLessonDays = 0; // 기간 내 총 수업일 수

  @override
  void initState() {
    super.initState();
    // 초기값: 현재 월
    _startDate = DateTime(widget.currentYear, widget.currentMonth);
    _endDate = DateTime(widget.currentYear, widget.currentMonth);

    // 초기 데이터 로드 (1개월)
    _fetchAndCalculate();
  }

  Future<void> _fetchAndCalculate() async {
    setState(() => _isLoading = true);

    try {
      DateTime start, end;

      if (_selectedPeriod == 0) {
        // 1개월: 현재 화면의 연/월
        start = DateTime(widget.currentYear, widget.currentMonth);
        end = DateTime(widget.currentYear, widget.currentMonth);
      } else if (_selectedPeriod == 1) {
        // 3개월: (현재 - 2개월) ~ 현재
        final now = DateTime(widget.currentYear, widget.currentMonth);
        start = DateTime(now.year, now.month - 2);
        end = now;
      } else {
        // 직접 입력
        start = _startDate;
        end = _endDate;
      }

      final provider = context.read<AttendanceProvider>();
      final records = await provider.getRecordsForPeriod(
        academyId: widget.academy.id,
        start: start,
        end: end,
      );

      // 통계 계산
      _calculateStats(records, start, end);
    } catch (e) {
      debugPrint('Error calculating stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStats(
    List<AttendanceRecord> records,
    DateTime start,
    DateTime end,
  ) {
    int present = 0;
    int absent = 0;
    int validLessons = 0;
    int lessonDaysCount = 0;

    // 기간 내 수업일(Date) 계산 (휴일 제외)
    // start부터 end의 마지막 날까지 루프
    DateTime loopStart = DateTime(start.year, start.month, 1);
    DateTime loopEnd = DateTime(end.year, end.month + 1, 0); // 해당 월의 마지막 날

    List<DateTime> validDates = [];

    for (int i = 0; i <= loopEnd.difference(loopStart).inDays; i++) {
      DateTime d = loopStart.add(Duration(days: i));
      if (widget.academy.lessonDays.contains(d.weekday) &&
          !HolidayHelper.isHoliday(d)) {
        validDates.add(d);
        lessonDaysCount++;
      }
    }

    // 빠른 조회를 위한 맵
    final recordMap = <String, AttendanceRecord>{};
    for (var r in records) {
      final key =
          "${r.studentId}_${r.timestamp.year}_${r.timestamp.month}_${r.timestamp.day}";
      recordMap[key] = r;
    }

    for (var student in widget.students) {
      for (var date in validDates) {
        final key = "${student.id}_${date.year}_${date.month}_${date.day}";
        final record = recordMap[key];

        if (record?.type == AttendanceType.present) present++;
        if (record?.type == AttendanceType.absent) absent++;

        validLessons++;
      }
    }

    setState(() {
      _totalPresent = present;
      _totalAbsent = absent;
      _totalLessonDays = lessonDaysCount;
      _attendanceRate = validLessons == 0 ? 0 : (present / validLessons) * 100;

      // 날짜 업데이트 (제목 표시용)
      if (_selectedPeriod != 2) {
        _startDate = start;
        _endDate = end;
      }
    });
  }

  // 월 선택 피커
  Future<void> _pickMonth(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: isStart ? '시작 월 선택' : '종료 월 선택',
      initialDatePickerMode: DatePickerMode.year, // 연도부터 선택하게 하여 월 선택 유도
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(picked.year, picked.month);
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = DateTime(picked.year, picked.month);
          if (_startDate.isAfter(_endDate)) _startDate = _endDate;
        }
      });
      _fetchAndCalculate();
    }
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    if (_selectedPeriod == 0) {
      titleText = "${_startDate.year}.${_startDate.month} 월간 통계";
    } else {
      titleText =
          "${_startDate.year}.${_startDate.month} ~ ${_endDate.year}.${_endDate.month} 통계";
    }

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text('출석 통계', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 12),
          // 기간 선택 버튼
          SizedBox(
            width: double.maxFinite,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('1개월')),
                ButtonSegment(value: 1, label: Text('3개월')),
                ButtonSegment(value: 2, label: Text('직접 입력')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedPeriod = newSelection.first;
                });
                _fetchAndCalculate();
              },
              style: ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedPeriod == 2) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _pickMonth(true),
                    child: Text("${_startDate.year}.${_startDate.month}"),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text("~"),
                  ),
                  OutlinedButton(
                    onPressed: () => _pickMonth(false),
                    child: Text("${_endDate.year}.${_endDate.month}"),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              )
            else
              Column(
                children: [
                  Text(
                    titleText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('대상 학생', '${widget.students.length}명'),
                  _buildStatRow('기간 내 총 수업일', '${_totalLessonDays}회'),
                  const Divider(),
                  _buildStatRow('총 출석', '$_totalPresent회', color: Colors.blue),
                  _buildStatRow('총 결석', '$_totalAbsent회', color: Colors.red),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '평균 출석률',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_attendanceRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
