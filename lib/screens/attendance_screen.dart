import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
// import 'package:intl/intl.dart';

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
                        '출석(O) 결석(X) 지각(L)',
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

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 10,
                      horizontalMargin: 12,
                      headingRowHeight: 50,
                      dataRowMinHeight: 45,
                      dataRowMaxHeight: 45,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade100,
                      ),
                      border: TableBorder.all(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                      columns: [
                        const DataColumn(
                          label: SizedBox(
                            width: 70,
                            child: Text(
                              '이름',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        ...lessonDates.map(
                          (date) => DataColumn(
                            label: SizedBox(
                              width: 25,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _getWeekdayName(date.weekday),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _getDayColor(date.weekday),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      rows: students.map((student) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ...lessonDates.map((date) {
                              final key =
                                  "${student.id}_${date.year}_${date.month}_${date.day}";
                              final record = attendanceMap[key];

                              return DataCell(
                                InkWell(
                                  onTap: () =>
                                      attendanceProvider.toggleAttendance(
                                        studentId: student.id,
                                        academyId: widget.academy.id,
                                        ownerId: ownerId,
                                        date: date,
                                      ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: record != null
                                        ? _getAttendanceIcon(record)
                                        : const SizedBox(width: 25),
                                  ),
                                ),
                              );
                            }),
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

  Color _getDayColor(int weekday) {
    if (weekday == 6) return Colors.blue;
    if (weekday == 7) return Colors.red;
    return Colors.black54;
  }

  Widget _getAttendanceIcon(AttendanceRecord record) {
    switch (record.type) {
      case AttendanceType.present:
        return const Icon(Icons.circle_outlined, color: Colors.green, size: 22);
      case AttendanceType.absent:
        return const Icon(Icons.close, color: Colors.red, size: 22);
      case AttendanceType.late:
        return const Text(
          'L',
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        );
      case AttendanceType.manual:
        return const Icon(Icons.edit_note, color: Colors.grey, size: 22);
    }
  }
}
