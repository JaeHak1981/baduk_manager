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
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.bar_chart, size: 16, color: Colors.white),
            label: const Text(
              '통계',
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

    final attendanceProvider = context.read<AttendanceProvider>();
    final lessonDates = _getLessonDates();

    int totalPresent = 0;
    int totalAbsent = 0;
    int totalValidLessons = 0; // 학생별 수업일수의 합

    // 빠른 조회를 위한 로컬 맵 생성
    final localMap = <String, AttendanceRecord>{};
    for (var r in attendanceProvider.monthlyRecords) {
      final key =
          "${r.studentId}_${r.timestamp.year}_${r.timestamp.month}_${r.timestamp.day}";
      localMap[key] = r;
    }

    for (var student in filteredStudents) {
      for (var date in lessonDates) {
        if (HolidayHelper.isHoliday(date)) continue;

        final key = "${student.id}_${date.year}_${date.month}_${date.day}";
        final record = localMap[key];

        if (record?.type == AttendanceType.present) totalPresent++;
        if (record?.type == AttendanceType.absent) totalAbsent++;

        totalValidLessons++;
      }
    }

    // 전체 출석률 (총 출석 수 / (총 학생 수 * 수업일수))
    // *주의: 각 학생별로 수업일수가 같다고 가정 (휴일 제외)
    // 정확히는 (총 출석 수 / 총 유효 수업 횟수)
    double attendanceRate = totalValidLessons == 0
        ? 0
        : (totalPresent / totalValidLessons) * 100;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bar_chart, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('${_currentMonth}월 출석 통계'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('대상 학생', '${filteredStudents.length}명'),
            _buildStatRow(
              '총 수업 횟수',
              '${lessonDates.where((d) => !HolidayHelper.isHoliday(d)).length}회',
            ),
            const Divider(),
            _buildStatRow('총 출석', '$totalPresent회', color: Colors.blue),
            _buildStatRow('총 결석', '$totalAbsent회', color: Colors.red),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '평균 출석률',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${attendanceRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
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
            ),
          ),
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
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
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
                                    _selectedStudentIds.length ==
                                        students.length,
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
                              : null, // 선택 모드 아닐 땐 null
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
                            // 1. 이름 (롱프레스 기능 추가)
                            DataCell(
                              InkWell(
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode(); // 모드 진입
                                    _toggleSelection(student.id); // 해당 학생 선택
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
                            // 2. 날짜별 버튼
                            ...lessonDates.map((date) {
                              final isHoliday = HolidayHelper.isHoliday(date);

                              if (isHoliday) {
                                final holidayName =
                                    HolidayHelper.getHolidayName(date) ?? "";
                                if (holidayName.isEmpty)
                                  return const DataCell(SizedBox());

                                // 세로 글씨 로직
                                final totalRows = students.length;
                                final textLength = holidayName.length;

                                // 충분한 공간이 있는 경우 중앙 정렬
                                int startIndex = (totalRows - textLength) ~/ 2;
                                if (startIndex < 0)
                                  startIndex =
                                      0; // 학생 수가 글자 수보다 적을 때 예외 처리 (상단부터 표시)

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
                                  '$presentCount/$validLessonCount',
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
