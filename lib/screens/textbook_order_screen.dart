import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/textbook_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import 'dart:math' as math;

/// 학생별 교재 주문 상태를 관리하기 위한 임시 모델
class _OrderEntry {
  TextbookModel? textbook;
  int volume;
  bool isChanged; // 기본 추천값에서 변경되었는지 여부

  _OrderEntry({this.textbook, this.volume = 1, this.isChanged = false});
}

class TextbookOrderScreen extends StatefulWidget {
  final AcademyModel academy;

  const TextbookOrderScreen({super.key, required this.academy});

  @override
  State<TextbookOrderScreen> createState() => _TextbookOrderScreenState();
}

class _OrderEntryController {
  // State variables could go here if extracted, but for now we'll keep it in Screen State
}

class _TextbookOrderScreenState extends State<TextbookOrderScreen> {
  int? _selectedFilterSession;
  String _searchQuery = '';

  // 학생별 주문 설정을 저장하는 맵 (key: studentId)
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

  // 데이터 로드 후 각 학생별로 기본 추천 진도 세팅
  void _initializeEntries() {
    if (_isInitialized) return;

    final students = context.read<StudentProvider>().students;
    final textbooks = context.read<ProgressProvider>().allOwnerTextbooks;
    final progressProvider = context.read<ProgressProvider>();

    if (textbooks.isEmpty) return;

    for (var student in students) {
      final currentProgress = progressProvider.getProgressForStudent(
        student.id,
      );

      TextbookModel? recommendedTextbook;
      int recommendedVolume = 1;

      if (currentProgress.isNotEmpty) {
        // 마지막으로 진행한 교재 찾기
        final lastP = currentProgress.first;
        recommendedTextbook = textbooks.firstWhere(
          (t) => t.id == lastP.textbookId,
          orElse: () => textbooks.first,
        );
        recommendedVolume = (lastP.volumeNumber + 1).clamp(
          1,
          recommendedTextbook.totalVolumes,
        );
      } else {
        recommendedTextbook = textbooks.first;
      }

      _orderEntries[student.id] = _OrderEntry(
        textbook: recommendedTextbook,
        volume: recommendedVolume,
      );
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

  /// [주문 완료] - 실제 DB에 진도 기록 저장
  Future<void> _handleOrderComplete() async {
    final progressProvider = context.read<ProgressProvider>();
    final filteredStudents = _getFilteredStudents(
      context.read<StudentProvider>().students,
    );

    // 변경 사항이 있는 학생만 일괄 저장하거나, 전체 저장하거나 정책 결정 필요
    // 여기서는 화면에 보이는(필터링된) 학생들의 현재 설정값을 모두 저장하는 것으로 구현

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var student in filteredStudents) {
        final entry = _orderEntries[student.id];
        if (entry != null && entry.textbook != null) {
          // 1. 기존 진행 중 완료 처리
          final currentP = progressProvider.getProgressForStudent(student.id);
          for (var p in currentP) {
            if (!p.isCompleted)
              await progressProvider.updateVolumeStatus(p.id, student.id, true);
          }
          // 2. 새 권호 할당
          await progressProvider.assignVolume(
            studentId: student.id,
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            textbook: entry.textbook!,
            volumeNumber: entry.volume,
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('모든 학생의 진도 할당이 완료되었습니다.')));
        Navigator.pop(context); // 화면 닫기
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

  /// [주문서 (문자)] - 문자 양식 생성 및 복사
  void _handleGenerateOrderSheet() {
    final filteredStudents = _getFilteredStudents(
      context.read<StudentProvider>().students,
    );
    Map<String, Map<int, int>> summary = {}; // TextbookName -> {Volume: Count}

    for (var student in filteredStudents) {
      final entry = _orderEntries[student.id];
      if (entry != null && entry.textbook != null) {
        final tName = entry.textbook!.name;
        summary[tName] ??= {};
        summary[tName]![entry.volume] =
            (summary[tName]![entry.volume] ?? 0) + 1;
      }
    }

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
      appBar: AppBar(title: const Text('교재 주문 명계표'), toolbarHeight: 48),
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
                  itemCount: filteredStudents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _buildOrderRow(student, textbooks);
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
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '이름 검색',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                isDense: true,
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
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text(
              '학생 이름',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '교재 선택',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '권호',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(StudentModel student, List<TextbookModel> textbooks) {
    final entry = _orderEntries[student.id];
    if (entry == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // 1. 학생 이름
          Expanded(
            flex: 2,
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
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 2. 교재 선택
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TextbookModel>(
                isExpanded: true,
                value: entry.textbook,
                style: const TextStyle(fontSize: 13, color: Colors.black),
                items: textbooks
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    entry.textbook = val;
                    entry.volume = 1; // 교재 바뀌면 1권으로 리셋
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 3. 권호 선택
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: entry.volume,
                style: const TextStyle(fontSize: 13, color: Colors.black),
                items: (entry.textbook != null)
                    ? List.generate(entry.textbook!.totalVolumes, (i) => i + 1)
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v권')),
                          )
                          .toList()
                    : const [DropdownMenuItem(value: 1, child: Text('1권'))],
                onChanged: (val) => setState(() => entry.volume = val!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.orange),
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _handleGenerateOrderSheet,
              icon: const Icon(Icons.description),
              label: const Text(
                '주문서 (문자)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _handleOrderComplete,
              icon: const Icon(Icons.check_circle),
              label: const Text(
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedFilterSession,
          style: const TextStyle(fontSize: 12, color: Colors.black),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체 부')),
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
