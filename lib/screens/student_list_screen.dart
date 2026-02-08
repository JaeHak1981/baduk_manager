import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';

import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_model.dart';
import 'add_student_screen.dart';
import 'textbook_center_screen.dart';
import 'attendance_tab_screen.dart';
import 'batch_add_student_dialog.dart';
import 'student_history_screen.dart'; // 학생 히스토리 화면 import
import '../constants/ui_constants.dart';
import '../utils/excel_utils.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [ADDED]

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
      _checkOnboarding(); // [ADDED]
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('show_layout_guide_2024') ?? false;

    if (!hasShown && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.orange),
              SizedBox(width: 8),
              Text('화면 개선 안내'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '더 많은 정보를 한눈에 관리할 수 있도록 학생 목록 화면이 개선되었습니다!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• PC/태블릿: 넓은 화면을 활용한 2단 리스트'),
              Text('• 모바일: 더 슬림해진 1단 리스트'),
              Text('• 시선 최적화: 왼쪽에서 아래로 번호순 정렬'),
              Text('• 고정 헤더: 스크롤을 내려도 항목 이름 유지'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                prefs.setBool('show_layout_guide_2024', true);
                Navigator.pop(context);
              },
              child: const Text('확인 완료'),
            ),
          ],
        ),
      );
    }
  }

  void _loadData() {
    context.read<StudentProvider>().loadStudents(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );
    // [Bulk Load] 전체 진도 한 번에 로드
    context.read<ProgressProvider>().loadAcademyProgress(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );
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
      final success = await context
          .read<StudentProvider>()
          .batchProcessStudents(
            toDelete: _selectedStudentIds.toList(),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;

                  return Expanded(
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
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () async => _loadData(),
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0, // 헤더가 고정이므로 상단 여백 제거
                                      16,
                                      AppDimensions.getBottomInset(context) +
                                          40,
                                    ),
                                    child: isWide
                                        ? _buildTwoColumnLayout(
                                            filteredStudents,
                                          )
                                        : _buildSingleColumnLayout(
                                            filteredStudents,
                                          ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
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
    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _buildListHeader()),
            const SizedBox(width: 16),
            Expanded(child: _buildListHeader()),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildListHeader(),
    );
  }

  Widget _buildListHeader() {
    const textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
    );

    return Container(
      height: 36,
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
            width: 40,
            child: Center(child: Text('번호', style: textStyle)),
          ),
          const SizedBox(
            width: 60,
            child: Center(child: Text('부', style: textStyle)),
          ),
          const SizedBox(width: 90, child: Text('성명', style: textStyle)),
          const SizedBox(width: 50, child: Text('학년', style: textStyle)),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('진도 현황', style: textStyle),
            ),
          ),
          const SizedBox(width: 65, child: Text('출석', style: textStyle)),
          const SizedBox(
            width: 160,
            child: Text('관리', style: textStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnLayout(List<StudentModel> filteredStudents) {
    // Column-major 정렬: 1~15번 왼쪽, 16~30번 오른쪽
    final halfLength = (filteredStudents.length / 2).ceil();
    final leftColumnStudents = filteredStudents.take(halfLength).toList();
    final rightColumnStudents = filteredStudents.skip(halfLength).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(leftColumnStudents.length, (index) {
              final student = leftColumnStudents[index];
              return _StudentProgressCard(
                index: index + 1,
                student: student,
                academy: widget.academy,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedStudentIds.contains(student.id),
                onToggleSelection: () => _toggleStudentSelection(student.id),
              );
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: List.generate(rightColumnStudents.length, (index) {
              final student = rightColumnStudents[index];
              return _StudentProgressCard(
                index: halfLength + index + 1,
                student: student,
                academy: widget.academy,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedStudentIds.contains(student.id),
                onToggleSelection: () => _toggleStudentSelection(student.id),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumnLayout(List<StudentModel> filteredStudents) {
    return Column(
      children: List.generate(filteredStudents.length, (index) {
        final student = filteredStudents[index];
        return _StudentProgressCard(
          index: index + 1,
          student: student,
          academy: widget.academy,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedStudentIds.contains(student.id),
          onToggleSelection: () => _toggleStudentSelection(student.id),
        );
      }),
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
                      if (selected) {
                        setState(() => _selectedFilterSession = null);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      '미등록 (${activeStudents.where((s) => s.session == null || s.session == 0).length}명)',
                    ),
                    selected: _selectedFilterSession == 0,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilterSession = 0);
                      }
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
                          if (selected) {
                            setState(() => _selectedFilterSession = s);
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

  @override
  Widget build(BuildContext context) {
    final progressProvider = context.watch<ProgressProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    // 메인 화면에서는 완료되지 않은(진행 중인) 교재만 표시
    final progressList = progressProvider
        .getProgressForStudent(widget.student.id)
        .where((p) => !p.isCompleted)
        .toList();

    // 오늘의 출석 정보
    final todayRecord = attendanceProvider.getTodayRecord(widget.student.id);

    return Container(
      height: 44, // 고정 높이로 밀도 최적화
      decoration: BoxDecoration(
        color: widget.isSelected ? Colors.blue.shade50 : Colors.white,
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
              // 0. 선택/번호 영역 (40)
              SizedBox(
                width: 40,
                child: widget.isSelectionMode
                    ? Checkbox(
                        value: widget.isSelected,
                        onChanged: (_) => widget.onToggleSelection(),
                      )
                    : Text(
                        '${widget.index}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
              ),

              // 1. [부] 영역 (60)
              SizedBox(
                width: 60,
                child: Center(
                  child:
                      widget.student.session != null &&
                          widget.student.session != 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade200),
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
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Text(
                            '미배정',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),

              // 2. [이름] 영역 (90)
              SizedBox(
                width: 90,
                child: Text(
                  widget.student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 3. [학년] 영역 (50)
              SizedBox(
                width: 50,
                child: Text(
                  widget.student.grade != null
                      ? '${widget.student.grade}학년'
                      : '-',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),

              // 4. [진도현황] 영역 (Expanded)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: progressList.isNotEmpty
                      ? Text(
                          '${progressList.first.textbookName} ${progressList.first.volumeNumber}권 (${progressList.first.progressPercentage.toInt()}%)',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        )
                      : const Text(
                          '-',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                ),
              ),

              // 5. [출석상태] 영역 (65)
              SizedBox(
                width: 65,
                child: todayRecord == null
                    ? const SizedBox()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            todayRecord.type == AttendanceType.present
                                ? Icons.check_circle
                                : (todayRecord.type == AttendanceType.absent
                                      ? Icons.cancel
                                      : Icons.access_time),
                            size: 14,
                            color: todayRecord.type == AttendanceType.present
                                ? Colors.green
                                : (todayRecord.type == AttendanceType.absent
                                      ? Colors.red
                                      : Colors.orange),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            todayRecord.type == AttendanceType.present
                                ? '출석'
                                : (todayRecord.type == AttendanceType.absent
                                      ? '결석'
                                      : '지각'),
                            style: TextStyle(
                              fontSize: 10,
                              color: todayRecord.type == AttendanceType.present
                                  ? Colors.green
                                  : (todayRecord.type == AttendanceType.absent
                                        ? Colors.red
                                        : Colors.orange),
                            ),
                          ),
                        ],
                      ),
              ),

              // 6. [관리버튼] 영역 (160)
              SizedBox(
                width: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _navigateToStudentHistory(context, widget.student),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('학습정보', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 2),
                    TextButton(
                      onPressed: () => _navigateToAssignTextbook(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('교재할당', style: TextStyle(fontSize: 11)),
                    ),
                    if (widget.student.isDeleted) ...[
                      const SizedBox(width: 2),
                      TextButton(
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                            final provider = context.read<StudentProvider>();
                            await provider.restoreStudent(
                              widget.student.id,
                              academyId: widget.student.academyId,
                              ownerId: widget.student.ownerId,
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Colors.green,
                        ),
                        child: const Text('복구', style: TextStyle(fontSize: 11)),
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
