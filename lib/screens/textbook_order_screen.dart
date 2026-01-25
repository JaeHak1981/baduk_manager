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
        title: const Text('교재 주문 명계표'),
        toolbarHeight: 48,
        elevation: 0,
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
                    horizontal: 20,
                    vertical: 8,
                  ), // 좌우 패딩 추가
                  itemCount: filteredStudents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _buildOrderRow(student, textbooks, progressProvider);
                  },
                ),
              ),
              _buildBottomButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), // 좌우 패딩 추가
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
              style: const TextStyle(fontSize: 13),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ), // 좌우 패딩 동기화
      child: Row(
        children: const [
          Expanded(
            flex: 22,
            child: Text(
              '이름',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 38,
            child: Text(
              '교재 선택',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              '권호',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              '전 교재',
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

    // 현재 진도 정보 가져오기
    final currentProgress = progressProvider.getProgressForStudent(student.id);
    String currentStatus = '없음';
    if (currentProgress.isNotEmpty) {
      final lastP = currentProgress.first;
      final textbook = textbooks.firstWhere(
        (t) => t.id == lastP.textbookId,
        orElse: () => TextbookModel(
          id: '',
          name: '알수없음',
          ownerId: '',
          totalVolumes: 0,
          category: '',
        ),
      );
      currentStatus = '${textbook.name} ${lastP.volumeNumber}권';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 1. 이름
          Expanded(
            flex: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  student.session != null && student.session != 0
                      ? '${student.session}부'
                      : '미지정',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 2. 교재 선택
          Expanded(
            flex: 38,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TextbookModel?>(
                isExpanded: true,
                value: entry.textbook,
                hint: const Text(
                  '없음',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem<TextbookModel?>(
                    value: null,
                    child: Text('없음', style: TextStyle(color: Colors.grey)),
                  ),
                  ...textbooks.map(
                    (t) => DropdownMenuItem<TextbookModel?>(
                      value: t,
                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    entry.textbook = val;
                    entry.volume = 1;
                  });
                },
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
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
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
          // 4. 전 교재 (현재 상태)
          Expanded(
            flex: 28,
            child: Text(
              currentStatus,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), // 좌우 패딩 추가
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.orange),
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _handleGenerateOrderSheet,
              child: const Text(
                '주문서 생성',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _handleOrderComplete,
              child: const Text(
                '주문 완료',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
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
          style: const TextStyle(fontSize: 11, color: Colors.black),
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
