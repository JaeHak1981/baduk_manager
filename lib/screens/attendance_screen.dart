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
import 'components/remark_cell.dart';

class AttendanceScreen extends StatefulWidget {
  final AcademyModel academy;
  final bool isEmbedded;

  const AttendanceScreen({
    super.key,
    required this.academy,
    this.isEmbedded = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
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
                : () {
                    final filteredStudents = _selectedSession == null
                        ? allStudents
                        : _selectedSession == 0
                        ? allStudents
                              .where((s) => s.session == null || s.session == 0)
                              .toList()
                        : allStudents
                              .where((s) => s.session == _selectedSession)
                              .toList();
                    _downloadAsExcel(filteredStudents);
                  },
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
            !HolidayHelper.isHoliday(d)) {
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

      // 4. 데이터 영역 채우기
      for (var sIdx = 0; sIdx < students.length; sIdx++) {
        final student = students[sIdx] as StudentModel;
        final rowIndex = sIdx + 1;

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
    final filteredStudents = _selectedSession == null
        ? students
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
        isSessionFiltered: _selectedSession != null,
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

  // 선택된 학생 ID 목록
  final Set<String> _selectedStudentIds = {};
  bool _isSelectionMode = false; // 선택 모드 상태

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedStudentIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
        if (_selectedStudentIds.isEmpty) {
          // 선택된 학생이 없으면 자동으로 모드 해제할지는 기획에 따름.
          // 여기선 유지하되 사용자 경험상 0명이면 모드 유지
        }
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<dynamic> students) {
    setState(() {
      if (_selectedStudentIds.length == students.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds.addAll(students.map((s) => s.id));
      }
    });
  }

  Future<void> _moveSelectedStudents(
    BuildContext context,
    String currentOwnerId,
  ) async {
    if (_selectedStudentIds.isEmpty) return;

    int? targetSession;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_selectedStudentIds.length}명 부 이동'),
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
      _selectedStudentIds.toList(),
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
        _isSelectionMode = false;
        _selectedStudentIds.clear();
      });
    }
  }

  Future<void> _deleteSelectedStudents(
    BuildContext context,
    String currentOwnerId,
  ) async {
    if (_selectedStudentIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text(
          '선택한 ${_selectedStudentIds.length}명의 학생을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
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
      _selectedStudentIds.toList(),
      academyId: widget.academy.id,
      ownerId: currentOwnerId,
    );

    if (success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택한 학생이 삭제되었습니다.')));
      setState(() {
        _isSelectionMode = false;
        _selectedStudentIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep alive를 위해 호출
    final lessonDates = _getLessonDates();
    final authProvider = context.read<AuthProvider>();
    final ownerId = authProvider.currentUser?.uid ?? '';
    final studentProvider = context
        .watch<StudentProvider>(); // Watch to use filtered list in AppBar

    // 현재 화면에 보이는 학생 목록 (필터링 적용)
    final visibleStudents = _selectedSession == null
        ? studentProvider.students
        : _selectedSession == 0
        ? studentProvider.students
              .where((s) => s.session == null || s.session == 0)
              .toList()
        : studentProvider.students
              .where((s) => s.session == _selectedSession)
              .toList();

    Widget body = Column(
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
                  if (context.watch<AttendanceProvider>().hasPendingChanges)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await context
                              .read<AttendanceProvider>()
                              .savePendingChanges();
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('출결 변경 사항이 저장되었습니다.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('저장하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12),
                        children: [
                          TextSpan(
                            text: 'O : 파랑',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: '   ',
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextSpan(
                            text: 'X : 빨강',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

              return SingleChildScrollView(
                key: const PageStorageKey('attendance_scroll_vertical'),
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  key: const PageStorageKey('attendance_scroll_horizontal'),
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    key: ValueKey(
                      'at_table_${attendanceProvider.stateCounter}_${attendanceProvider.monthlyRecords.length}_${_selectedStudentIds.length}_$_isSelectionMode',
                    ),
                    showCheckboxColumn: false, // 수동으로 만든 체크박스와 겹치지 않게 비활성화
                    columnSpacing: 12, // 간격 대폭 축소
                    horizontalMargin: 8,
                    headingRowHeight: 50, // 헤더 높이 축소
                    dataRowMinHeight: 45, // 데이터 행 높이 축소
                    dataRowMaxHeight: 45,
                    headingRowColor: WidgetStateProperty.all(
                      _isSelectionMode
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
                      if (_isSelectionMode)
                        DataColumn(
                          label: SizedBox(
                            width: 30,
                            child: Checkbox(
                              value:
                                  students.isNotEmpty &&
                                  _selectedStudentIds.length == students.length,
                              onChanged: (v) => _toggleSelectAll(students),
                            ),
                          ),
                        ),
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
                        final holidayName = HolidayHelper.getHolidayName(date);
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
                      // 3. 출석율
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
                      Color rateColor =
                          (validLessonCount > 0 &&
                              (presentCount / validLessonCount) >= 0.8)
                          ? Colors.blue
                          : (presentCount > 0 ? Colors.orange : Colors.red);

                      return DataRow(
                        selected: _selectedStudentIds.contains(student.id),
                        onSelectChanged: _isSelectionMode
                            ? (val) {
                                _toggleSelection(student.id);
                              }
                            : null,
                        cells: [
                          // 0. 체크박스
                          if (_isSelectionMode)
                            DataCell(
                              SizedBox(
                                width: 30,
                                child: Checkbox(
                                  value: _selectedStudentIds.contains(
                                    student.id,
                                  ),
                                  onChanged: (val) =>
                                      _toggleSelection(student.id),
                                ),
                              ),
                            ),
                          // 1. 이름
                          DataCell(
                            InkWell(
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  _toggleSelectionMode();
                                  _toggleSelection(student.id);
                                }
                              },
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(student.id)
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

                            if (isHoliday) {
                              final holidayName =
                                  HolidayHelper.getHolidayName(date) ?? "";
                              if (holidayName.isEmpty)
                                return const DataCell(SizedBox());

                              final totalRows = students.length;
                              final textLength = holidayName.length;
                              int startIndex = (totalRows - textLength) ~/ 2;
                              if (startIndex < 0) startIndex = 0;

                              final charIndex = index - startIndex;
                              String charToDisplay = "";
                              if (charIndex >= 0 && charIndex < textLength) {
                                charToDisplay = holidayName[charIndex];
                              }

                              return DataCell(
                                Center(
                                  child: Text(
                                    charToDisplay,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
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
                              DateTime(_currentYear, _currentMonth, 1),
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
          ),
        ),
      ],
    );

    if (widget.isEmbedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedStudentIds.length}명 선택됨')
            : Text('${widget.academy.name} 출석부'),
        backgroundColor: _isSelectionMode
            ? Colors.red.shade50
            : Theme.of(context).colorScheme.inversePrimary,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline),
                  tooltip: '부 이동',
                  onPressed: () => _moveSelectedStudents(context, ownerId),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '삭제',
                  onPressed: () => _deleteSelectedStudents(context, ownerId),
                ),
                TextButton(
                  onPressed: () =>
                      _toggleSelectAll(visibleStudents), // 필터링된 학생 전체 선택
                  child: Text(
                    _selectedStudentIds.length == visibleStudents.length &&
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
                  onPressed: _toggleSelectionMode,
                ),
              ],
      ),
      body: body,
    );
  }

  // [추가] 비고란 셀 빌더
  Widget _buildRemarkCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    Map<String, AttendanceRecord> attendanceMap,
  ) {
    final key = "${studentId}_${date.year}_${date.month}_${date.day}";
    final record = attendanceMap[key];

    return RemarkCell(
      provider: provider,
      studentId: studentId,
      academyId: widget.academy.id,
      ownerId: ownerId,
      date: date,
      initialNote: record?.note ?? "",
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
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
