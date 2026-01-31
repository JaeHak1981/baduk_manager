import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import 'components/remark_cell.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/holiday_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/schedule_provider.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final AcademyModel academy;
  final bool isEmbedded;
  final VoidCallback? onSelectionModeChanged;

  const DailyAttendanceScreen({
    super.key,
    required this.academy,
    this.isEmbedded = false,
    this.onSelectionModeChanged,
  });

  @override
  State<DailyAttendanceScreen> createState() => DailyAttendanceScreenState();
}

class DailyAttendanceScreenState extends State<DailyAttendanceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  int? _selectedSession;

  List<StudentModel> getFilteredStudents(List<StudentModel> allStudents) {
    List<StudentModel> filtered = allStudents;
    if (_selectedSession != null) {
      filtered = filtered.where((s) {
        if (_selectedSession == 0) return s.session == null || s.session == 0;
        return s.session == _selectedSession;
      }).toList();
    }
    return filtered;
  }

  // 선택 모드 상태 전용 Notifier (개별 리빌드를 위해)
  final ValueNotifier<int> _selectionNotifier = ValueNotifier<int>(0);
  final Set<String> selectedStudentIds = {};
  bool isSelectionMode = false;
  // bool isSelectionMode = false; // 이 변수는 아래에 정의되어 있음

  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedStudentIds.clear();
      }
    });
    _selectionNotifier.value++; // 내부 리빌드 트리거
    widget.onSelectionModeChanged?.call(); // 외부(앱바) 리빌드 트리거
  }

  void toggleSelection(String id) {
    setState(() {
      if (selectedStudentIds.contains(id)) {
        selectedStudentIds.remove(id);
      } else {
        selectedStudentIds.add(id);
      }
    });
    _selectionNotifier.value++; // 내부 리빌드 트리거
    widget.onSelectionModeChanged?.call(); // 외부(앱바) 리빌드 트리거
  }

  void toggleSelectAll(List<StudentModel> students) {
    setState(() {
      if (selectedStudentIds.length == students.length) {
        selectedStudentIds.clear();
      } else {
        selectedStudentIds.addAll(students.map((s) => s.id));
      }
    });
    _selectionNotifier.value++; // 내부 리빌드 트리거
    widget.onSelectionModeChanged?.call(); // 외부(앱바) 리빌드 트리거
  }

  void clearSelection() {
    selectedStudentIds.clear();
    _selectionNotifier.value++;
    widget.onSelectionModeChanged?.call();
  }

  Future<void> moveSelectedStudents(
    BuildContext context,
    String currentOwnerId,
  ) async {
    if (selectedStudentIds.isEmpty) return;

    int? targetSession;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${selectedStudentIds.length}명 부 이동'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('이동할 부를 선택하세요.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('미배정'),
                  selected: false,
                  onSelected: (s) {
                    Navigator.pop(context, 0);
                  },
                ),
                ...List.generate(
                  widget.academy.totalSessions,
                  (i) => i + 1,
                ).map((s) {
                  return ChoiceChip(
                    label: Text('$s부'),
                    selected: false,
                    onSelected: (_) {
                      Navigator.pop(context, s);
                    },
                  );
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    ).then((value) {
      if (value != null) targetSession = value;
    });

    if (targetSession == null) return;
    if (!context.mounted) return;

    final provider = context.read<StudentProvider>();
    final success = await provider.moveStudents(
      selectedStudentIds.toList(),
      targetSession!,
      academyId: widget.academy.id,
      ownerId: currentOwnerId,
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '학생들이 ${targetSession == 0 ? "미배정" : "$targetSession부"}로 이동되었습니다.',
          ),
        ),
      );
      setState(() {
        isSelectionMode = false;
        selectedStudentIds.clear();
      });
      widget.onSelectionModeChanged?.call();
    }
  }

  Future<void> deleteSelectedStudents(
    BuildContext context,
    String currentOwnerId,
  ) async {
    if (selectedStudentIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text(
          '선택한 ${selectedStudentIds.length}명의 학생을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final provider = context.read<StudentProvider>();
    final success = await provider.deleteStudents(
      selectedStudentIds.toList(),
      academyId: widget.academy.id,
      ownerId: currentOwnerId,
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택한 학생이 삭제되었습니다.')));
      setState(() {
        isSelectionMode = false;
        selectedStudentIds.clear();
      });
      widget.onSelectionModeChanged?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ownerId = context.read<AuthProvider>().currentUser?.uid ?? '';
      context.read<AttendanceProvider>().loadMonthlyAttendance(
        academyId: widget.academy.id,
        ownerId: ownerId,
        year: _selectedDate.year,
        month: _selectedDate.month,
      );
      context.read<ScheduleProvider>().loadSchedule(
        academyId: widget.academy.id,
        year: _selectedDate.year,
        month: _selectedDate.month,
      );
      context.read<StudentProvider>().loadStudents(
        widget.academy.id,
        ownerId: ownerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = context.read<AuthProvider>();
    final ownerId = authProvider.currentUser?.uid ?? '';
    final scheduleProvider = context.watch<ScheduleProvider>();

    Widget content = Consumer2<StudentProvider, AttendanceProvider>(
      builder: (context, studentProvider, attendanceProvider, child) {
        final bool isStudentsEmpty = studentProvider.students.isEmpty;
        final bool isAttendanceEmpty =
            attendanceProvider.monthlyRecords.isEmpty;

        // 초기 로딩 중이거나 명확하게 로딩 중일 때 로딩 인디케이터 표시
        if ((studentProvider.isLoading && isStudentsEmpty) ||
            (attendanceProvider.isLoading && isAttendanceEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredStudents = getFilteredStudents(studentProvider.students);

        final attendanceMap = <String, AttendanceRecord>{};
        for (var r in attendanceProvider.monthlyRecords) {
          if (r.timestamp.year == _selectedDate.year &&
              r.timestamp.month == _selectedDate.month &&
              r.timestamp.day == _selectedDate.day) {
            attendanceMap[r.studentId] = r;
          }
        }

        final holidayName = HolidayHelper.getHolidayName(_selectedDate);
        final isAcademyHoliday = scheduleProvider.isDateHoliday(_selectedDate);

        if (holidayName != null || isAcademyHoliday) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  holidayName != null
                      ? '${_selectedDate.month}월 ${_selectedDate.day}일은 $holidayName입니다.'
                      : '${_selectedDate.month}월 ${_selectedDate.day}일은 학원 휴강일입니다.',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '출석 처리가 필요하지 않습니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSessionFilter(studentProvider.students),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final provider = context.read<AttendanceProvider>();
                      if (!provider.hasPendingChanges) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('저장할 변경 사항이 없습니다.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        return;
                      }
                      final success = await provider.savePendingChanges();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('출결 변경 사항이 저장되었습니다.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save, color: Colors.black),
                    label: const Text(
                      '저장하기',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _selectionNotifier,
                builder: (context, _, child) {
                  if (filteredStudents.isEmpty) {
                    return const Center(child: Text('표시할 학생이 없습니다.'));
                  }

                  // 10명씩 학생 데이터를 분할(Chunking)
                  final List<List<StudentModel>> studentChunks = [];
                  for (var i = 0; i < filteredStudents.length; i += 10) {
                    studentChunks.add(
                      filteredStudents.sublist(
                        i,
                        i + 10 > filteredStudents.length
                            ? filteredStudents.length
                            : i + 10,
                      ),
                    );
                  }

                  return Align(
                    alignment: Alignment.topLeft,
                    child: SingleChildScrollView(
                      key: const PageStorageKey(
                        'daily_attendance_scroll_horizontal',
                      ),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: studentChunks.map((chunk) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 24, 100),
                            child: DataTable(
                              key: ValueKey(
                                'daily_at_table_${attendanceProvider.stateCounter}_${chunk.length}_${isSelectionMode}_${chunk.first.id}',
                              ),
                              showCheckboxColumn: false,
                              columnSpacing: 12,
                              horizontalMargin: 8,
                              headingRowHeight: 45,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 40,
                              columns: [
                                if (isSelectionMode)
                                  DataColumn(
                                    label: SizedBox(
                                      width: 30,
                                      child: Checkbox(
                                        side: BorderSide(
                                          color: Colors.grey.shade600,
                                          width: 1.5,
                                        ),
                                        value:
                                            chunk.isNotEmpty &&
                                            chunk.every(
                                              (s) => selectedStudentIds
                                                  .contains(s.id),
                                            ),
                                        onChanged: (v) =>
                                            toggleSelectAll(chunk),
                                      ),
                                    ),
                                  ),
                                const DataColumn(
                                  label: Text(
                                    '번호',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    '이름',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const DataColumn(
                                  label: SizedBox(
                                    width: 60,
                                    child: Text(
                                      '출결',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                if (_selectedSession != null)
                                  const DataColumn(
                                    label: Text(
                                      '비고',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                              rows: chunk.map((student) {
                                final overallIndex = filteredStudents.indexOf(
                                  student,
                                );
                                final record = attendanceMap[student.id];
                                final isSelected = selectedStudentIds.contains(
                                  student.id,
                                );

                                return DataRow(
                                  selected: isSelected,
                                  onSelectChanged: isSelectionMode
                                      ? (val) => toggleSelection(student.id)
                                      : null,
                                  cells: [
                                    if (isSelectionMode)
                                      DataCell(
                                        SizedBox(
                                          width: 30,
                                          child: Checkbox(
                                            side: BorderSide(
                                              color: Colors.grey.shade600,
                                              width: 1.5,
                                            ),
                                            value: isSelected,
                                            onChanged: (val) =>
                                                toggleSelection(student.id),
                                          ),
                                        ),
                                      ),
                                    DataCell(
                                      Text(
                                        '${overallIndex + 1}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onLongPress: () {
                                          if (!isSelectionMode) {
                                            toggleSelectionMode();
                                            toggleSelection(student.id);
                                          }
                                        },
                                        onTap: isSelectionMode
                                            ? () => toggleSelection(student.id)
                                            : null,
                                        child: SizedBox(
                                          width: 60,
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
                                    ),
                                    DataCell(
                                      Center(
                                        child: Transform.scale(
                                          scale: 0.8,
                                          child: _buildCircularToggleCell(
                                            context,
                                            attendanceProvider,
                                            student.id,
                                            ownerId,
                                            _selectedDate,
                                            record,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_selectedSession != null)
                                      DataCell(
                                        SizedBox(
                                          width: 100, // 부별 명단에서는 너비를 더 줄임
                                          child: _buildRemarkCell(
                                            context,
                                            attendanceProvider,
                                            student.id,
                                            ownerId,
                                            _selectedDate,
                                            attendanceMap,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    Widget body = Row(
      children: [
        Container(
          width: 260,
          padding: const EdgeInsets.fromLTRB(20, 8, 4, 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              TableCalendar(
                locale: 'ko_KR',
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                  rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                  headerPadding: EdgeInsets.symmetric(vertical: 4),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekendStyle: TextStyle(color: Colors.red),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: Colors.red),
                  holidayTextStyle: const TextStyle(color: Colors.red),
                  outsideDaysVisible: false,
                ),
                holidayPredicate: (day) =>
                    HolidayHelper.isHoliday(day) ||
                    scheduleProvider.isDateHoliday(day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    final oldMonth = _selectedDate.month;
                    final oldYear = _selectedDate.year;
                    _selectedDate = selectedDay;
                    _focusedDay = focusedDay;

                    if (oldMonth != _selectedDate.month ||
                        oldYear != _selectedDate.year) {
                      _loadData();
                    }
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('학원 휴강 설정', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  '선택한 날짜를 휴강으로 지정합니다.',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: scheduleProvider.isDateHoliday(_selectedDate),
                    onChanged: (value) async {
                      await scheduleProvider.toggleHoliday(
                        academyId: widget.academy.id,
                        year: _selectedDate.year,
                        month: _selectedDate.month,
                        day: _selectedDate.day,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value ? '휴강으로 설정되었습니다.' : '휴강 설정이 해제되었습니다.',
                            ),
                            duration: const Duration(seconds: 1),
                            backgroundColor: value ? Colors.red : Colors.blue,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 40),
            child: content,
          ),
        ),
      ],
    );

    if (widget.isEmbedded) return body;

    final holidayName = HolidayHelper.getHolidayName(_selectedDate);
    final isSunday = _selectedDate.weekday == 7;
    final titleColor = (holidayName != null || isSunday)
        ? Colors.red
        : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedDate.month}월 ${_selectedDate.day}일 출결 체크',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (holidayName != null)
              Text(
                holidayName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        backgroundColor: (holidayName != null || isSunday)
            ? Colors.red.shade50
            : Theme.of(context).colorScheme.primaryContainer,
      ),
      body: body,
    );
  }

  Widget _buildSessionFilter(List<StudentModel> allStudents) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
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
          ...List.generate(widget.academy.totalSessions, (i) => i + 1).map((s) {
            final count = allStudents.where((st) => st.session == s).length;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
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

  Widget _buildRemarkCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    Map<String, AttendanceRecord> attendanceMap,
  ) {
    final record = attendanceMap[studentId];

    return RemarkCell(
      provider: provider,
      studentId: studentId,
      academyId: widget.academy.id,
      ownerId: ownerId,
      date: date,
      initialNote: record?.note ?? "",
    );
  }

  Widget _buildCircularToggleCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    AttendanceRecord? record,
  ) {
    bool isPresent = record?.type == AttendanceType.present;
    bool isAbsent = record?.type == AttendanceType.absent;

    Widget child;
    if (isPresent) {
      child = const Icon(Icons.panorama_fish_eye, color: Colors.blue, size: 20);
    } else if (isAbsent) {
      child = const Text(
        '/',
        style: TextStyle(
          color: Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      child = const SizedBox();
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        provider.toggleStatus(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: ownerId,
          date: date,
        );
      },
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26, width: 1.0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: child),
      ),
    );
  }
}
