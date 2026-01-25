import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 진동 피드백을 위해 추가
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/holiday_helper.dart';

class AttendanceScreen extends StatefulWidget {
  final AcademyModel academy;

  const AttendanceScreen({super.key, required this.academy});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  late int _currentYear;
  late int _currentMonth;
  int? _selectedSession;
  int _localStateCounter = 0; // 로컬 UI 강제 갱신용

  @override
  void initState() {
    super.initState();
    _currentYear = _selectedDate.year;
    _currentMonth = _selectedDate.month;
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadMonthlyAttendance(
        academyId: widget.academy.id,
        year: _currentYear,
        month: _currentMonth,
      );
      context.read<StudentProvider>().loadStudents(
        widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
    });
  }

  Widget _buildSessionFilter(List<dynamic> allStudents) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: Text('전체 (${allStudents.length})'),
            selected: _selectedSession == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSession = null);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(
              '미배정 (${allStudents.where((s) => s.session == null || s.session == 0).length})',
            ),
            selected: _selectedSession == 0,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSession = 0);
            },
          ),
          const SizedBox(width: 8),
          ...List.generate(widget.academy.totalSessions, (i) => i + 1).map((s) {
            final count = allStudents.where((st) => st.session == s).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$s부 ($count)'),
                selected: _selectedSession == s,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedSession = s);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  List<DateTime> _getLessonDates() {
    List<DateTime> dates = [];
    int daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      DateTime date = DateTime(_currentYear, _currentMonth, i);
      if (widget.academy.lessonDays.contains(date.weekday)) {
        dates.add(date);
      }
    }
    return dates;
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentYear++;
        _currentMonth = 1;
      } else {
        _currentMonth++;
      }
      _loadData();
    });
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentYear--;
        _currentMonth = 12;
      } else {
        _currentMonth--;
      }
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lessonDates = _getLessonDates();
    final authProvider = context.read<AuthProvider>();
    final ownerId = authProvider.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.academy.name} 출석부'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 년/월 선택 영역
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$_currentYear년 $_currentMonth월',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        'O: 파랑, X: 빨강',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                Consumer<StudentProvider>(
                  builder: (context, provider, _) =>
                      _buildSessionFilter(provider.students),
                ),
              ],
            ),
          ),

          Expanded(
            child: Consumer2<StudentProvider, AttendanceProvider>(
              builder: (context, studentProvider, attendanceProvider, child) {
                if (studentProvider.isLoading || attendanceProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = _selectedSession == null
                    ? studentProvider.students
                    : _selectedSession == 0
                    ? studentProvider.students
                          .where((s) => s.session == null || s.session == 0)
                          .toList()
                    : studentProvider.students
                          .where((s) => s.session == _selectedSession)
                          .toList();

                if (students.isEmpty) {
                  return const Center(child: Text('해당되는 학생이 없습니다.'));
                }

                // 빠른 조회를 위한 맵 생성 (key: "studentId_YYYY_MM_DD")
                final attendanceMap = <String, AttendanceRecord>{};
                for (var r in attendanceProvider.monthlyRecords) {
                  final key =
                      "${r.studentId}_${r.timestamp.year}_${r.timestamp.month}_${r.timestamp.day}";
                  attendanceMap[key] = r;
                }

                debugPrint(
                  'Rebuilding attendance table. Month: $_currentYear-$_currentMonth, Records: ${attendanceProvider.monthlyRecords.length}',
                );

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      key: ValueKey(
                        'at_table_${attendanceProvider.stateCounter}_${attendanceProvider.monthlyRecords.length}',
                      ),
                      columnSpacing: 12, // 간격 대폭 축소
                      horizontalMargin: 8,
                      headingRowHeight: 50, // 헤더 높이 축소
                      dataRowMinHeight: 45, // 데이터 행 높이 축소
                      dataRowMaxHeight: 45,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade50,
                      ),
                      // 테두리 스타일 변경: 수직선 제거, 깔끔한 수평선 위주
                      border: const TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.black12,
                          width: 0.5,
                        ),
                        bottom: BorderSide(color: Colors.black12, width: 0.5),
                      ),
                      columns: [
                        // 1. 이름 (항상 고정)
                        const DataColumn(
                          label: SizedBox(
                            width: 50,
                            child: Text(
                              '이름',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        // 2. 날짜별 컬럼
                        ...lessonDates.map((date) {
                          final holidayName = HolidayHelper.getHolidayName(
                            date,
                          );
                          final isHoliday = holidayName != null;
                          final isSunday = date.weekday == 7;
                          final textPrimaryColor = (isHoliday || isSunday)
                              ? Colors.red
                              : Colors.black87;

                          return DataColumn(
                            label: SizedBox(
                              width: 60, // 버튼 두 개가 들어갈 최소 너비
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    _getWeekdayName(date.weekday),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textPrimaryColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        // 3. 출석율 (맨 뒤로 이동 및 이름 변경)
                        const DataColumn(
                          label: SizedBox(
                            width: 50,
                            child: Text(
                              '출석율',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blueAccent,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                      rows: students.map((student) {
                        int presentCount = 0;
                        int validLessonCount = 0;

                        // 통계 계산
                        for (var date in lessonDates) {
                          final isHoliday = HolidayHelper.isHoliday(date);
                          if (!isHoliday) {
                            validLessonCount++;
                            final key =
                                "${student.id}_${date.year}_${date.month}_${date.day}";
                            if (attendanceMap[key]?.type ==
                                AttendanceType.present) {
                              presentCount++;
                            }
                          }
                        }

                        // 출석률 계산
                        int rate = validLessonCount == 0
                            ? 0
                            : ((presentCount / validLessonCount) * 100).round();
                        Color rateColor = rate >= 80
                            ? Colors.blue
                            : (rate >= 50 ? Colors.orange : Colors.red);

                        return DataRow(
                          cells: [
                            // 1. 이름
                            DataCell(
                              SizedBox(
                                width: 50,
                                child: Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            // 2. 날짜별 버튼
                            ...lessonDates.map((date) {
                              final isHoliday = HolidayHelper.isHoliday(date);

                              if (isHoliday) {
                                return const DataCell(
                                  Center(
                                    child: Text(
                                      '-',
                                      style: TextStyle(color: Colors.black26),
                                    ),
                                  ),
                                );
                              }

                              final key =
                                  "${student.id}_${date.year}_${date.month}_${date.day}";
                              final record = attendanceMap[key];

                              return DataCell(
                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildCompactButton(
                                        context,
                                        attendanceProvider,
                                        student.id,
                                        ownerId,
                                        date,
                                        AttendanceType.present,
                                        record?.type == AttendanceType.present,
                                      ),
                                      const SizedBox(width: 4), // 간격 축소
                                      _buildCompactButton(
                                        context,
                                        attendanceProvider,
                                        student.id,
                                        ownerId,
                                        date,
                                        AttendanceType.absent,
                                        record?.type == AttendanceType.absent,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            // 3. 출석율 (맨 뒤로 이동)
                            DataCell(
                              Container(
                                width: 50,
                                alignment: Alignment.center,
                                child: Text(
                                  '$rate%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: rateColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 컴팩트하고 예쁜 버튼 빌더
  Widget _buildCompactButton(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    AttendanceType type,
    bool isSelected,
  ) {
    Color activeColor;
    Color borderColor;
    String label = "";

    switch (type) {
      case AttendanceType.present:
        activeColor = const Color(0xFF3B82F6); // Modern Blue
        borderColor = const Color(0xFF2563EB);
        label = "O";
        break;
      case AttendanceType.absent:
        activeColor = const Color(0xFFEF4444); // Modern Red
        borderColor = const Color(0xFFDC2626);
        label = "X";
        break;
      default:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact(); // 가벼운 햅틱

        setState(() {
          _localStateCounter++;
        });

        provider.updateStatus(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: ownerId,
          date: date,
          type: isSelected ? null : type,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        key: ValueKey('b_${studentId}_${date.day}_${type.name}_$isSelected'),
        width: 28, // 확 줄임 (컴팩트)
        height: 28,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(6), // 약간 둥글게
          border: Border.all(
            color: isSelected ? borderColor : Colors.grey.shade300,
            width: isSelected ? 0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade400,
              fontWeight: FontWeight.w900, // 굵게
              fontSize: 14, // 적당한 크기
            ),
          ),
        ),
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      case 6:
        return '토';
      case 7:
        return '일';
      default:
        return '';
    }
  }
}
