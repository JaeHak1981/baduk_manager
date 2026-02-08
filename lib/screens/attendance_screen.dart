import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../utils/holiday_helper.dart';
import '../utils/file_download_helper.dart';
import '../constants/ui_constants.dart';
import 'components/statistics_dialog.dart';
import 'components/attendance_calendar.dart';
import 'components/attendance_session_filter.dart';
import 'components/batch_attendance_dialog.dart';

class AttendanceScreen extends StatefulWidget {
  final AcademyModel academy;
  final bool isEmbedded;
  final VoidCallback? onSelectionModeChanged;

  const AttendanceScreen({
    super.key,
    required this.academy,
    this.isEmbedded = false,
    this.onSelectionModeChanged,
  });

  @override
  State<AttendanceScreen> createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  late int _currentYear;
  late int _currentMonth;
  int? _selectedSession;
  int _localStateCounter = 0;
  bool _isDownloading = false;

  // 선택 모드 상태 전용 Notifier
  final ValueNotifier<int> _selectionNotifier = ValueNotifier<int>(0);
  final Set<String> selectedStudentIds = {};
  bool isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _currentYear = _selectedDate.year;
    _currentMonth = _selectedDate.month;
    _focusedDay = _selectedDate;
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ownerId = context.read<AuthProvider>().currentUser?.uid ?? '';
      context.read<AttendanceProvider>().loadMonthlyAttendance(
        academyId: widget.academy.id,
        ownerId: ownerId,
        year: _currentYear,
        month: _currentMonth,
      );
      context.read<ScheduleProvider>().loadSchedule(
        academyId: widget.academy.id,
        year: _currentYear,
        month: _currentMonth,
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
    final studentProvider = context.watch<StudentProvider>();

    Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 달력 영역 (좌측 고정폭)
        SizedBox(
          width: 260,
          child: AttendanceCalendar(
            selectedDate: _selectedDate,
            focusedDay: _focusedDay,
            academyId: widget.academy.id,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                final oldMonth = _currentMonth;
                final oldYear = _currentYear;
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
                _currentYear = selectedDay.year;
                _currentMonth = selectedDay.month;

                if (oldMonth != _currentMonth || oldYear != _currentYear) {
                  _loadData();
                }
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
        ),

        const VerticalDivider(width: 1),

        // 2. 메인 전개 영역
        Expanded(
          child: Column(
            children: [
              // 상단 필터 및 도구 모음
              Consumer2<StudentProvider, AttendanceProvider>(
                builder: (context, studentProvider, attendanceProvider, _) {
                  return AttendanceSessionFilter(
                    totalSessions: widget.academy.totalSessions,
                    selectedSession: _selectedSession,
                    students: studentProvider.students,
                    onSessionSelected: (session) =>
                        setState(() => _selectedSession = session),
                    hasPendingChanges: attendanceProvider.hasPendingChanges,
                    onSave: () async {
                      final success = await attendanceProvider
                          .savePendingChanges();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('출결 변경 사항이 저장되었습니다.')),
                        );
                      }
                    },
                    actions: [
                      ActionChip(
                        avatar: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.download,
                                size: 16,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isDownloading ? '준비 중...' : '엑셀 다운로드',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.blueAccent,
                        onPressed: _isDownloading
                            ? null
                            : () => _showDownloadSelectionDialog(
                                studentProvider.students,
                              ),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.bar_chart,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          '출석 통계',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.deepPurple,
                        onPressed: () =>
                            _showStatisticsDialog(studentProvider.students),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 1),

              // 월별 출석 테이블
              Expanded(child: _buildAttendanceTable(context, ownerId)),
            ],
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: isSelectionMode
            ? Text('${selectedStudentIds.length}명 선택됨')
            : Text('${widget.academy.name} 출석부'),
        actions: isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline),
                  tooltip: '부 이동',
                  onPressed: () => moveSelectedStudents(context, ownerId),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '삭제',
                  onPressed: () => deleteSelectedStudents(context, ownerId),
                ),
                TextButton(
                  onPressed: () => toggleSelectAll(
                    getVisibleStudents(studentProvider.students),
                  ),
                  child: const Text(
                    '전체선택',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: toggleSelectionMode,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.today),
                  tooltip: '오늘 날짜로 이동',
                  onPressed: () {
                    setState(() {
                      final now = DateTime.now();
                      _selectedDate = now;
                      _focusedDay = now;
                      _currentYear = now.year;
                      _currentMonth = now.month;
                      _loadData();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.check_box_outlined),
                  tooltip: '다중 선택',
                  onPressed: toggleSelectionMode,
                ),
              ],
      ),
      body: body,
    );
  }

  Widget _buildAttendanceTable(BuildContext context, String ownerId) {
    return Consumer2<StudentProvider, AttendanceProvider>(
      builder: (context, studentProvider, attendanceProvider, child) {
        final students = getVisibleStudents(studentProvider.students);
        final lessonDates = _getLessonDates();
        final scheduleProvider = context.watch<ScheduleProvider>();

        if ((studentProvider.isLoading && studentProvider.students.isEmpty) ||
            (attendanceProvider.isLoading &&
                attendanceProvider.monthlyRecords.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }

        if (students.isEmpty) {
          return const Center(child: Text('해당되는 학생이 없습니다.'));
        }

        final attendanceMap = <String, AttendanceRecord>{};
        for (var r in attendanceProvider.monthlyRecords) {
          final key =
              "${r.studentId}_${r.timestamp.year}_${r.timestamp.month}_${r.timestamp.day}";
          attendanceMap[key] = r;
        }

        return ValueListenableBuilder<int>(
          valueListenable: _selectionNotifier,
          builder: (context, _, child) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: EdgeInsets.only(
                bottom: AppDimensions.getBottomInset(context),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: ValueKey(
                    'at_table_${attendanceProvider.stateCounter}_$isSelectionMode',
                  ),
                  showCheckboxColumn: false,
                  columnSpacing: 8,
                  horizontalMargin: 8,
                  headingRowHeight: 50,
                  dataRowMinHeight: 45,
                  dataRowMaxHeight: 45,
                  headingRowColor: WidgetStateProperty.all(
                    isSelectionMode ? Colors.red.shade50 : Colors.grey.shade50,
                  ),
                  border: const TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.black12,
                      width: 0.5,
                    ),
                    bottom: BorderSide(color: Colors.black12, width: 0.5),
                  ),
                  columns: [
                    if (isSelectionMode)
                      DataColumn(
                        label: SizedBox(
                          width: 30,
                          child: Checkbox(
                            value:
                                students.isNotEmpty &&
                                selectedStudentIds.length == students.length,
                            onChanged: (v) => toggleSelectAll(students),
                          ),
                        ),
                      ),
                    const DataColumn(
                      label: SizedBox(
                        width: 30,
                        child: Text(
                          '번호',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: SizedBox(
                        width: 60,
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
                      final holidayName = HolidayHelper.getHolidayName(date);
                      final isAcademyHoliday = scheduleProvider.isDateHoliday(
                        date,
                      );
                      final isHoliday = holidayName != null || isAcademyHoliday;
                      final isSunday = date.weekday == 7;
                      final color = (isHoliday || isSunday)
                          ? Colors.red
                          : Colors.black87;

                      return DataColumn(
                        label: SizedBox(
                          width: 45,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                _getWeekdayName(date.weekday),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color.withOpacity(0.7),
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
                          '출석율',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: SizedBox(
                        width: 65,
                        child: Text(
                          '일괄',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: SizedBox(
                        width: 150,
                        child: Text('비고', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  rows: students.asMap().entries.map((entry) {
                    final index = entry.key;
                    final student = entry.value;
                    int presentCount = 0;
                    int validLessonCount = 0;

                    for (var date in lessonDates) {
                      if (!HolidayHelper.isHoliday(date) &&
                          !scheduleProvider.isDateHoliday(date)) {
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
                      selected: selectedStudentIds.contains(student.id),
                      onSelectChanged: isSelectionMode
                          ? (val) => toggleSelection(student.id)
                          : null,
                      cells: [
                        if (isSelectionMode)
                          DataCell(
                            Checkbox(
                              value: selectedStudentIds.contains(student.id),
                              onChanged: (val) => toggleSelection(student.id),
                            ),
                          ),
                        DataCell(
                          Container(
                            width: 30,
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
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
                            child: Container(
                              width: 60,
                              alignment: Alignment.centerLeft,
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
                        ...lessonDates.map((date) {
                          final isHoliday = HolidayHelper.isHoliday(date);
                          final isAcademyHoliday = scheduleProvider
                              .isDateHoliday(date);
                          if (isHoliday || isAcademyHoliday) {
                            final name = isHoliday
                                ? (HolidayHelper.getHolidayName(date) ?? "")
                                : "휴강";
                            final char = (index < name.length)
                                ? name[index]
                                : "";
                            return DataCell(
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.red.shade50,
                                child: Center(
                                  child: Text(
                                    char,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final record =
                              attendanceMap["${student.id}_${date.year}_${date.month}_${date.day}"];
                          return DataCell(
                            Center(
                              child: _buildCircularToggleCell(
                                context,
                                attendanceProvider,
                                student.id,
                                ownerId,
                                date,
                                record,
                              ),
                            ),
                          );
                        }),
                        DataCell(
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Text(
                              '$presentCount/$validLessonCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 65,
                            alignment: Alignment.center,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(60, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                final result = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => BatchAttendanceDialog(
                                    student: student,
                                    academyId: widget.academy.id,
                                    ownerId: ownerId,
                                    initialDate: DateTime(
                                      _currentYear,
                                      _currentMonth,
                                      1,
                                    ),
                                    lessonDays: widget.academy.lessonDays,
                                  ),
                                );
                                if (result == true && context.mounted) {
                                  // 추가 작업이 필요하다면 여기에 작성
                                }
                              },
                              child: const Text(
                                '일괄',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          _buildRemarkCell(
                            context,
                            attendanceProvider,
                            student.id,
                            ownerId,
                            attendanceMap,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRemarkCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    Map<String, AttendanceRecord> attendanceMap,
  ) {
    final monthRecords = provider.monthlyRecords
        .where(
          (r) =>
              r.studentId == studentId &&
              r.timestamp.year == _currentYear &&
              r.timestamp.month == _currentMonth &&
              r.note != null &&
              r.note!.trim().isNotEmpty,
        )
        .toList();
    monthRecords.sort((a, b) => a.timestamp.day.compareTo(b.timestamp.day));

    if (monthRecords.isEmpty) {
      return const SizedBox(
        width: 150,
        child: Text("-", style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }

    // 연속된 날짜와 동일한 내용 그룹화 로직
    List<String> groupedNotes = [];
    if (monthRecords.isNotEmpty) {
      int startDay = monthRecords[0].timestamp.day;
      int lastDay = startDay;
      String currentNote = monthRecords[0].note!;

      for (int i = 1; i < monthRecords.length; i++) {
        final r = monthRecords[i];
        final day = r.timestamp.day;
        final note = r.note!;

        // 날짜가 연속되고 내용이 같으면 그룹 유지
        if (day == lastDay + 1 && note == currentNote) {
          lastDay = day;
        } else {
          // 그룹 종료 및 추가
          if (startDay == lastDay) {
            groupedNotes.add("$startDay일: $currentNote");
          } else {
            groupedNotes.add("$startDay~$lastDay일: $currentNote");
          }
          // 새 그룹 시작
          startDay = day;
          lastDay = day;
          currentNote = note;
        }
      }
      // 마지막 그룹 추가
      if (startDay == lastDay) {
        groupedNotes.add("$startDay일: $currentNote");
      } else {
        groupedNotes.add("$startDay~$lastDay일: $currentNote");
      }
    }

    final combinedNotes = groupedNotes.join(" / ");

    return SizedBox(
      width: 150,
      child: Text(
        combinedNotes,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
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
    Widget child = isPresent
        ? const Icon(Icons.panorama_fish_eye, color: Colors.blue, size: 20)
        : isAbsent
        ? const Text(
            '/',
            style: TextStyle(
              color: Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          )
        : const SizedBox();

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _localStateCounter++);
        provider.toggleStatus(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: ownerId,
          date: date,
        );
      },
      child: Container(
        width: 30,
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: child),
      ),
    );
  }

  Future<void> _downloadAsExcel(List<dynamic> students) async {
    if (students.isEmpty) {
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final provider = context.read<AttendanceProvider>();
      final start = DateTime(_currentYear, _currentMonth, 1);
      final end = DateTime(_currentYear, _currentMonth + 1, 0);
      final records = await provider.getRecordsForPeriod(
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
        start: start,
        end: end,
      );

      var excel = excel_lib.Excel.createExcel();
      String sheetName = "$_currentYear년 $_currentMonth월 출석부";
      excel.rename('Sheet1', sheetName);
      var sheet = excel[sheetName];

      final List<DateTime> lessonDates = [];
      for (int i = 1; i <= end.day; i++) {
        DateTime d = DateTime(_currentYear, _currentMonth, i);
        if (widget.academy.lessonDays.contains(d.weekday)) {
          lessonDates.add(d);
        }
      }

      List<String> header = [
        '학생 이름',
        ...lessonDates.map((d) => "${d.month}/${d.day}"),
        '출석',
        '결석',
        '출석률(%)',
      ];
      var headerStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#E0E0E0'),
        bold: true,
        horizontalAlign: excel_lib.HorizontalAlign.Center,
      );
      for (var i = 0; i < header.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = excel_lib.TextCellValue(header[i]);
        cell.cellStyle = headerStyle;
      }

      final sorted = List.from(students)
        ..sort((a, b) => (a.session ?? 0).compareTo(b.session ?? 0));
      int currentRow = 1;
      int? lastSession;
      var sessionStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#F0F7FF'),
        bold: true,
      );

      for (var s in sorted) {
        final student = s as StudentModel;
        if (lastSession != student.session) {
          if (lastSession != null) {
            currentRow++;
          }
          var cell = sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRow,
            ),
          );
          cell.value = excel_lib.TextCellValue(
            student.session == 0 ? "미배정" : "${student.session}부",
          );
          cell.cellStyle = sessionStyle;
          currentRow++;
          lastSession = student.session;
        }

        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRow,
              ),
            )
            .value = excel_lib.TextCellValue(
          student.name,
        );
        int p = 0, a = 0, total = 0;

        for (var i = 0; i < lessonDates.length; i++) {
          final date = lessonDates[i];
          final hName = HolidayHelper.getHolidayName(date);
          final isAH = context.read<ScheduleProvider>().isDateHoliday(date);
          var cell = sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: i + 1,
              rowIndex: currentRow,
            ),
          );
          if (hName != null || isAH) {
            cell.value = excel_lib.TextCellValue(hName ?? "휴강");
          } else {
            final dStr =
                "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";

            // Manual firstWhereOrNull implementation to avoid collection dependency
            AttendanceRecord? r;
            for (final record in records) {
              if (record.id == "${student.id}_$dStr") {
                r = record;
                break;
              }
            }

            if (r != null) {
              cell.value = excel_lib.TextCellValue(
                r.type == AttendanceType.present ? 'O' : 'X',
              );
              if (r.type == AttendanceType.present) {
                p++;
              } else {
                a++;
              }
              total++;
            }
          }
        }
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: lessonDates.length + 1,
                rowIndex: currentRow,
              ),
            )
            .value = excel_lib.IntCellValue(
          p,
        );
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: lessonDates.length + 2,
                rowIndex: currentRow,
              ),
            )
            .value = excel_lib.IntCellValue(
          a,
        );
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: lessonDates.length + 3,
                rowIndex: currentRow,
              ),
            )
            .value = excel_lib.DoubleCellValue(
          total == 0 ? 0 : (p / total) * 100,
        );
        currentRow++;
      }

      final bytes = excel.save();
      if (bytes != null) {
        FileDownloadHelper.downloadBytes(
          bytes: bytes,
          fileName: "attendance_${_currentYear}_$_currentMonth.xlsx",
        );
      }
    } catch (e) {
      debugPrint('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showStatisticsDialog(List<dynamic> students) {
    final filtered = _selectedSession == null
        ? students.where((s) => s.session != 0).toList()
        : students.where((s) => s.session == _selectedSession).toList();
    if (filtered.isEmpty) {
      return;
    }
    showDialog(
      context: context,
      builder: (c) => StatisticsDialog(
        students: filtered.cast<StudentModel>(),
        academy: widget.academy,
        currentYear: _currentYear,
        currentMonth: _currentMonth,
        isSessionFiltered: true,
      ),
    );
  }

  void _showDownloadSelectionDialog(List<dynamic> all) {
    showDialog(
      context: context,
      builder: (c) => _DownloadSessionDialog(
        totalSessions: widget.academy.totalSessions,
        onConfirm: (sessions) {
          final filtered = all
              .where((s) => sessions.contains(s.session ?? 0))
              .toList();
          if (filtered.isNotEmpty) {
            _downloadAsExcel(filtered);
          }
        },
      ),
    );
  }

  List<DateTime> _getLessonDates() {
    int days = DateTime(_currentYear, _currentMonth + 1, 0).day;
    return List.generate(
      days,
      (i) => DateTime(_currentYear, _currentMonth, i + 1),
    ).where((d) => widget.academy.lessonDays.contains(d.weekday)).toList();
  }

  List<StudentModel> getVisibleStudents(List<StudentModel> all) {
    if (_selectedSession == null) {
      return all;
    }
    return all.where((s) => (s.session ?? 0) == _selectedSession).toList();
  }

  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedStudentIds.clear();
      }
      _selectionNotifier.value++;
    });
    widget.onSelectionModeChanged?.call();
  }

  void toggleSelection(String id) {
    setState(() {
      if (selectedStudentIds.contains(id)) {
        selectedStudentIds.remove(id);
      } else {
        selectedStudentIds.add(id);
      }
      _selectionNotifier.value++;
    });
    widget.onSelectionModeChanged?.call();
  }

  void toggleSelectAll(List<StudentModel> students) {
    setState(() {
      if (selectedStudentIds.length == students.length) {
        selectedStudentIds.clear();
      } else {
        selectedStudentIds.addAll(students.map((s) => s.id));
      }
      _selectionNotifier.value++;
    });
    widget.onSelectionModeChanged?.call();
  }

  Future<void> moveSelectedStudents(BuildContext context, String owner) async {
    if (selectedStudentIds.isEmpty) return;
    final target = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${selectedStudentIds.length}명 부 이동'),
        content: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('미배정'),
              selected: false,
              onSelected: (_) => Navigator.pop(c, 0),
            ),
            ...List.generate(widget.academy.totalSessions, (i) => i + 1).map(
              (s) => ChoiceChip(
                label: Text('$s부'),
                selected: false,
                onSelected: (_) => Navigator.pop(c, s),
              ),
            ),
          ],
        ),
      ),
    );
    if (target != null && context.mounted) {
      final success = await context.read<StudentProvider>().moveStudents(
        selectedStudentIds.toList(),
        target,
        academyId: widget.academy.id,
        ownerId: owner,
      );
      if (success && mounted) {
        setState(() {
          isSelectionMode = false;
          selectedStudentIds.clear();
        });
      }
    }
  }

  Future<void> deleteSelectedStudents(
    BuildContext context,
    String owner,
  ) async {
    if (selectedStudentIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text('선택한 ${selectedStudentIds.length}명의 학생을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final success = await context.read<StudentProvider>().deleteStudents(
        selectedStudentIds.toList(),
        academyId: widget.academy.id,
        ownerId: owner,
      );
      if (success) {
        setState(() {
          isSelectionMode = false;
          selectedStudentIds.clear();
        });
      }
    }
  }

  String _getWeekdayName(int weekday) {
    return ['', '월', '화', '수', '목', '금', '토', '일'][weekday];
  }
}

class _DownloadSessionDialog extends StatefulWidget {
  final int totalSessions;
  final Function(Set<int>) onConfirm;
  const _DownloadSessionDialog({
    required this.totalSessions,
    required this.onConfirm,
  });
  @override
  State<_DownloadSessionDialog> createState() => _DownloadSessionDialogState();
}

class _DownloadSessionDialogState extends State<_DownloadSessionDialog> {
  final Set<int> _selectedSessions = {};
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('다운로드할 부 선택'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('전체 선택'),
              value: _selectedSessions.length == widget.totalSessions + 1,
              onChanged: (v) => setState(() {
                if (v!) {
                  _selectedSessions.add(0);
                  for (int i = 1; i <= widget.totalSessions; i++) {
                    _selectedSessions.add(i);
                  }
                } else {
                  _selectedSessions.clear();
                }
              }),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('미배정 학생'),
              value: _selectedSessions.contains(0),
              onChanged: (v) => setState(() {
                if (v!) {
                  _selectedSessions.add(0);
                } else {
                  _selectedSessions.remove(0);
                }
              }),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            ...List.generate(widget.totalSessions, (i) => i + 1).map(
              (s) => CheckboxListTile(
                title: Text('$s부'),
                value: _selectedSessions.contains(s),
                onChanged: (v) => setState(() {
                  if (v!) {
                    _selectedSessions.add(s);
                  } else {
                    _selectedSessions.remove(s);
                  }
                }),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_selectedSessions);
            Navigator.pop(context);
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}
