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
    if (_selectedSession == null) return allStudents;
    return allStudents.where((s) {
      if (_selectedSession == 0) return s.session == null || s.session == 0;
      return s.session == _selectedSession;
    }).toList();
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
                      onSessionSelected: (session) =>
                          setState(() => _selectedSession = session),
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

                      if (holidayName != null || isAcademyHoliday) {
                        return _buildHolidayView(holidayName);
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

  Widget _buildHolidayView(String? holidayName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            holidayName != null
                ? '${_selectedDate.month}월 ${_selectedDate.day}일은 $holidayName입니다.'
                : '${_selectedDate.month}월 ${_selectedDate.day}일은 학원 휴강일입니다.',
            style: AppTheme.heading1,
          ),
          const SizedBox(height: 8),
          const Text('출석 처리가 필요하지 않습니다.', style: AppTheme.bodyText),
        ],
      ),
    );
  }
}
