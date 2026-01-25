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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_currentYear년 $_currentMonth월',
                  style: const TextStyle(
                    fontSize: 20,
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
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    '클릭: 출석 → 결석 → 지각 → 취소',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
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

                final students = studentProvider.students;
                if (students.isEmpty) {
                  return const Center(child: Text('등록된 학생이 없습니다.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade100,
                      ),
                      border: TableBorder.all(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                      columns: [
                        const DataColumn(
                          label: SizedBox(
                            width: 80,
                            child: Text(
                              '이름',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        ...lessonDates.map(
                          (date) => DataColumn(
                            label: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  _getWeekdayName(date.weekday),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getDayColor(date.weekday),
                                  ),
                                ),
                              ],
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
                              final record = attendanceProvider.monthlyRecords
                                  .firstWhere(
                                    (r) =>
                                        r.studentId == student.id &&
                                        r.timestamp.year == date.year &&
                                        r.timestamp.month == date.month &&
                                        r.timestamp.day == date.day,
                                    orElse: () => AttendanceRecord(
                                      id: '',
                                      studentId: '',
                                      academyId: '',
                                      ownerId: '',
                                      timestamp: date,
                                      type: AttendanceType
                                          .late, // Placeholder, will not be used
                                    ),
                                  );

                              return DataCell(
                                InkWell(
                                  onTap: () {
                                    attendanceProvider.toggleAttendance(
                                      studentId: student.id,
                                      academyId: widget.academy.id,
                                      ownerId: ownerId,
                                      date: date,
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    alignment: Alignment.center,
                                    child: _getAttendanceIcon(record),
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
    if (record.id.isEmpty) return const SizedBox.shrink();

    switch (record.type) {
      case AttendanceType.present:
        return const Icon(Icons.circle_outlined, color: Colors.green, size: 20);
      case AttendanceType.absent:
        return const Icon(Icons.close, color: Colors.red, size: 20);
      case AttendanceType.late:
        return const Text(
          'L',
          style: TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
      case AttendanceType.manual:
        return const Icon(Icons.edit_note, color: Colors.grey, size: 20);
    }
  }
}
