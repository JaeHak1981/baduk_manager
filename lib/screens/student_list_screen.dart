import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/student_progress_model.dart';

import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/schedule_provider.dart';
import '../models/attendance_model.dart';
import '../utils/holiday_helper.dart';
import 'add_student_screen.dart';
import 'textbook_center_screen.dart';
import 'attendance_tab_screen.dart';
import 'batch_add_student_dialog.dart';
import 'student_history_screen.dart'; // 학생 히스토리 화면 import
import '../constants/ui_constants.dart';
import '../utils/excel_utils.dart';

/// 학생 목록 화면
class StudentListScreen extends StatefulWidget {
  final AcademyModel academy;

  const StudentListScreen({super.key, required this.academy});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  int? _selectedFilterSession; // null: 전체, 1~: 특정 부
  bool _isSelectionMode = false;
  final Set<String> _selectedStudentIds = {};

  // 중복 로딩 및 무한 루프 방지를 위한 플래그
  bool _isInitialLoading = false;
  String? _lastLoadedAcademyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 화면 전환 애니메이션이 완료될 때까지 잠시 대기 후 로드 (멈춤 현상 방지)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadData();
        }
      });
    });
  }

  void _loadData() {
    // 이미 로딩 중이거나 동일 기관 데이터를 로딩한 경우 중복 호출 차단
    if (_isInitialLoading && _lastLoadedAcademyId == widget.academy.id) return;

    _isInitialLoading = true;
    _lastLoadedAcademyId = widget.academy.id;

    final now = DateTime.now();
    final ownerId = widget.academy.ownerId;

    // [FIX] ownerId가 없는 경우 Permission Denied 발생 방지
    if (ownerId.isEmpty) {
      debugPrint(
        'Warning: StudentListScreen _loadData aborted: ownerId is empty',
      );
      if (mounted) setState(() => _isInitialLoading = false);
      return;
    }

    // 비동기 작업 통합 처리 및 로딩 상태 관리
    Future.wait([
          context.read<StudentProvider>().loadStudents(
            widget.academy.id,
            ownerId: widget.academy.ownerId,
          ),
          context.read<ProgressProvider>().loadAcademyProgress(
            widget.academy.id,
            ownerId: widget.academy.ownerId,
          ),
          context.read<AttendanceProvider>().loadMonthlyAttendance(
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            year: now.year,
            month: now.month,
            showLoading: false,
          ),
          context.read<ScheduleProvider>().loadSchedule(
            academyId: widget.academy.id,
            year: now.year,
            month: now.month,
          ),
        ])
        .then((_) {
          if (mounted) setState(() => _isInitialLoading = false);
        })
        .catchError((_) {
          if (mounted) setState(() => _isInitialLoading = false);
        });
  }

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedStudentIds.clear();
    });
  }

  List<StudentModel> _getFilteredStudents(List<StudentModel> allStudents) {
    final showDeletedOnly = context.read<StudentProvider>().showDeleted;

    // 1. 상태 필터링 (재원생 vs 퇴원생)
    if (showDeletedOnly) {
      // 퇴원생 모드일 때는 세션 필터를 무시하고 모든 퇴원생 노출
      return allStudents.where((s) => s.isDeleted == true).toList();
    }

    // 재원생 모드 (isDeleted == false)
    final activeStudents = allStudents
        .where((s) => s.isDeleted == false)
        .toList();

    // 2. 부(세션) 필터링
    if (_selectedFilterSession == null) return activeStudents;

    final now = DateTime.now().startOfDay;
    if (_selectedFilterSession == 0) {
      return activeStudents
          .where((s) => (s.getSessionAt(now) ?? 0) == 0)
          .toList();
    }
    return activeStudents
        .where((s) => s.getSessionAt(now) == _selectedFilterSession)
        .toList();
  }

  void _toggleSelectAll(List<StudentModel> filteredStudents) {
    setState(() {
      final allSelected =
          filteredStudents.isNotEmpty &&
          filteredStudents.every((s) => _selectedStudentIds.contains(s.id));

      if (allSelected) {
        // 현재 필터링된 학생들만 선택 해제
        for (var s in filteredStudents) {
          _selectedStudentIds.remove(s.id);
        }
      } else {
        // 현재 필터링된 학생들을 모두 추가
        _selectedStudentIds.addAll(filteredStudents.map((s) => s.id));
      }
    });
  }

  Future<void> _handleSyncData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 동기화'),
        content: const Text(
          '학생들의 현재 부 배정 정보와 이력 데이터를 대조하여 누락된 기록을 보정합니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('동기화 시작'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<StudentProvider>().syncHistoryData(
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      _loadData();
    }
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedStudentIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 일괄 삭제'),
        content: Text(
          '${_selectedStudentIds.length}명의 학생 정보를 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
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

    if (confirmed == true && mounted) {
      final provider = context.read<StudentProvider>();
      final success = await provider.batchProcessStudents(
        toDelete: _selectedStudentIds.toList(),
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
        isPermanent: provider.showDeleted,
      );
      if (mounted && success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('일괄 삭제되었습니다')));
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
      }
    }
  }

  /// 일괄 재등록 핸들러
  Future<void> _handleBulkReEnroll() async {
    if (_selectedStudentIds.isEmpty) return;

    DateTime startDate = DateTime.now();
    int? selectedSession;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('일괄 재등록 예약'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('선택한 학생들을 재등록하시겠습니까?'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('재등록 시작일'),
                subtitle: Text(
                  '${startDate.year}-${startDate.month}-${startDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => startDate = picked);
                  }
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '배정할 부 선택',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('미배정'),
                    selected: selectedSession == 0,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => selectedSession = 0);
                    },
                  ),
                  ...List.generate(
                    widget.academy.totalSessions,
                    (i) => i + 1,
                  ).map((s) {
                    return ChoiceChip(
                      label: Text('$s부'),
                      selected: selectedSession == s,
                      onSelected: (selected) {
                        if (selected) setDialogState(() => selectedSession = s);
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('일괄 재등록'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context
          .read<StudentProvider>()
          .bulkUpdateEnrollmentHistory(
            _selectedStudentIds.toList(),
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            startDate: startDate,
            sessionId: selectedSession,
          );
      if (mounted && success) {
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
      }
    }
  }

  /// 일괄 퇴원 예약 핸들러
  Future<void> _handleBulkRetire() async {
    if (_selectedStudentIds.isEmpty) return;

    DateTime endDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('일괄 퇴원 예약'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('선택한 ${_selectedStudentIds.length}명의 퇴원 날짜를 지정하시겠습니까?'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('퇴원 예정일'),
                subtitle: Text(
                  '${endDate.year}-${endDate.month}-${endDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => endDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('일괄 퇴원 예약'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context
          .read<StudentProvider>()
          .bulkUpdateEnrollmentHistory(
            _selectedStudentIds.toList(),
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            endDate: endDate,
          );
      if (mounted && success) {
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
      }
    }
  }

  /// 일괄 수강 시작일 변경 핸들러
  Future<void> _handleBulkEnrollDateUpdate() async {
    if (_selectedStudentIds.isEmpty) return;

    DateTime startDate = DateTime.now();
    bool replaceAll = false; // [NEW] 체크박스 상태 변수

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('수강 시작일 일괄 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('선택한 ${_selectedStudentIds.length}명의 수강 시작일을 일괄 변경하시겠습니까?'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('변경된 수강 시작일'),
                subtitle: Text(
                  '${startDate.year}-${startDate.month}-${startDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => startDate = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              // [NEW] 최초 입학일 정정 체크박스
              CheckboxListTile(
                value: replaceAll,
                onChanged: (val) =>
                    setDialogState(() => replaceAll = val ?? false),
                title: const Text('최초 입학일로 정정', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  '이전 달의 모든 수강 기록을 삭제합니다.',
                  style: TextStyle(fontSize: 11),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              const SizedBox(height: 8),
              const Text(
                '※ 변경 시점부터 과거 출석부에서 해당 학생이 자동으로 제외됩니다.',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('변경 적용'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context
          .read<StudentProvider>()
          .bulkUpdateEnrollmentHistory(
            _selectedStudentIds.toList(),
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            startDate: startDate,
            replaceAll: replaceAll, // [NEW] 플래그 전달
          );
      if (mounted && success) {
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedStudentIds.length}명 선택됨')
            : Text('${widget.academy.name} 학생 명단'),
        backgroundColor: _isSelectionMode
            ? Colors.red.shade50
            : Theme.of(context).colorScheme.inversePrimary,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add), // 리스트 추가 아이콘
            tooltip: '학생 일괄 등록 (복사&붙여넣기)',
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => BatchAddStudentDialog(
                  academyId: widget.academy.id,
                  ownerId: widget.academy.ownerId,
                ),
              );

              if (result == true && mounted) {
                _loadData(); // 목록 새로고침
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('학생 일괄 등록이 완료되었습니다')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined), // 내보내기 아이콘
            tooltip: '학생 명단 내보내기',
            onPressed: _showExportOptionsDialog,
          ),
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.check_box_outlined),
              tooltip: '다중 선택',
              onPressed: _toggleSelectionMode,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'sync') _handleSyncData();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 20),
                      SizedBox(width: 8),
                      Text('데이터 동기화'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_isSelectionMode) ...[
            Consumer<StudentProvider>(
              builder: (context, provider, _) {
                // 현재 필터링된 학생들 기준 전체 선택
                final filteredStudents = _getFilteredStudents(
                  provider.students,
                );

                return Row(
                  children: [
                    // 이동 버튼
                    IconButton(
                      icon: const Icon(Icons.drive_file_move_outline),
                      tooltip: '선택한 학생 이동',
                      onPressed: _handleBulkMove,
                    ),
                    // 수강 시작일 변경 버튼 추가
                    IconButton(
                      icon: const Icon(Icons.event_available),
                      tooltip: '일괄 수강 시작일 변경',
                      onPressed: _handleBulkEnrollDateUpdate,
                    ),
                    // 재등록 버튼
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      tooltip: '일괄 재등록 예약',
                      onPressed: _handleBulkReEnroll,
                    ),
                    // 퇴원 예약 버튼
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined),
                      tooltip: '일괄 퇴원 예약',
                      onPressed: _handleBulkRetire,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: '선택한 학생 삭제',
                      onPressed: _handleBulkDelete,
                    ),
                    TextButton(
                      onPressed: () => _toggleSelectAll(filteredStudents),
                      child: Text(
                        _selectedStudentIds.isNotEmpty &&
                                filteredStudents.every(
                                  (s) => _selectedStudentIds.contains(s.id),
                                )
                            ? '선택 해제'
                            : '전체 선택',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
      body: Consumer2<StudentProvider, ProgressProvider>(
        builder: (context, studentProvider, progressProvider, child) {
          if (studentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (studentProvider.errorMessage != null) {
            return _buildErrorState(studentProvider.errorMessage!);
          }

          // [FIX] ProgressProvider 에러가 있어도 목록은 유지하고 스낵바로 표시하기 위해
          // 여기서의 에러 체크는 student 데이터 로드 에러에만 집중합니다.

          if (studentProvider.students.isEmpty) {
            return _buildEmptyState();
          }

          // 부 필터링 적용
          final filteredStudents = _getFilteredStudents(
            studentProvider.students,
          );

          return Column(
            children: [
              if (widget.academy.totalSessions > 1) _buildSessionFilter(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 웹 버전에서 무한 높이 에러(Unbounded height) 방지를 위한 절대 높이 계산
                    final double screenHeight = MediaQuery.sizeOf(
                      context,
                    ).height;
                    final double effectiveHeight =
                        constraints.maxHeight.isInfinite
                        ? (screenHeight - 150).clamp(300.0, 5000.0)
                        : constraints.maxHeight;

                    final isWide = constraints.maxWidth > 800;

                    return SizedBox(
                      height: effectiveHeight,
                      child: Column(
                        children: [
                          // 1. 고정 헤더 (Sticky Header)
                          _buildStickyHeader(isWide),
                          // 2. 스크롤 영역
                          Expanded(
                            child: filteredStudents.isEmpty
                                ? Center(
                                    child: Text(
                                      _selectedFilterSession == 0
                                          ? '부 배정 안 된 학생이 없습니다'
                                          : '$_selectedFilterSession부에 등록된 학생이 없습니다',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () async => _loadData(),
                                    child: isWide
                                        ? _buildTwoColumnListView(
                                            filteredStudents,
                                          )
                                        : _buildSingleColumnListView(
                                            filteredStudents,
                                          ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddStudent(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildStickyHeader(bool isWide) {
    // 미배정 필터가 선택되었거나 퇴원생 모드일 때 출석 숨김
    final hideAttendance =
        _selectedFilterSession == 0 ||
        context.read<StudentProvider>().showDeleted;

    // 특정 부(1부, 2부 등) 필터 시 예약 현황 숨김
    final hideReservation =
        _selectedFilterSession != null && _selectedFilterSession! > 0;

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildListHeader(
                hideAttendance: hideAttendance,
                hideReservation: hideReservation,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildListHeader(
                hideAttendance: hideAttendance,
                hideReservation: hideReservation,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildListHeader(
        hideAttendance: hideAttendance,
        hideReservation: hideReservation,
      ),
    );
  }

  Widget _buildListHeader({
    bool hideAttendance = false,
    bool hideReservation = false,
  }) {
    const textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 600;
        final bool isVerySmall = constraints.maxWidth < 450;

        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 35,
                child: Center(child: Text('번호', style: textStyle)),
              ),
              if (!isVerySmall)
                const Expanded(
                  flex: 2,
                  child: Center(child: Text('부', style: textStyle)),
                ),
              const Expanded(flex: 3, child: Text('성명', style: textStyle)),
              if (!isSmall) ...[
                const Expanded(flex: 2, child: Text('학년', style: textStyle)),
                const Expanded(flex: 2, child: Text('급수', style: textStyle)),
              ],
              if (!hideReservation && !isVerySmall)
                const Expanded(flex: 4, child: Text('예약 현황', style: textStyle)),
              const Expanded(
                flex: 6,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('진도 현황', style: textStyle),
                ),
              ),
              if (!hideAttendance && !isSmall)
                const Expanded(flex: 2, child: Text('출석', style: textStyle)),
              SizedBox(
                width: isVerySmall ? 80 : 130,
                child: const Text(
                  '관리',
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTwoColumnListView(List<StudentModel> filteredStudents) {
    final halfLength = (filteredStudents.length / 2).ceil();
    final totalLessonDays = _calculateTotalLessonDays();
    final hideAttendance =
        _selectedFilterSession == 0 ||
        context.read<StudentProvider>().showDeleted;
    final hideReservation =
        _selectedFilterSession != null && _selectedFilterSession! > 0;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppDimensions.getBottomInset(context) + 40,
      ),
      itemCount: halfLength,
      itemBuilder: (context, index) {
        final leftIndex = index;
        final rightIndex = index + halfLength;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StudentProgressCard(
                index: leftIndex + 1,
                student: filteredStudents[leftIndex],
                academy: widget.academy,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedStudentIds.contains(
                  filteredStudents[leftIndex].id,
                ),
                onToggleSelection: () =>
                    _toggleStudentSelection(filteredStudents[leftIndex].id),
                totalLessonDays: totalLessonDays,
                hideAttendance: hideAttendance,
                hideReservation: hideReservation,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: rightIndex < filteredStudents.length
                  ? _StudentProgressCard(
                      index: rightIndex + 1,
                      student: filteredStudents[rightIndex],
                      academy: widget.academy,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedStudentIds.contains(
                        filteredStudents[rightIndex].id,
                      ),
                      onToggleSelection: () => _toggleStudentSelection(
                        filteredStudents[rightIndex].id,
                      ),
                      totalLessonDays: totalLessonDays,
                      hideAttendance: hideAttendance,
                      hideReservation: hideReservation,
                    )
                  : const SizedBox(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleColumnListView(List<StudentModel> filteredStudents) {
    final totalLessonDays = _calculateTotalLessonDays();
    final hideAttendance =
        _selectedFilterSession == 0 ||
        context.read<StudentProvider>().showDeleted;
    final hideReservation =
        _selectedFilterSession != null && _selectedFilterSession! > 0;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppDimensions.getBottomInset(context) + 40,
      ),
      itemCount: filteredStudents.length,
      itemBuilder: (context, index) {
        final student = filteredStudents[index];
        return _StudentProgressCard(
          index: index + 1,
          student: student,
          academy: widget.academy,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedStudentIds.contains(student.id),
          onToggleSelection: () => _toggleStudentSelection(student.id),
          totalLessonDays: totalLessonDays,
          hideAttendance: hideAttendance,
          hideReservation: hideReservation,
        );
      },
    );
  }

  Widget _buildSessionFilter() {
    final studentProvider = context.watch<StudentProvider>();
    final showDeletedOnly = studentProvider.showDeleted;
    final allStudents = studentProvider.allStudents;
    final activeStudents = allStudents.where((s) => !s.isDeleted).toList();
    final deletedStudents = allStudents.where((s) => s.isDeleted).toList();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 1. 퇴원 / 수강종료 전환 버튼 (가장 앞에 배치하여 상태 명확화)
                InputChip(
                  label: Text(
                    showDeletedOnly
                        ? '재원생 명단 보기'
                        : '퇴원 / 수강종료 (${deletedStudents.length}명)',
                  ),
                  selected: showDeletedOnly,
                  onSelected: (selected) {
                    studentProvider.toggleShowDeleted();
                    // 전환 시 선택 상태 초기화 (안전을 위해)
                    setState(() {
                      _selectedStudentIds.clear();
                      _isSelectionMode = false;
                    });
                    _loadData();
                  },
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red,
                  labelStyle: TextStyle(
                    color: showDeletedOnly ? Colors.red.shade900 : null,
                    fontWeight: showDeletedOnly ? FontWeight.bold : null,
                  ),
                ),
                const SizedBox(width: 12),
                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                const SizedBox(width: 12),

                // 2. 재원생 모드일 때만 세부 필터 노출
                if (!showDeletedOnly) ...[
                  ChoiceChip(
                    label: Text('전체 (${activeStudents.length}명)'),
                    selected: _selectedFilterSession == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilterSession = null;
                          _selectedStudentIds.clear();
                          _isSelectionMode = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      '미등록 (${activeStudents.where((s) => (s.getSessionAt(DateTime.now().startOfDay) ?? 0) == 0).length}명)',
                    ),
                    selected: _selectedFilterSession == 0,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilterSession = 0;
                          _selectedStudentIds.clear();
                          _isSelectionMode = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(
                    widget.academy.totalSessions,
                    (i) => i + 1,
                  ).map((s) {
                    final count = activeStudents
                        .where(
                          (st) =>
                              (st.getSessionAt(DateTime.now().startOfDay) ??
                                  0) ==
                              s,
                        )
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$s부 ($count명)'),
                        selected: _selectedFilterSession == s,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedFilterSession = s;
                              _selectedStudentIds.clear();
                              _isSelectionMode = false;
                            });
                          }
                        },
                      ),
                    );
                  }),
                ] else ...[
                  // 퇴원생 모드일 때는 안내 텍스트 또는 단순 현황 표시
                  Center(
                    child: Text(
                      '퇴원 / 수강종료 학생 목록 (${deletedStudents.length}명)',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const VerticalDivider(width: 1, indent: 10, endIndent: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceTabScreen(
                          academy: widget.academy,
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 18,
                  ),
                  label: const Text('출석 관리', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: Colors.blue.shade700,
                    side: BorderSide(color: Colors.blue.shade300),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('에러 메시지가 복사되었습니다')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('복사'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBulkMove() async {
    if (_selectedStudentIds.isEmpty) return;

    final targetSession = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('학생 부 이동'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('선택한 ${_selectedStudentIds.length}명의 학생을 어느 부로 이동하시겠습니까?'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('미배정'),
                    selected: false,
                    onSelected: (_) => Navigator.pop(context, 0),
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
        );
      },
    );

    if (targetSession != null && mounted) {
      final success = await context.read<StudentProvider>().moveStudents(
        _selectedStudentIds.toList(),
        targetSession,
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedStudentIds.length}명이 $targetSession부로 이동되었습니다',
            ),
          ),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedStudentIds.clear();
        });
      }
    }
  }

  void _handleExport() async {
    final provider = context.read<StudentProvider>();
    final students = _getFilteredStudents(provider.students);

    if (students.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내보낼 학생 데이터가 없습니다')));
      return;
    }

    // 1. 컬럼 선택 다이얼로그 표시
    final Map<String, bool>? selectedColumns =
        await showDialog<Map<String, bool>>(
          context: context,
          builder: (context) {
            // 초기값: 모두 선택
            Map<String, bool> columns = {
              '이름': true,
              '학년': true,
              '반': true,
              '번호': true,
              '보호자 연락처': true,
              '현재 급수': true,
              '부': true,
              '메모': true,
            };

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('내보내기 항목 선택'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: columns.keys.map((key) {
                        return CheckboxListTile(
                          title: Text(key),
                          value: columns[key],
                          onChanged: (val) {
                            setState(() {
                              columns[key] = val ?? false;
                            });
                          },
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, columns),
                      child: const Text('텍스트 생성'),
                    ),
                  ],
                );
              },
            );
          },
        );
    if (selectedColumns == null || selectedColumns.isEmpty) return; // 취소됨

    // 2. 텍스트 생성
    final buffer = StringBuffer();

    // 헤더 생성
    final headers = selectedColumns.keys
        .where((k) => selectedColumns[k]!)
        .toList();
    buffer.writeln(headers.join('\t'));

    // 데이터 생성
    for (var s in students) {
      final List<String> row = [];
      if (selectedColumns['이름']!) row.add(s.name);
      if (selectedColumns['학년']!) row.add(s.grade?.toString() ?? "");
      if (selectedColumns['반']!) row.add(s.classNumber ?? "");
      if (selectedColumns['번호']!) row.add(s.studentNumber ?? "");
      if (selectedColumns['보호자 연락처']!) row.add(s.parentPhone ?? "");
      if (selectedColumns['현재 급수']!) row.add(s.levelDisplayName);
      if (selectedColumns['부']!) row.add(s.session?.toString() ?? "");
      if (selectedColumns['메모']!) row.add(s.note ?? "");

      buffer.writeln(row.join('\t'));
    }

    if (!mounted) return;

    // 3. 결과 다이얼로그 표시
    _showExportResultDialog(buffer.toString());
  }

  void _showExportOptionsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.file_download_outlined,
                  color: Colors.green,
                ),
                title: const Text('일괄 수정용 엑셀 다운로드 (ID 포함)'),
                subtitle: const Text('학년, 반, 번호 등을 한 번에 수정할 때 사용하세요.'),
                onTap: () {
                  Navigator.pop(context);
                  final students = context.read<StudentProvider>().students;
                  final progressProvider = context.read<ProgressProvider>();

                  // 학생별 가장 최근 진도 정보를 Map으로 구성
                  final Map<String, StudentProgressModel?> progressMap = {
                    for (var s in students)
                      s.id:
                          progressProvider
                              .getProgressForStudent(s.id)
                              .isNotEmpty
                          ? progressProvider.getProgressForStudent(s.id).first
                          : null,
                  };

                  ExcelUtils.exportStudentListForUpdate(
                    students: students,
                    academyName: widget.academy.name,
                    studentProgressMap: progressMap,
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.copy_all),
                title: const Text('전체 복사 (표 형식)'),
                onTap: () {
                  Navigator.pop(context);
                  _handleExport();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportResultDialog(String exportText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 명단 내보내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('아래 텍스트를 복사하여 엑셀에 붙여넣으세요.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              height: 200,
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  exportText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: exportText));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다')));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('복사하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('등록된 학생이 없습니다'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddStudent(context),
            icon: const Icon(Icons.person_add),
            label: const Text('학생 등록하기'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddStudent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(academy: widget.academy),
      ),
    ).then((_) => _loadData());
  }

  int _calculateTotalLessonDays() {
    final now = DateTime.now();
    final scheduleProvider = context.read<ScheduleProvider>();
    int totalLessonDaysCount = 0;
    final targetDay = now.day;

    for (int day = 1; day <= targetDay; day++) {
      final date = DateTime(now.year, now.month, day);
      if (widget.academy.lessonDays.contains(date.weekday) &&
          !HolidayHelper.isHoliday(date) &&
          !scheduleProvider.isDateHoliday(date)) {
        totalLessonDaysCount++;
      }
    }
    return totalLessonDaysCount;
  }
}

/// 개별 학생 카드 (진도 정보 포함)
class _StudentProgressCard extends StatefulWidget {
  final int index;
  final StudentModel student;
  final AcademyModel academy;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final int totalLessonDays;
  final bool hideAttendance;
  final bool hideReservation;

  const _StudentProgressCard({
    required this.index,
    required this.student,
    required this.academy,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onToggleSelection,
    required this.totalLessonDays,
    this.hideAttendance = false,
    this.hideReservation = false,
  });

  @override
  State<_StudentProgressCard> createState() => _StudentProgressCardState();
}

class _StudentProgressCardState extends State<_StudentProgressCard> {
  void _navigateToStudentHistory(BuildContext context, StudentModel student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentHistoryScreen(
          student: student,
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = context.watch<ProgressProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    // 메인 화면에서는 완료되지 않은(진행 중인) 교재만 표시
    final progressList = progressProvider
        .getProgressForStudent(widget.student.id)
        .where((p) => !p.isCompleted)
        .toList();

    // 예약 정보 분석
    final reservationDetail = widget.student.reservationDetail;
    final hasReservation =
        reservationDetail != '수강 중' && reservationDetail != '미배정';
    final isRetirement = hasReservation && reservationDetail.contains('퇴원');

    // 배경색 결정
    Color backgroundColor;
    if (widget.isSelected) {
      backgroundColor = Colors.blue.shade50;
    } else if (hasReservation) {
      // 퇴원 예약: 연한 빨강, 부 이동 등: 연한 노랑
      backgroundColor = isRetirement
          ? Colors.red.shade50
          : Colors.amber.shade50;
    } else {
      backgroundColor = Colors.white;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall = constraints.maxWidth < 600;
        final bool isVerySmall = constraints.maxWidth < 450;

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: InkWell(
            onTap: () {
              if (widget.isSelectionMode) {
                widget.onToggleSelection();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddStudentScreen(
                      academy: widget.academy,
                      student: widget.student,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // 0. 선택/번호 영역 (35)
                  SizedBox(
                    width: 35,
                    child: widget.isSelectionMode
                        ? Checkbox(
                            value: widget.isSelected,
                            onChanged: (_) => widget.onToggleSelection(),
                          )
                        : Text(
                            '${widget.index}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),

                  // 1. [부] 영역
                  if (!isVerySmall)
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: () {
                          final currentSessionId = widget.student.getSessionAt(
                            DateTime.now(),
                          );
                          return currentSessionId != null &&
                                  currentSessionId != 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    '$currentSessionId부',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: const Text(
                                    '미배정',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                        }(),
                      ),
                    ),

                  // 2. [이름] 영역
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.student.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.student.enrollmentHistory.isNotEmpty &&
                                widget.student.enrollmentHistory.first.startDate
                                    .isAfter(DateTime.now())) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Text(
                                  '입학 예정: ${widget.student.enrollmentHistory.first.startDate.month}/${widget.student.enrollmentHistory.first.startDate.day}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if ((widget.hideReservation || isVerySmall) &&
                            hasReservation)
                          Text(
                            isRetirement ? '[퇴원]' : '[$reservationDetail]',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.normal,
                              color: isRetirement
                                  ? Colors.red.shade700
                                  : Colors.amber.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // 3. [학년/급수] 영역 - 작은 화면에서 숨김
                  if (!isSmall) ...[
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.student.grade != null
                            ? '${widget.student.grade}학년'
                            : '-',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        widget.student.levelDisplayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.student.level == 0
                              ? Colors.grey
                              : Colors.blue.shade800,
                          fontWeight: widget.student.level == 0
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  // 3.5. [예약 현황] 영역 - 매우 작은 화면에서 숨김
                  if (!widget.hideReservation && !isVerySmall)
                    Expanded(
                      flex: 4,
                      child: () {
                        final detail = widget.student.reservationDetail;
                        if (detail == '수강 중' || detail == '미배정') {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Text(
                            detail,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }(),
                    ),

                  // 4. [진도현황] 영역
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: progressList.isNotEmpty
                          ? Text(
                              isSmall
                                  ? '${progressList.first.textbookName.substring(0, (progressList.first.textbookName.length > 4 ? 4 : progressList.first.textbookName.length))}.. ${progressList.first.progressPercentage.toInt()}%'
                                  : '${progressList.first.textbookName} ${progressList.first.volumeNumber}권 (${progressList.first.progressPercentage.toInt()}%)',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            )
                          : const Text(
                              '-',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),

                  // 5. [출석율] 영역 - 작은 화면에서 숨김
                  if (!widget.hideAttendance && !isSmall)
                    Expanded(
                      flex: 2,
                      child: Builder(
                        builder: (context) {
                          final monthlyRecords = attendanceProvider
                              .getRecordsForStudent(widget.student.id);
                          if (widget.totalLessonDays == 0) {
                            return const Center(
                              child: Text(
                                '-%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          final now = DateTime.now();
                          final presentCount = monthlyRecords.where((r) {
                            return r.timestamp.year == now.year &&
                                r.timestamp.month == now.month &&
                                (r.type == AttendanceType.present ||
                                    r.type == AttendanceType.late);
                          }).length;

                          final rate =
                              (presentCount / widget.totalLessonDays * 100)
                                  .toInt();

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '출석',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '$rate%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: rate >= 90
                                      ? Colors.blue.shade700
                                      : (rate >= 70
                                            ? Colors.orange.shade700
                                            : Colors.red.shade700),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  // 6. [관리버튼] 영역
                  SizedBox(
                    width: isVerySmall ? 80 : 130,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isVerySmall)
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 20),
                            onPressed: () => _navigateToStudentHistory(
                              context,
                              widget.student,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: '학습정보',
                          )
                        else
                          TextButton(
                            onPressed: () => _navigateToStudentHistory(
                              context,
                              widget.student,
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '학습',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        if (isVerySmall)
                          IconButton(
                            icon: const Icon(
                              Icons.menu_book_outlined,
                              size: 20,
                            ),
                            onPressed: () => _navigateToAssignTextbook(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: '교재할당',
                          )
                        else
                          TextButton(
                            onPressed: () => _navigateToAssignTextbook(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '교재',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        if (widget.student.isDeleted) ...[
                          if (isVerySmall)
                            IconButton(
                              icon: const Icon(
                                Icons.restore,
                                size: 20,
                                color: Colors.green,
                              ),
                              onPressed: () => _handleRestore(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: '복구',
                            )
                          else
                            TextButton(
                              onPressed: () => _handleRestore(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: Colors.green,
                              ),
                              child: const Text(
                                '복구',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRestore(BuildContext context) async {
    DateTime startDate = DateTime.now();
    int? selectedSession;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('재원생 재등록'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('[${widget.student.name}] 학생을 재원생 목록으로 다시 등록하시겠습니까?'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('재등록 시작일'),
                subtitle: Text(
                  '${startDate.year}-${startDate.month}-${startDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => startDate = picked);
                  }
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '배정할 부 선택',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('미배정'),
                    selected: selectedSession == 0,
                    onSelected: (selected) {
                      if (selected) {
                        setDialogState(() => selectedSession = 0);
                      }
                    },
                  ),
                  ...List.generate(
                    widget.academy.totalSessions,
                    (i) => i + 1,
                  ).map((s) {
                    return ChoiceChip(
                      label: Text('$s부'),
                      selected: selectedSession == s,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedSession = s);
                        }
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('재등록'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      if (!mounted) return;
      final provider = context.read<StudentProvider>();
      await provider.reEnrollStudent(
        widget.student.id,
        academyId: widget.student.academyId,
        ownerId: widget.student.ownerId,
        startDate: startDate,
        sessionId: selectedSession,
      );
    }
  }

  void _navigateToAssignTextbook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextbookCenterScreen(
          academy: widget.academy,
          studentId: widget.student.id,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      // TextbookCenterScreen에서 이미 assignVolume을 통해 Provider 상태를 갱신하고
      // notifyListeners()를 호출했으므로, 자동으로 반영됩니다.
    });
  }
}
