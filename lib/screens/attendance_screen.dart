import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 진동 피드백을 위해 추가
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/holiday_helper.dart';
import '../utils/file_download_helper.dart';
import 'components/statistics_dialog.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/schedule_provider.dart';

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
  DateTime _focusedDay = DateTime.now(); // 달력 포커스용 추가
  late int _currentYear;
  late int _currentMonth;
  int? _selectedSession;
  int _localStateCounter = 0; // 로컬 UI 강제 갱신용
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentYear = _selectedDate.year;
    _currentMonth = _selectedDate.month;
    _focusedDay = _selectedDate; // 초기값 설정
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadMonthlyAttendance(
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
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
          const SizedBox(width: 8),
          // [추가] 출석부 다운로드 버튼
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
                : const Icon(Icons.download, size: 16, color: Colors.white),
            label: Text(
              _isDownloading ? '준비 중...' : '출석부 다운로드',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.blueAccent,
            onPressed: _isDownloading
                ? null
                : () => _showDownloadSelectionDialog(allStudents),
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.bar_chart, size: 16, color: Colors.white),
            label: const Text(
              '출석 통계',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.deepPurple,
            onPressed: () => _showStatisticsDialog(allStudents),
          ),
        ],
      ),
    );
  }

  // [수정] 출석부 진짜 엑셀(.xlsx) 다운로드 로직
  Future<void> _downloadAsExcel(List<dynamic> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다운로드할 학생이 없습니다.')));
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final provider = context.read<AttendanceProvider>();
      final startOfMonth = DateTime(_currentYear, _currentMonth, 1);
      final endOfMonth = DateTime(_currentYear, _currentMonth + 1, 0);

      final records = await provider.getRecordsForPeriod(
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
        start: startOfMonth,
        end: endOfMonth, // 이번 달 마지막 날까지
      );

      // 1. 엑셀 객체 생성 및 시트 설정
      var excel = excel_lib.Excel.createExcel();
      String sheetName = "$_currentYear년 $_currentMonth월 출석부";
      excel.rename('Sheet1', sheetName);
      var sheet = excel[sheetName];

      // 2. 수업일 리스트 생성 (Header용)
      final List<DateTime> lessonDates = [];
      for (int i = 1; i <= endOfMonth.day; i++) {
        DateTime d = DateTime(_currentYear, _currentMonth, i);
        if (widget.academy.lessonDays.contains(d.weekday) &&
            !HolidayHelper.isHoliday(d) &&
            !context.read<ScheduleProvider>().isDateHoliday(d)) {
          lessonDates.add(d);
        }
      }

      // 3. 헤더 구성 및 스타일 적용
      List<String> header = ['학생 이름'];
      for (var date in lessonDates) {
        header.add("${date.month}/${date.day}");
      }
      header.addAll(['출석', '결석', '출석률(%)']);

      // 헤더 스타일 (배경색, 볼드)
      var headerStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#E0E0E0'),
        fontFamily: excel_lib.getFontFamily(excel_lib.FontFamily.Arial),
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

      // 4. 데이터 영역 채우기 (부별 그룹화)
      // 부별로 정렬
      final sortedStudents = List.from(students);
      sortedStudents.sort((a, b) {
        final sa = (a as StudentModel).session ?? 0;
        final sb = (b as StudentModel).session ?? 0;
        return sa.compareTo(sb);
      });

      int currentRowIndex = 1;
      int? lastSession;

      // 구분선 스타일 (연한 파란색 배경, 볼드)
      var sessionGroupStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.fromHexString('#F0F7FF'),
        fontFamily: excel_lib.getFontFamily(excel_lib.FontFamily.Arial),
        bold: true,
        horizontalAlign: excel_lib.HorizontalAlign.Left,
      );

      for (var sIdx = 0; sIdx < sortedStudents.length; sIdx++) {
        final student = sortedStudents[sIdx] as StudentModel;
        final currentSession = student.session ?? 0;

        // 부가 바뀌면 구분선 추가
        if (lastSession != currentSession) {
          // 첫 번째 그룹이 아니면 빈 줄 하나 추가
          if (lastSession != null) {
            currentRowIndex++;
          }

          // 부 제목 행 추가
          String sessionLabel = currentSession == 0
              ? "미배정 학생 명단"
              : "$currentSession부 명단";
          var sessionCell = sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRowIndex,
            ),
          );
          sessionCell.value = excel_lib.TextCellValue(sessionLabel);
          sessionCell.cellStyle = sessionGroupStyle;

          currentRowIndex++;
          lastSession = currentSession;
        }

        final rowIndex = currentRowIndex;

        // 이름
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.TextCellValue(
          student.name,
        );

        int presentCount = 0;
        int absentCount = 0;
        int totalRecorded = 0;

        // 날짜별 기록
        for (var dIdx = 0; dIdx < lessonDates.length; dIdx++) {
          final date = lessonDates[dIdx];
          final dateStr =
              "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
          final recordId = "${student.id}_$dateStr";

          final record = records.any((r) => r.id == recordId)
              ? records.firstWhere((r) => r.id == recordId)
              : null;

          var cell = sheet.cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: dIdx + 1,
              rowIndex: rowIndex,
            ),
          );
          if (record != null) {
            cell.value = excel_lib.TextCellValue(
              record.type == AttendanceType.present ? 'O' : 'X',
            );
            if (record.type == AttendanceType.present) presentCount++;
            if (record.type == AttendanceType.absent) absentCount++;
            totalRecorded++;
          } else {
            cell.value = excel_lib.TextCellValue('');
          }
        }

        // 통계
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: lessonDates.length + 1,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.IntCellValue(
          presentCount,
        );
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: lessonDates.length + 2,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.IntCellValue(
          absentCount,
        );

        final rate = totalRecorded == 0
            ? 0.0
            : (presentCount / totalRecorded) * 100;
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: lessonDates.length + 3,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_lib.DoubleCellValue(
          rate,
        );

        currentRowIndex++; // 다음 학생을 위해 인덱스 증가
      }

      // 5. 다운로드
      final fileBytes = excel.save();
      if (fileBytes != null) {
        String fileName =
            "attendance_${_currentYear}_${_currentMonth.toString().padLeft(2, '0')}.xlsx";
        FileDownloadHelper.downloadBytes(bytes: fileBytes, fileName: fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fileName 다운로드를 시작합니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('엑셀 파일 데이터 생성에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('Excel Export Error: $e');
      if (mounted) {
        final errorMsg = e.toString();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('다운로드 오류 발생'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('다음 에러가 발생했습니다. 아래 내용을 복사해서 전달해 주세요:'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      errorMsg,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: errorMsg));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('에러 내용이 클립보드에 복사되었습니다.')),
                    );
                  }
                },
                child: const Text('클립보드 복사'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showStatisticsDialog(List<dynamic> students) {
    // 현재 필터링된 학생 기준 통계 계산
    // 미배정 학생(0부)은 다음달 수강 예정이므로 전체 통계에서 제외
    final filteredStudents = _selectedSession == null
        ? students.where((s) => s.session != null && s.session != 0).toList()
        : _selectedSession == 0
        ? students.where((s) => s.session == null || s.session == 0).toList()
        : students.where((s) => s.session == _selectedSession).toList();

    if (filteredStudents.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('통계를 낼 학생이 없습니다.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatisticsDialog(
        students: filteredStudents,
        academy: widget.academy,
        currentYear: _currentYear,
        currentMonth: _currentMonth,
        isSessionFiltered: true, // 미배정 학생 제외 등 항상 필터링된 목록을 사용하므로 true 설정
      ),
    );
  }

  void _showDownloadSelectionDialog(List<dynamic> allStudents) {
    showDialog(
      context: context,
      builder: (context) => _DownloadSessionDialog(
        totalSessions: widget.academy.totalSessions,
        onConfirm: (selectedSessions) {
          final filteredStudents = allStudents.where((s) {
            final student = s as StudentModel;
            final session = student.session ?? 0;
            return selectedSessions.contains(session);
          }).toList();

          if (filteredStudents.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('선택한 부에 학생이 없습니다.')));
            return;
          }

          _downloadAsExcel(filteredStudents);
        },
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

  List<StudentModel> getVisibleStudents(List<StudentModel> allStudents) {
    if (_selectedSession == null) return allStudents;
    if (_selectedSession == 0) {
      return allStudents
          .where((s) => s.session == null || s.session == 0)
          .toList();
    }
    return allStudents.where((s) => s.session == _selectedSession).toList();
  }

  // 선택 모드 상태 전용 Notifier
  final ValueNotifier<int> _selectionNotifier = ValueNotifier<int>(0);
  final Set<String> selectedStudentIds = {};
  bool isSelectionMode = false; // 선택 모드 상태

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    if (!isSelectionMode) {
      selectedStudentIds.clear();
    }
    _selectionNotifier.value++;
    widget.onSelectionModeChanged?.call();
  }

  void toggleSelection(String id) {
    if (selectedStudentIds.contains(id)) {
      selectedStudentIds.remove(id);
    } else {
      selectedStudentIds.add(id);
    }
    _selectionNotifier.value++;
    widget.onSelectionModeChanged?.call(); // AppBar updates
  }

  void toggleSelectAll(List<dynamic> students) {
    if (selectedStudentIds.length == students.length) {
      selectedStudentIds.clear();
    } else {
      selectedStudentIds.addAll(students.map((s) => s.id));
    }
    _selectionNotifier.value++;
    widget.onSelectionModeChanged?.call();
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
                  selected: targetSession == 0,
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
                    selected: targetSession == s,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep alive를 위해 호출
    final lessonDates = _getLessonDates();
    final authProvider = context.read<AuthProvider>();
    final ownerId = authProvider.currentUser?.uid ?? '';
    final scheduleProvider = context.watch<ScheduleProvider>();
    final studentProvider = context
        .watch<StudentProvider>(); // Watch to use filtered list in AppBar

    // 현재 화면에 보이는 학생 목록 (필터링 적용)
    final visibleStudents = getVisibleStudents(studentProvider.students);

    Widget content = Column(
      children: [
        // 상단 도구 모음 (저장, 통계 등)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Consumer<StudentProvider>(
                  builder: (context, provider, _) =>
                      _buildSessionFilter(provider.students),
                ),
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
          child: Consumer2<StudentProvider, AttendanceProvider>(
            builder: (context, studentProvider, attendanceProvider, child) {
              // 데이터가 아예 없을 때만 전면 로딩 인디케이터 표시 (스크롤 튕김 방지)
              final bool isStudentsEmpty = studentProvider.students.isEmpty;
              final bool isAttendanceEmpty =
                  attendanceProvider.monthlyRecords.isEmpty;

              if ((studentProvider.isLoading && isStudentsEmpty) ||
                  (attendanceProvider.isLoading && isAttendanceEmpty)) {
                return const Center(child: CircularProgressIndicator());
              }

              final students = visibleStudents; // 위에서 계산한 리스트 재사용

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

              return ValueListenableBuilder<int>(
                valueListenable: _selectionNotifier,
                builder: (context, _, child) {
                  return SingleChildScrollView(
                    key: const PageStorageKey('attendance_scroll_vertical'),
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      key: const PageStorageKey('attendance_scroll_horizontal'),
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        key: ValueKey(
                          'at_table_${attendanceProvider.stateCounter}_${attendanceProvider.monthlyRecords.length}_$isSelectionMode',
                        ),
                        showCheckboxColumn: false, // 수동으로 만든 체크박스와 겹치지 않게 비활성화
                        columnSpacing: 8, // 12에서 8로 축소
                        horizontalMargin: 8,
                        headingRowHeight: 50, // 헤더 높이 축소
                        dataRowMinHeight: 45, // 데이터 행 높이 축소
                        dataRowMaxHeight: 45,
                        headingRowColor: WidgetStateProperty.all(
                          isSelectionMode
                              ? Colors.red.shade50
                              : Colors.grey.shade50,
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
                          // 0. 체크박스 (전체 선택)
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
                                      students.isNotEmpty &&
                                      selectedStudentIds.length ==
                                          students.length,
                                  onChanged: (v) => toggleSelectAll(students),
                                ),
                              ),
                            ),
                          // 1. 번호 (가장 왼쪽 고정)
                          const DataColumn(
                            label: SizedBox(
                              width: 30,
                              child: Text(
                                '번호',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 2. 이름 (항상 고정)
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
                            final isAcademyHoliday = scheduleProvider
                                .isDateHoliday(date);
                            final isHoliday =
                                holidayName != null || isAcademyHoliday;
                            final isSunday = date.weekday == 7;
                            final textPrimaryColor = (isHoliday || isSunday)
                                ? Colors.red
                                : Colors.black87;

                            return DataColumn(
                              label: SizedBox(
                                width: 45, // 60에서 45로 축소
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
                                        color: textPrimaryColor.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // 3. 출석율
                          const DataColumn(
                            label: SizedBox(
                              width: 50,
                              child: Text(
                                '출석율',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 4. 비고 (추가)
                          const DataColumn(
                            label: SizedBox(
                              width: 150,
                              child: Text(
                                '비고',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                        rows: students.asMap().entries.map((entry) {
                          final index = entry.key;
                          final student = entry.value;
                          int presentCount = 0;
                          int validLessonCount = 0;

                          // 통계 계산
                          for (var date in lessonDates) {
                            final isHoliday = HolidayHelper.isHoliday(date);
                            final isAcademyHoliday = scheduleProvider
                                .isDateHoliday(date);
                            if (!isHoliday && !isAcademyHoliday) {
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
                          Color rateColor = Colors.black;

                          return DataRow(
                            selected: selectedStudentIds.contains(student.id),
                            onSelectChanged: isSelectionMode
                                ? (val) {
                                    toggleSelection(student.id);
                                  }
                                : null,
                            cells: [
                              // 0. 체크박스
                              if (isSelectionMode)
                                DataCell(
                                  SizedBox(
                                    width: 30,
                                    child: Checkbox(
                                      side: BorderSide(
                                        color: Colors.grey.shade600,
                                        width: 1.5,
                                      ),
                                      value: selectedStudentIds.contains(
                                        student.id,
                                      ),
                                      onChanged: (val) =>
                                          toggleSelection(student.id),
                                    ),
                                  ),
                                ),
                              // 1. 번호
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
                              // 2. 이름
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
                                    width: 50,
                                    height: double.infinity,
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
                              // 2. 날짜별 셀 (순환 토글 적용)
                              ...lessonDates.map((date) {
                                final isHoliday = HolidayHelper.isHoliday(date);
                                final isAcademyHoliday = scheduleProvider
                                    .isDateHoliday(date);

                                if (isHoliday || isAcademyHoliday) {
                                  final holidayName = isHoliday
                                      ? (HolidayHelper.getHolidayName(date) ??
                                            "")
                                      : "휴강";

                                  // 텍스트 배치: 상단부터 한 글자씩 (공백 포함 배경색 유지)
                                  final charToDisplay =
                                      (index < holidayName.length)
                                      ? holidayName[index]
                                      : "";

                                  return DataCell(
                                    Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors
                                          .red
                                          .shade50, // 휴강일 전체 컬럼 연한 빨강 배경
                                      child: Center(
                                        child: Text(
                                          charToDisplay,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final key =
                                    "${student.id}_${date.year}_${date.month}_${date.day}";
                                final record = attendanceMap[key];

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
                              // 3. 출석율
                              DataCell(
                                Container(
                                  width: 50,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$presentCount/$validLessonCount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: rateColor,
                                    ),
                                  ),
                                ),
                              ),
                              // 4. 비고 (추가)
                              DataCell(
                                _buildRemarkCell(
                                  context,
                                  attendanceProvider,
                                  student.id,
                                  ownerId,
                                  (_currentYear == DateTime.now().year &&
                                          _currentMonth == DateTime.now().month)
                                      ? DateTime.now()
                                      : DateTime(
                                          _currentYear,
                                          _currentMonth,
                                          1,
                                        ),
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
          ),
        ),
      ],
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
                    // 페이지 변경 시 자동으로 해당 월 데이터 로드 여부는 선택(일일출결과 동일하게 유지)
                  });
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
        Expanded(child: content),
      ],
    );

    if (widget.isEmbedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: isSelectionMode
            ? Text(
                '${selectedStudentIds.length}명 선택됨',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : Text(
                '${widget.academy.name} 출석부',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
        backgroundColor: isSelectionMode
            ? Colors.red.shade50
            : Theme.of(context).colorScheme.inversePrimary,
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: toggleSelectionMode,
              )
            : null,
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
                  onPressed: () =>
                      toggleSelectAll(visibleStudents), // 필터링된 학생 전체 선택
                  child: Text(
                    selectedStudentIds.length == visibleStudents.length &&
                            visibleStudents.isNotEmpty
                        ? '해제'
                        : '전체',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
              ]
            : [
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

  // [추가] 비고란 셀 빌더 - 월별 출석부용 (해당 월의 모든 비고 누적 표시)
  Widget _buildRemarkCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    Map<String, AttendanceRecord> attendanceMap,
  ) {
    // 해당 학생의 이 달의 모든 기록 중 비고가 있는 것만 추출
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

    // 날짜 연대순 정렬
    monthRecords.sort((a, b) => a.timestamp.day.compareTo(b.timestamp.day));

    // "일: 내용 / 일: 내용" 형식으로 변환
    final combinedNotes = monthRecords
        .map((r) => "${r.timestamp.day}일: ${r.note}")
        .join(" / ");

    return SizedBox(
      width: 150,
      child: Text(
        combinedNotes.isEmpty ? "-" : combinedNotes,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // [변경] 순환 토글 방식의 셀 빌더 (빈 칸 -> ○ -> / -> 빈 칸)
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
        setState(() {
          _localStateCounter++;
        });
        provider.toggleStatus(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: ownerId,
          date: date,
        );
      },
      child: Container(
        width: 30, // 35에서 30으로 축소
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26, width: 1.0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: child),
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
  void initState() {
    super.initState();
    // 기본값은 전체 미체크로 설정
  }

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
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSessions.add(0);
                    for (int i = 1; i <= widget.totalSessions; i++) {
                      _selectedSessions.add(i);
                    }
                  } else {
                    _selectedSessions.clear();
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(),
            CheckboxListTile(
              title: const Text('미배정 학생'),
              value: _selectedSessions.contains(0),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSessions.add(0);
                  } else {
                    _selectedSessions.remove(0);
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            ...List.generate(widget.totalSessions, (i) => i + 1).map((s) {
              return CheckboxListTile(
                title: Text('$s부'),
                value: _selectedSessions.contains(s),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedSessions.add(s);
                    } else {
                      _selectedSessions.remove(s);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _selectedSessions.isEmpty
              ? null
              : () {
                  widget.onConfirm(_selectedSessions);
                  Navigator.pop(context);
                },
          child: const Text('다운로드'),
        ),
      ],
    );
  }
}
