import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/student_progress_model.dart';

import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import 'add_student_screen.dart';
import 'textbook_center_screen.dart';
import 'attendance_tab_screen.dart';
import 'batch_add_student_dialog.dart';
import 'student_history_screen.dart'; // 학생 히스토리 화면 import
import '../constants/ui_constants.dart';
import '../utils/excel_utils.dart'; // [ADDED]

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<StudentProvider>().loadStudents(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
      includeDeleted: true, // 항상 전체(퇴원생 포함) 로드하여 카운트 정확히 표시
    );
    // [Bulk Load] 전체 진도 한 번에 로드
    context.read<ProgressProvider>().loadAcademyProgress(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );
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
    if (_selectedFilterSession == 0) {
      return activeStudents
          .where((s) => s.session == null || s.session == 0)
          .toList();
    }
    return activeStudents
        .where((s) => s.session == _selectedFilterSession)
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
      final success = await context.read<StudentProvider>().deleteStudents(
        _selectedStudentIds.toList(),
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('학생 일괄 등록이 완료되었습니다')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined), // 내보내기 아이콘
            tooltip: '학생 명단 내보내기',
            onPressed: _showExportOptionsDialog,
          ),
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.check_box_outlined),
              tooltip: '다중 선택',
              onPressed: _toggleSelectionMode,
            ),
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
                child: filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilterSession == 0
                              ? '부 배정 안 된 학생이 없습니다'
                              : '${_selectedFilterSession}부에 등록된 학생이 없습니다',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          _loadData();
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            AppDimensions.getBottomInset(context),
                          ),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            // 해당 학생의 진도 정보 가져오기 시도 (FutureBuilder 대신 일단 Map에서 가져오는 방식 혹은 각 아이템에서 로드)
                            return _StudentProgressCard(
                              index: index + 1, // 순번 (1부터 시작)
                              student: student,
                              academy: widget.academy,
                              isSelectionMode: _isSelectionMode,
                              isSelected: _selectedStudentIds.contains(
                                student.id,
                              ),
                              onToggleSelection: () {
                                setState(() {
                                  if (_selectedStudentIds.contains(
                                    student.id,
                                  )) {
                                    _selectedStudentIds.remove(student.id);
                                  } else {
                                    _selectedStudentIds.add(student.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
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
                      if (selected)
                        setState(() => _selectedFilterSession = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      '미등록 (${activeStudents.where((s) => s.session == null || s.session == 0).length}명)',
                    ),
                    selected: _selectedFilterSession == 0,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilterSession = 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(
                    widget.academy.totalSessions,
                    (i) => i + 1,
                  ).map((s) {
                    final count = activeStudents
                        .where((st) => st.session == s)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$s부 ($count명)'),
                        selected: _selectedFilterSession == s,
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedFilterSession = s);
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
                  ExcelUtils.exportStudentListForUpdate(
                    students: context.read<StudentProvider>().students,
                    academyName: widget.academy.name,
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
}

/// 개별 학생 카드 (진도 정보 포함)
class _StudentProgressCard extends StatefulWidget {
  final int index;
  final StudentModel student;
  final AcademyModel academy;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _StudentProgressCard({
    required this.index,
    required this.student,
    required this.academy,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onToggleSelection,
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

  String _buildStudentSubtitle() {
    final s = widget.student;
    List<String> parts = [];

    if (s.grade != null && s.classNumber != null) {
      parts.add('${s.grade}-${s.classNumber}');
    } else if (s.grade != null) {
      parts.add('${s.grade}학년');
    }

    if (s.studentNumber != null && s.studentNumber!.isNotEmpty) {
      parts.add('${s.studentNumber}번');
    }
    if (s.parentPhone != null && s.parentPhone!.isNotEmpty) {
      parts.add(s.parentPhone!);
    }
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = context.watch<ProgressProvider>();
    // 메인 화면에서는 완료되지 않은(진행 중인) 교재만 표시
    final progressList = progressProvider
        .getProgressForStudent(widget.student.id)
        .where((p) => !p.isCompleted)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: widget.isSelected ? Colors.blue.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 1. 아바타 및 이름 영역 (클릭 시 학생 정보 수정으로 이동)
            Expanded(
              flex: 3,
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
                onLongPress: () {
                  if (!widget.isSelectionMode) {
                    widget.onToggleSelection();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    if (!widget.isSelectionMode) ...[
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${widget.index}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (widget.isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Checkbox(
                          side: BorderSide(
                            color: Colors.grey.shade600,
                            width: 1.5,
                          ),
                          value: widget.isSelected,
                          onChanged: (_) => widget.onToggleSelection(),
                        ),
                      ),
                    CircleAvatar(child: Text(widget.student.name[0])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (widget.student.session != null &&
                                  widget.student.session != 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.student.session}부',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    '미등록',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              Text(
                                widget.student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.student.isDeleted) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '퇴원',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _buildStudentSubtitle(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 2. 진도 목록 영역 (클릭 시 이동 안 함)
            if (progressList.isNotEmpty)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: progressList.map((progress) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${progress.textbookName} (${progress.volumeNumber}권)',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${progress.progressPercentage.toInt()}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    // 삭제/완료 버튼 터치 영역 확보
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _showProgressActionDialog(
                                          context,
                                          progress,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons
                                                .more_vert, // 아이콘 변경: 삭제 대신 옵션 메뉴
                                            size: 14,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progress.progressPercentage / 100,
                                    minHeight: 4,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress.isCompleted
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            // 3. 작업 버튼 영역
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      _navigateToStudentHistory(context, widget.student),
                  icon: const Icon(Icons.assignment_ind, size: 16),
                  label: const Text('정보', style: TextStyle(fontSize: 11)),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _navigateToAssignTextbook(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('교재 할당', style: TextStyle(fontSize: 11)),
                ),
                if (widget.student.isDeleted)
                  IconButton(
                    icon: const Icon(
                      Icons.restore_from_trash,
                      color: Colors.green,
                      size: 20,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('재원생 복구'),
                          content: Text(
                            '${widget.student.name} 학생을 다시 재원생 목록으로 복구하시겠습니까?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('복구'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await context.read<StudentProvider>().restoreStudent(
                          widget.student.id,
                          academyId: widget.student.academyId,
                          ownerId: widget.student.ownerId,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${widget.student.name} 학생이 복구되었습니다.',
                            ),
                          ),
                        );
                      }
                    },
                    tooltip: '재원생으로 복구',
                  ),
                if (!widget.student.isDeleted)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _showDeleteConfirmation(context),
                    tooltip: '수강 종료 처리',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
      // TextbookCenterScreen에서 이미 assignVolume을 통해 Provider 상태를 갱신하고
      // notifyListeners()를 호출했으므로, 여기서 다시 load할 필요가 없거나
      // 필요한 경우에만 전체 리프레시를 고려할 수 있습니다.
      // 현재는 Provider가 전역이므로 자동으로 반영됩니다.
    });
  }

  // Method removed: _navigateToEditProgress

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text(
          '[${widget.student.name}] 학생의 모든 정보를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
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
      final success = await context.read<StudentProvider>().deleteStudent(
        widget.student.id,
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      if (mounted && success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('학생이 삭제되었습니다')));
      }
    }
  }

  Future<void> _showProgressActionDialog(
    BuildContext context,
    StudentProgressModel progress,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${progress.textbookName} 관리'),
        content: const Text('수행할 작업을 선택하세요.'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmCompleteProgress(this.context, progress);
            },
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            label: const Text('학습 완료 (로그로 이전)'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteProgress(this.context, progress);
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('삭제 (휴지통으로 보관)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCompleteProgress(
    BuildContext context,
    StudentProgressModel progress,
  ) async {
    final success = await context.read<ProgressProvider>().updateVolumeStatus(
      progress.id,
      widget.student.id,
      true, // 완료 처리
      ownerId: widget.academy.ownerId,
    );
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('[${progress.textbookName}] 학습이 완료되어 로그로 이전되었습니다.'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteProgress(
    BuildContext context,
    StudentProgressModel progress,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('교재 할당 삭제'),
        content: Text(
          '[${progress.textbookName} ${progress.volumeNumber}권] 할당을 삭제하시겠습니까?\n이 데이터는 30일간 보관 후 자동 삭제됩니다.',
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
      debugPrint(
        '🚀🚀🚀 [_confirmDeleteProgress] User confirmed. Initializing delete...',
      );
      debugPrint('🚀🚀🚀 [target_progress_id]: ${progress.id}');
      debugPrint('🚀🚀🚀 [student_id]: ${widget.student.id}');

      try {
        final provider = context.read<ProgressProvider>();
        debugPrint(
          '🚀🚀🚀 [provider_instance]: ${provider.runtimeType} (Hash: ${provider.hashCode})',
        );

        final success = await provider.removeProgress(
          progress.id,
          widget.student.id,
          ownerId: widget.academy.ownerId,
        );

        debugPrint('🚀🚀🚀 [result_success]: $success');

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('교재 할당이 삭제되었습니다.')));
          } else {
            final error = provider.errorMessage;
            debugPrint('❌❌❌ [delete_failed_message]: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('삭제 실패: $error'),
                backgroundColor: Colors.red,
              ),
            );
            provider.clearErrorMessage();
          }
        }
      } catch (e, stack) {
        debugPrint('❌❌❌ [EXCEPTION_DURING_DELETE]: $e');
        debugPrint('❌❌❌ [STACK]: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('시스템 오류: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }
}
