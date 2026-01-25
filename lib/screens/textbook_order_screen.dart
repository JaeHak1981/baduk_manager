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
  int _selectedStartVolume = 1;
  int _selectedEndVolume = 1;
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

    // 부 필터링
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

    // 이름 검색 필터링
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
      ).showSnackBar(const SnackBar(content: Text('주문할 교재를 선택해 주세요')));
      return;
    }

    final progressProvider = context.read<ProgressProvider>();
    int totalCount = 0;

    // 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
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

        // 2. 새 교재 할당 (시작 권수부터 종료 권수까지)
        for (int v = _selectedStartVolume; v <= _selectedEndVolume; v++) {
          await progressProvider.assignVolume(
            studentId: studentId,
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            textbook: _selectedTextbook!,
            volumeNumber: v,
          );
          totalCount++;
        }
      }

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        _showOrderSummaryDialog(totalCount);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _showOrderSummaryDialog(int totalCount) {
    final int studentCount = _selectedStudentIds.length;
    final int volumesPerStudent = _selectedEndVolume - _selectedStartVolume + 1;
    final String textbookName = _selectedTextbook!.name;

    String volumeRange = _selectedStartVolume == _selectedEndVolume
        ? '$_selectedStartVolume권'
        : '$_selectedStartVolume~$_selectedEndVolume권';

    String orderSummary =
        '[${widget.academy.name}] 주문 내역:\n'
        '$textbookName $volumeRange ($studentCount명 x $volumesPerStudent권)\n'
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('주문 문구가 클립보드에 복사되었습니다')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('문구 복사하기'),
          ),
        ],
      ),
    ).then((_) {
      // 작업 완료 후 화면 닫기 (또는 상태 초기화)
      Navigator.pop(context);
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
              // 1. 학생 선택 영역
              _buildStudentSelectionArea(filteredStudents),

              const Divider(height: 1),

              // 2. 교재 선택 및 주문 정보 설정 영역
              _buildOrderSettingsArea(progressProvider.allOwnerTextbooks),

              // 3. 하단 주문 버튼
              _buildBottomButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentSelectionArea(List<StudentModel> filteredStudents) {
    return Expanded(
      flex: 3,
      child: Column(
        children: [
          // 필터 및 검색
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '학생 이름 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                _buildSessionFilterDropdown(),
              ],
            ),
          ),

          // 전체 선택 버튼
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

          // 학생 리스트
          Expanded(
            child: ListView.builder(
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                final isSelected = _selectedStudentIds.contains(student.id);
                return CheckboxListTile(
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
                      if (val == true) {
                        _selectedStudentIds.add(student.id);
                      } else {
                        _selectedStudentIds.remove(student.id);
                      }
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
      hint: const Text('부 선택'),
      items: [
        const DropdownMenuItem(value: null, child: Text('전체 부')),
        const DropdownMenuItem(value: 0, child: Text('미지정')),
        ...List.generate(widget.academy.totalSessions, (i) => i + 1).map((s) {
          return DropdownMenuItem(value: s, child: Text('$s부'));
        }),
      ],
      onChanged: (val) => setState(() => _selectedFilterSession = val),
    );
  }

  Widget _buildOrderSettingsArea(List<TextbookModel> textbooks) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주문 및 할당 교재 설정',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),

          // 교재 선택 드롭다운
          DropdownButtonFormField<TextbookModel>(
            value: _selectedTextbook,
            decoration: const InputDecoration(
              labelText: '교재 시리즈 선택',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: textbooks.map((t) {
              return DropdownMenuItem(value: t, child: Text(t.name));
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedTextbook = val;
                _selectedStartVolume = 1;
                _selectedEndVolume = 1;
              });
            },
          ),

          const SizedBox(height: 16),

          // 권호 범위 선택
          if (_selectedTextbook != null)
            Row(
              children: [
                Expanded(
                  child: _buildVolumeDropdown(
                    label: '시작 권호',
                    value: _selectedStartVolume,
                    max: _selectedTextbook!.totalVolumes,
                    onChanged: (val) {
                      setState(() {
                        _selectedStartVolume = val!;
                        if (_selectedEndVolume < _selectedStartVolume) {
                          _selectedEndVolume = _selectedStartVolume;
                        }
                      });
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('~'),
                ),
                Expanded(
                  child: _buildVolumeDropdown(
                    label: '종료 권호',
                    value: _selectedEndVolume,
                    max: _selectedTextbook!.totalVolumes,
                    onChanged: (val) {
                      setState(() {
                        _selectedEndVolume = val!;
                        if (_selectedStartVolume > _selectedEndVolume) {
                          _selectedStartVolume = _selectedEndVolume;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),

          if (_selectedTextbook != null) ...[
            const SizedBox(height: 12),
            Text(
              '1인당 주문 수량: ${_selectedEndVolume - _selectedStartVolume + 1}권',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeDropdown({
    required String label,
    required int value,
    required int max,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        filled: true,
        fillColor: Colors.white,
      ),
      items: List.generate(max, (i) => i + 1).map((v) {
        return DropdownMenuItem(value: v, child: Text('$v권'));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBottomButton() {
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
        child: const Text(
          '주문 및 할당 실행',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
