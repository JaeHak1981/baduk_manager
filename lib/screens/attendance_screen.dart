import 'package:flutter/material.dart';
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
  int? _selectedSession; // 선택된 부 (null: 전체, 0: 미배정)

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
                        '파란색: 선택됨',
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
                      // 데이터가 바뀌면 테이블을 새로 그리도록 함
                      key: ValueKey(
                        'attendance_table_${_currentYear}_${_currentMonth}_${attendanceProvider.monthlyRecords.length}',
                      ),
                      columnSpacing: 15,
                      horizontalMargin: 12,
                      headingRowHeight: 65,
                      dataRowMinHeight: 65,
                      dataRowMaxHeight: 65,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade100,
                      ),
                      border: TableBorder.all(
                        color: Colors.grey.shade500,
                        width: 1.2,
                      ),
                      columns: [
                        const DataColumn(
                          label: SizedBox(
                            width: 65,
                            child: Text(
                              '이름',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        ...lessonDates.map((date) {
                          final holidayName = HolidayHelper.getHolidayName(
                            date,
                          );
                          final isHoliday = holidayName != null;
                          final isSunday = date.weekday == 7;
                          final textPrimaryColor = (isHoliday || isSunday)
                              ? Colors.red
                              : Colors.black;

                          return DataColumn(
                            label: SizedBox(
                              width: 80, // 너비 확장
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    _getWeekdayName(date.weekday),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                  if (isHoliday)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        holidayName,
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const DataColumn(
                          label: SizedBox(
                            width: 50,
                            child: Text(
                              '출석/계',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ...lessonDates.map((date) {
                              final isHoliday = HolidayHelper.isHoliday(date);

                              if (isHoliday) {
                                return const DataCell(
                                  Center(
                                    child: Text(
                                      '-',
                                      style: TextStyle(color: Colors.grey),
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
                                      _buildStatusButton(
                                        context,
                                        attendanceProvider,
                                        student.id,
                                        ownerId,
                                        date,
                                        AttendanceType.present,
                                        record?.type == AttendanceType.present,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusButton(
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
                            DataCell(
                              Center(
                                child: Text(
                                  '$presentCount/$validLessonCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blue,
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

  Widget _buildStatusButton(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    AttendanceType type,
    bool isSelected,
  ) {
    Color activeColor;
    String label = "";

    switch (type) {
      case AttendanceType.present:
        activeColor = Colors.blue.shade600; // 선명한 파란색
        label = "O";
        break;
      case AttendanceType.absent:
        activeColor = Colors.red.shade600; // 선명한 빨간색
        label = "X";
        break;
      default:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 터치 영역 안정성 강화
      onTap: () {
        provider.updateStatus(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: ownerId,
          date: date,
          type: isSelected ? null : type,
        );
      },
      child: Container(
        // key를 부여하여 상태 변경 시 반드시 다시 그리게 함
        key: ValueKey('btn_${studentId}_${date.day}_${type.name}_$isSelected'),
        width: 40, // 버튼 크기 조금 더 확대
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade400,
            width: 2, // 테두리 조금 더 굵게
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 18, // 글자 크기 확대
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
