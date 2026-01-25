import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/textbook_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';

class TextbookOrderScreen extends StatefulWidget {
  final AcademyModel academy;

  const TextbookOrderScreen({super.key, required this.academy});

  @override
  State<TextbookOrderScreen> createState() => _TextbookOrderScreenState();
}

class _TextbookOrderScreenState extends State<TextbookOrderScreen> {
  int? _selectedFilterSession; // null: 전체
  final Set<String> _selectedStudentIds = {};
  TextbookModel? _selectedTextbook;
  final Set<int> _selectedVolumes = {}; // 다중 선택된 권호들
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    context.read<StudentProvider>().loadStudents(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );
    context.read<ProgressProvider>().loadOwnerTextbooks(widget.academy.ownerId);
    context.read<ProgressProvider>().loadAcademyProgress(widget.academy.id);
  }

  List<StudentModel> _getFilteredStudents(List<StudentModel> allStudents) {
    List<StudentModel> filtered = allStudents;

    if (_selectedFilterSession != null) {
      if (_selectedFilterSession == 0) {
        filtered = filtered
            .where((s) => s.session == null || s.session == 0)
            .toList();
      } else {
        filtered = filtered
            .where((s) => s.session == _selectedFilterSession)
            .toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) => s.name.contains(_searchQuery)).toList();
    }

    return filtered;
  }

  void _toggleSelectAll(List<StudentModel> filteredStudents) {
    setState(() {
      final allSelected =
          filteredStudents.isNotEmpty &&
          filteredStudents.every((s) => _selectedStudentIds.contains(s.id));

      if (allSelected) {
        for (var s in filteredStudents) {
          _selectedStudentIds.remove(s.id);
        }
      } else {
        _selectedStudentIds.addAll(filteredStudents.map((s) => s.id));
      }
    });
  }

  Future<void> _handleOrderAndAssign() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학생을 선택해 주세요')));
      return;
    }
    if (_selectedTextbook == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재를 선택해 주세요')));
      return;
    }
    if (_selectedVolumes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문할 권호를 선택해 주세요')));
      return;
    }

    final progressProvider = context.read<ProgressProvider>();
    Map<int, int> volumeCounts = {};
    int totalAssigned = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<int> sortedSelectedVolumes = _selectedVolumes.toList()..sort();

      for (var studentId in _selectedStudentIds) {
        // 1. 기존 진행 중인 교재 자동 완료 처리
        final currentProgress = progressProvider.getProgressForStudent(
          studentId,
        );
        for (var p in currentProgress) {
          if (!p.isCompleted) {
            await progressProvider.updateVolumeStatus(p.id, studentId, true);
          }
        }

        // 2. 선택된 모든 권호 할당
        for (var v in sortedSelectedVolumes) {
          await progressProvider.assignVolume(
            studentId: studentId,
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            textbook: _selectedTextbook!,
            volumeNumber: v,
          );

          volumeCounts[v] = (volumeCounts[v] ?? 0) + 1;
          totalAssigned++;
        }
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        _showOrderSummaryDialog(totalAssigned, volumeCounts);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
      }
    }
  }

  void _showOrderSummaryDialog(int totalCount, Map<int, int> volumeCounts) {
    final String textbookName = _selectedTextbook!.name;
    List<int> sortedVolumes = volumeCounts.keys.toList()..sort();
    String detailedVolumes = sortedVolumes
        .map((v) => '${v}권(${volumeCounts[v]})')
        .join(', ');

    String orderSummary =
        '[${widget.academy.name}] 주문 내역:\n'
        '$textbookName $detailedVolumes\n'
        '총 $totalCount권 주문 요청합니다.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 및 할당 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('학생들에게 교재 할당이 완료되었습니다.'),
            const SizedBox(height: 16),
            const Text(
              '출판사 전송용 주문 문구:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(orderSummary),
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
              Clipboard.setData(ClipboardData(text: orderSummary));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('클립보드에 복사되었습니다')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('문구 복사하기'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('교재 주문 및 할당')),
      body: Consumer2<StudentProvider, ProgressProvider>(
        builder: (context, studentProvider, progressProvider, child) {
          final filteredStudents = _getFilteredStudents(
            studentProvider.students,
          );
          return Column(
            children: [
              _buildStudentSelectionArea(filteredStudents),
              const Divider(height: 1),
              _buildOrderSettingsArea(progressProvider.allOwnerTextbooks),
              _buildBottomButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentSelectionArea(List<StudentModel> filteredStudents) {
    return Expanded(
      flex: 5, // 학생 목록에 더 많은 공간 할당
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '이름 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSessionFilterDropdown(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedStudentIds.length}명 선택됨',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleSelectAll(filteredStudents),
                  icon: Icon(
                    _selectedStudentIds.length == filteredStudents.length &&
                            filteredStudents.isNotEmpty
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                  label: Text(
                    _selectedStudentIds.length == filteredStudents.length &&
                            filteredStudents.isNotEmpty
                        ? '전체 해제'
                        : '전체 선택',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                final isSelected = _selectedStudentIds.contains(student.id);
                return CheckboxListTile(
                  visualDensity: VisualDensity.compact,
                  value: isSelected,
                  title: Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    student.session != null && student.session != 0
                        ? '${student.session}부'
                        : '부 미지정',
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (val == true)
                        _selectedStudentIds.add(student.id);
                      else
                        _selectedStudentIds.remove(student.id);
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionFilterDropdown() {
    return DropdownButton<int?>(
      value: _selectedFilterSession,
      items: [
        const DropdownMenuItem(value: null, child: Text('전체 부')),
        const DropdownMenuItem(value: 0, child: Text('미지정')),
        ...List.generate(
          widget.academy.totalSessions,
          (i) => i + 1,
        ).map((s) => DropdownMenuItem(value: s, child: Text('$s부'))),
      ],
      onChanged: (val) => setState(() => _selectedFilterSession = val),
    );
  }

  Widget _buildOrderSettingsArea(List<TextbookModel> textbooks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '교재 및 권호 선택',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TextbookModel>(
            value: _selectedTextbook,
            decoration: const InputDecoration(
              labelText: '교재 시리즈',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: textbooks
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedTextbook = val;
                _selectedVolumes.clear();
              });
            },
          ),
          if (_selectedTextbook != null) ...[
            const SizedBox(height: 16),
            const Text(
              '주문할 권호들을 터치하여 선택하세요:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120, // 그리드 영역 높이 제한
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.2,
                ),
                itemCount: _selectedTextbook!.totalVolumes,
                itemBuilder: (context, index) {
                  final volume = index + 1;
                  final isSelected = _selectedVolumes.contains(volume);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected)
                          _selectedVolumes.remove(volume);
                        else
                          _selectedVolumes.add(volume);
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$volume',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final int totalBooks = _selectedStudentIds.length * _selectedVolumes.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _handleOrderAndAssign,
        child: Text(
          totalBooks > 0 ? '총 $totalBooks권 주문 및 할당 실행' : '주문 및 할당 실행',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
