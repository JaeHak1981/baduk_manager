import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../utils/holiday_helper.dart';
import '../config/app_theme.dart';
import 'components/attendance_calendar.dart';
import 'components/attendance_session_filter.dart';
import 'components/attendance_table.dart';

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
  bool _isExtraLessonMode = false; // 보강 수업 모드 (수업 없는 날 강제 활성화)

  final Set<String> selectedStudentIds = {};
  bool isSelectionMode = false;

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

  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedStudentIds.clear();
      }
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
    });
    widget.onSelectionModeChanged?.call();
  }

  void clearSelection() {
    setState(() {
      selectedStudentIds.clear();
    });
    widget.onSelectionModeChanged?.call();
  }

  List<StudentModel> getFilteredStudents(List<StudentModel> allStudents) {
    // 1. 퇴원생(isDeleted)은 무조건 제외
    final activeStudents = allStudents.where((s) => !s.isDeleted).toList();

    // 2. 미배정 학생(session == null 또는 0) 제외
    final assignedStudents = activeStudents.where((s) {
      return s.session != null && s.session != 0;
    }).toList();

    // 3. 특정 부 선택 필터링
    if (_selectedSession == null) return assignedStudents;
    return assignedStudents
        .where((s) => s.session == _selectedSession)
        .toList();
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
                  onSelected: (s) => Navigator.pop(context, 0),
                ),
                ...List.generate(
                  widget.academy.totalSessions,
                  (i) => i + 1,
                ).map((s) {
                  return ChoiceChip(
                    label: Text('$s부'),
                    selected: false,
                    onSelected: (_) => Navigator.pop(context, s),
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
    final success = await provider.batchProcessStudents(
      toDelete: selectedStudentIds.toList(),
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
  Widget build(BuildContext context) {
    super.build(context);
    final ownerId = context.read<AuthProvider>().currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 달력 영역 (왼쪽 사이드바)
          AttendanceCalendar(
            selectedDate: _selectedDate,
            focusedDay: _focusedDay,
            academyId: widget.academy.id,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                final oldMonth = _selectedDate.month;
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
                _isExtraLessonMode = false; // 날짜 변경 시 보강 모드 초기화
                if (oldMonth != _selectedDate.month) {
                  _loadData();
                }
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                _loadData();
              });
            },
          ),

          // 2. 메인 컨텐츠 영역 (부 필터 + 출결 테이블)
          Expanded(
            child: Column(
              children: [
                // 상단 필터 및 버튼 바
                Consumer2<StudentProvider, AttendanceProvider>(
                  builder: (context, studentProvider, attendanceProvider, _) {
                    return AttendanceSessionFilter(
                      totalSessions: widget.academy.totalSessions,
                      selectedSession: _selectedSession,
                      students: studentProvider.students,
                      onSessionSelected: (session) => setState(() {
                        // 필터 초기화: 이미 선택된 부를 다시 누르면 전체보기(null)로 전환
                        if (_selectedSession == session) {
                          _selectedSession = null;
                        } else {
                          _selectedSession = session;
                        }
                      }),
                      hasPendingChanges: attendanceProvider.hasPendingChanges,
                      onSave: () async {
                        final success = await attendanceProvider
                            .savePendingChanges();
                        if (success && mounted) {
                          // 필요 시 추가 작업
                        }
                      },
                    );
                  },
                ),

                const Divider(height: 1),

                // 출결 테이블 영역
                Expanded(
                  child: Consumer2<StudentProvider, AttendanceProvider>(
                    builder: (context, studentProvider, attendanceProvider, _) {
                      if (studentProvider.isLoading ||
                          attendanceProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final filteredStudents = getFilteredStudents(
                        studentProvider.students,
                      );

                      // 오늘 날짜의 출결 데이터만 필터링
                      final attendanceMap = <String, AttendanceRecord>{};
                      for (var r in attendanceProvider.monthlyRecords) {
                        if (r.timestamp.year == _selectedDate.year &&
                            r.timestamp.month == _selectedDate.month &&
                            r.timestamp.day == _selectedDate.day) {
                          attendanceMap[r.studentId] = r;
                        }
                      }

                      final holidayName = HolidayHelper.getHolidayName(
                        _selectedDate,
                      );
                      final isAcademyHoliday = context
                          .watch<ScheduleProvider>()
                          .isDateHoliday(_selectedDate);
                      final isLessonDay = widget.academy.lessonDays.contains(
                        _selectedDate.weekday,
                      );

                      // 수업이 없는 날이거나 휴일인 경우 (보강 모드가 아닐 때만 차단)
                      if ((!isLessonDay ||
                              holidayName != null ||
                              isAcademyHoliday) &&
                          !_isExtraLessonMode) {
                        return _buildNoLessonView(
                          holidayName: holidayName,
                          isAcademyHoliday: isAcademyHoliday,
                          isLessonDay: isLessonDay,
                        );
                      }

                      return AttendanceTable(
                        students: filteredStudents,
                        attendanceProvider: attendanceProvider,
                        attendanceMap: attendanceMap,
                        selectedDate: _selectedDate,
                        ownerId: ownerId,
                        isSelectionMode: isSelectionMode,
                        selectedStudentIds: selectedStudentIds,
                        onStudentSelected: toggleSelection,
                        academyId: widget.academy.id,
                        lessonDays: widget.academy.lessonDays,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLessonView({
    String? holidayName,
    bool isAcademyHoliday = false,
    bool isLessonDay = true,
  }) {
    String mainMessage = '';
    String subMessage = '출석 처리가 필요하지 않은 날입니다.';

    // 정기 수업 요일 이름 매핑
    final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final lessonDayNames = widget.academy.lessonDays.isEmpty
        ? '미지정'
        : widget.academy.lessonDays.map((d) => weekdayNames[d - 1]).join(', ');

    if (holidayName != null) {
      mainMessage =
          '${_selectedDate.month}월 ${_selectedDate.day}일은 $holidayName입니다.';
    } else if (isAcademyHoliday) {
      mainMessage = '${_selectedDate.month}월 ${_selectedDate.day}일은 학원 휴강일입니다.';
    } else if (!isLessonDay) {
      mainMessage = '오늘은 정기 수업이 없는 날입니다.';
      subMessage = '${widget.academy.name}은(는) $lessonDayNames요일 수업일입니다.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            !isLessonDay ? Icons.calendar_today_outlined : Icons.event_busy,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            mainMessage,
            style: AppTheme.heading1.copyWith(color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: AppTheme.bodyText.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          // 보강 수업 입력 버튼
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isExtraLessonMode = true;
              });
            },
            icon: const Icon(Icons.add_task),
            label: const Text('보강 수업 기록하기'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: Colors.blue.shade300),
              foregroundColor: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '특별한 수업이 있는 경우 버튼을 눌러 출결을 입력할 수 있습니다.',
            style: AppTheme.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
