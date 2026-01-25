import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';

import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import 'add_student_screen.dart';
import 'textbook_center_screen.dart';
// import 'progress_edit_screen.dart'; // Removed
import 'batch_add_student_dialog.dart';
import 'student_history_screen.dart'; // 학생 히스토리 화면 import

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
    );
    // [Bulk Load] 전체 진도 한 번에 로드
    context.read<ProgressProvider>().loadAcademyProgress(widget.academy.id);
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedStudentIds.clear();
    });
  }

  void _toggleSelectAll(List<StudentModel> students) {
    setState(() {
      if (_selectedStudentIds.length == students.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds.addAll(students.map((s) => s.id));
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
            onPressed: _handleExport,
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
                final filteredStudents = _selectedFilterSession == null
                    ? provider.students
                    : provider.students
                          .where((s) => s.session == _selectedFilterSession)
                          .toList();

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
                        _selectedStudentIds.length == filteredStudents.length
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

          if (studentProvider.students.isEmpty) {
            return _buildEmptyState();
          }

          // 부 필터링 적용
          final filteredStudents = _selectedFilterSession == null
              ? studentProvider.students
              : _selectedFilterSession == 0
              ? studentProvider.students
                    .where((s) => s.session == null || s.session == 0)
                    .toList()
              : studentProvider.students
                    .where((s) => s.session == _selectedFilterSession)
                    .toList();

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
                          padding: const EdgeInsets.all(16),
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
    final allStudents = context.watch<StudentProvider>().students;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: Text('전체 (${allStudents.length}명)'),
            selected: _selectedFilterSession == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilterSession = null);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(
              '미등록 (${allStudents.where((s) => s.session == null || s.session == 0).length}명)',
            ),
            selected: _selectedFilterSession == 0,
            onSelected: (selected) {
              if (selected) setState(() => _selectedFilterSession = 0);
            },
          ),
          const SizedBox(width: 8),
          ...List.generate(widget.academy.totalSessions, (i) => i + 1).map((s) {
            final count = allStudents.where((st) => st.session == s).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$s부 ($count명)'),
                selected: _selectedFilterSession == s,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedFilterSession = s);
                },
              ),
            );
          }),
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
        int? selected;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('학생 부 이동'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '선택한 ${_selectedStudentIds.length}명의 학생을 어느 부로 이동하시겠습니까?',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200, // 최대 높이 제한
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.academy.totalSessions,
                      itemBuilder: (context, index) {
                        final session = index + 1;
                        return RadioListTile<int>(
                          title: Text('$session부'),
                          value: session,
                          groupValue: selected,
                          onChanged: (val) => setState(() => selected = val),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(context, selected),
                  child: const Text('이동'),
                ),
              ],
            );
          },
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
    final students = _selectedFilterSession == null
        ? provider.students
        : provider.students
              .where((s) => s.session == _selectedFilterSession)
              .toList();

    if (students.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내보낼 학생 데이터가 없습니다')));
      return;
    }

    // 1. 컬럼 선택 다이얼로그 표시
    final selectedColumns = await _showExportOptionsDialog();
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

  Future<Map<String, bool>?> _showExportOptionsDialog() {
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

    return showDialog<Map<String, bool>>(
      context: context,
      builder: (context) {
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
          ownerId: widget.academy.ownerId,
        ),
      ),
    );
  }

  String _buildStudentSubtitle() {
    final s = widget.student;
    List<String> parts = [];

    // 학년-반 정보를 자막 영역으로 이동
    if (s.grade != null && s.classNumber != null) {
      parts.add('${s.grade}-${s.classNumber}');
    } else if (s.grade != null) {
      parts.add('${s.grade}학년');
    }

    // 급수는 타이틀로 이동했으므로 여기서는 제외

    if (s.studentNumber != null && s.studentNumber!.isNotEmpty) {
      parts.add('${s.studentNumber}번');
    }
    if (s.parentPhone != null && s.parentPhone!.isNotEmpty) {
      parts.add(s.parentPhone!);
    }
    return parts.join(' | ');
  }

  // initState removed to prevent N+1 fetching (handled by bulk load in parent)

  @override
  Widget build(BuildContext context) {
    final progressProvider = context.watch<ProgressProvider>();
    final progressList = progressProvider.getProgressForStudent(
      widget.student.id,
    );
    final activeProgress = progressList.isEmpty ? null : progressList.first;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: widget.isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () {
          if (widget.isSelectionMode) {
            widget.onToggleSelection();
          } else {
            // 일반 모드: 정보 수정 화면으로 이동
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 순번 표시 (선택 모드가 아닐 때만 혹은 항상?) -> 항상 표시하는 게 좋음
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
                        value: widget.isSelected,
                        onChanged: (_) => widget.onToggleSelection(),
                      ),
                    ),
                  CircleAvatar(child: Text(widget.student.name[0])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.student.session != null &&
                                widget.student.session != 0) ...[
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
                              ),
                            ] else ...[
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
                            ],
                            Text(
                              widget.student.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${widget.student.levelDisplayName})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
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
                  if (activeProgress != null)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${activeProgress.textbookName} (${activeProgress.volumeNumber}권)',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${activeProgress.progressPercentage.toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: activeProgress.progressPercentage / 100,
                                minHeight: 4,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  activeProgress.isCompleted
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 작업 버튼 영역 (기존 스타일 복구)
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
                        label: const Text(
                          '교재 할당',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        onPressed: () => _showDeleteConfirmation(context),
                        tooltip: '학생 삭제',
                      ),
                    ],
                  ),
                  if (activeProgress != null)
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                      size: 14,
                    ),
                ],
              ),
            ],
          ),
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
    ).then(
      (_) => context.read<ProgressProvider>().loadStudentProgress(
        widget.student.id,
      ),
    );
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
}
