import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/textbook_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';

/// 학생별 교재 주문 상태를 관리하기 위한 임시 모델
class _OrderEntry {
  TextbookModel? textbook; // null 이면 '없음'
  int volume;

  _OrderEntry({this.textbook, this.volume = 1});
}

class TextbookOrderScreen extends StatefulWidget {
  final AcademyModel academy;

  const TextbookOrderScreen({super.key, required this.academy});

  @override
  State<TextbookOrderScreen> createState() => _TextbookOrderScreenState();
}

class _TextbookOrderScreenState extends State<TextbookOrderScreen> {
  int? _selectedFilterSession;
  String _searchQuery = '';

  final Map<String, _OrderEntry> _orderEntries = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    final studentProvider = context.read<StudentProvider>();
    final progressProvider = context.read<ProgressProvider>();

    await studentProvider.loadStudents(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );
    await progressProvider.loadOwnerTextbooks(widget.academy.ownerId);
    await progressProvider.loadAcademyProgress(widget.academy.id);

    _initializeEntries();
  }

  void _initializeEntries() {
    if (_isInitialized) return;

    final students = context.read<StudentProvider>().students;
    for (var student in students) {
      _orderEntries[student.id] = _OrderEntry(textbook: null, volume: 1);
    }

    setState(() {
      _isInitialized = true;
    });
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

  Future<void> _handleOrderComplete() async {
    final progressProvider = context.read<ProgressProvider>();
    final entriesToAssign = _orderEntries.entries
        .where((e) => e.value.textbook != null)
        .toList();

    if (entriesToAssign.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('할당할 교재를 선택한 학생이 없습니다.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var entry in entriesToAssign) {
        final studentId = entry.key;
        final orderEntry = entry.value;

        final currentP = progressProvider.getProgressForStudent(studentId);
        for (var p in currentP) {
          if (!p.isCompleted)
            await progressProvider.updateVolumeStatus(p.id, studentId, true);
        }
        await progressProvider.assignVolume(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
          textbook: orderEntry.textbook!,
          volumeNumber: orderEntry.volume,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${entriesToAssign.length}명의 진도 할당이 완료되었습니다.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('할당 중 오류: $e')));
      }
    }
  }

  void _handleGenerateOrderSheet() {
    Map<String, Map<int, int>> summary = {};

    _orderEntries.forEach((studentId, entry) {
      if (entry.textbook != null) {
        final tName = entry.textbook!.name;
        summary[tName] ??= {};
        summary[tName]![entry.volume] =
            (summary[tName]![entry.volume] ?? 0) + 1;
      }
    });

    if (summary.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주문할 내용이 없습니다.')));
      return;
    }

    StringBuffer buffer = StringBuffer('[${widget.academy.name}] 주문 내역:\n');
    int totalAll = 0;

    summary.forEach((tName, volumes) {
      List<int> sortedV = volumes.keys.toList()..sort();
      String detailed = sortedV.map((v) => '${v}권(${volumes[v]})').join(', ');
      buffer.writeln('$tName $detailed');
      totalAll += volumes.values.fold(0, (sum, c) => sum + c);
    });
    buffer.write('총 $totalAll권 주문 요청합니다.');

    _showOrderSummaryDialog(buffer.toString());
  }

  void _showOrderSummaryDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('교재 주문서 생성'),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('복사되었습니다.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('복사하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '교재 주문 명계표',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        toolbarHeight: 56,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _handleGenerateOrderSheet,
            child: const Text(
              '주문서',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: _handleOrderComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Consumer2<StudentProvider, ProgressProvider>(
        builder: (context, studentProvider, progressProvider, child) {
          if (!_isInitialized && studentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final filteredStudents = _getFilteredStudents(
            studentProvider.students,
          );
          final textbooks = progressProvider.allOwnerTextbooks;

          return Column(
            children: [
              _buildFilterArea(),
              _buildTableHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredStudents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _buildOrderRow(student, textbooks, progressProvider);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '이름 검색',
                prefixIcon: Icon(Icons.search, size: 16),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 8),
          _buildSessionFilterDropdown(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Expanded(
            flex: 20,
            child: Text(
              '이름',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 52,
            child: Text(
              '교재 선택 (클릭)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '권',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              '기존',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
    StudentModel student,
    List<TextbookModel> textbooks,
    ProgressProvider progressProvider,
  ) {
    final entry = _orderEntries[student.id];
    if (entry == null) return const SizedBox();

    final currentProgress = progressProvider.getProgressForStudent(student.id);
    String currentStatus = '없음';
    if (currentProgress.isNotEmpty) {
      final lastP = currentProgress.first;
      final textbook = textbooks.firstWhere(
        (t) => t.id == lastP.textbookId,
        orElse: () => TextbookModel(
          id: '',
          name: '알수',
          ownerId: '',
          totalVolumes: 0,
          createdAt: DateTime.now(),
        ),
      );
      currentStatus =
          '${textbook.name.substring(0, textbook.name.length > 2 ? 3 : textbook.name.length)} ${lastP.volumeNumber}q';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 1. 이름 및 부 (고정)
          Expanded(
            flex: 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  student.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  student.session != null && student.session != 0
                      ? '${student.session}부'
                      : '미정',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 2. 교재 선택 버튼들 (가로 스크롤)
          Expanded(
            flex: 52,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSelectButton(
                    label: '없음',
                    isSelected: entry.textbook == null,
                    onTap: () => setState(() {
                      entry.textbook = null;
                      entry.volume = 1;
                    }),
                    isNone: true,
                  ),
                  for (var t in textbooks)
                    _buildSelectButton(
                      label: t.name,
                      isSelected: entry.textbook?.id == t.id,
                      onTap: () => setState(() {
                        entry.textbook = t;
                        entry.volume = 1;
                      }),
                    ),
                ],
              ),
            ),
          ),
          // 3. 권호 선택
          Expanded(
            flex: 12,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: entry.volume,
                alignment: Alignment.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
                items: (entry.textbook != null)
                    ? List.generate(entry.textbook!.totalVolumes, (i) => i + 1)
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Center(child: Text('$v')),
                            ),
                          )
                          .toList()
                    : const [
                        DropdownMenuItem(
                          value: 1,
                          child: Center(child: Text('-')),
                        ),
                      ],
                onChanged: entry.textbook == null
                    ? null
                    : (val) => setState(() => entry.volume = val!),
              ),
            ),
          ),
          // 4. 기존 상태
          Expanded(
            flex: 16,
            child: Text(
              currentStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: currentStatus == '없음'
                    ? Colors.red.shade700
                    : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isNone = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : (isNone ? Colors.black : Colors.black54),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected
                ? Colors.white
                : (isNone ? Colors.black : Colors.black),
            fontWeight: isSelected || isNone
                ? FontWeight.bold
                : FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedFilterSession,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체')),
            const DropdownMenuItem(value: 0, child: Text('미지정')),
            ...List.generate(
              widget.academy.totalSessions,
              (i) => i + 1,
            ).map((s) => DropdownMenuItem(value: s, child: Text('$s부'))),
          ],
          onChanged: (val) => setState(() => _selectedFilterSession = val),
        ),
      ),
    );
  }
}
