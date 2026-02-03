import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';

class BatchAddStudentDialog extends StatefulWidget {
  final String academyId;
  final String ownerId;

  const BatchAddStudentDialog({
    super.key,
    required this.academyId,
    required this.ownerId,
  });

  @override
  State<BatchAddStudentDialog> createState() => _BatchAddStudentDialogState();
}

class _BatchAddStudentDialogState extends State<BatchAddStudentDialog> {
  final TextEditingController _textController = TextEditingController();
  List<StudentModel> _toUpdate = [];
  List<StudentModel> _toAdd = [];
  List<StudentModel> _toDelete = []; // 종료된 것으로 간주될 학생(DB에만 있는 학생)

  // 변경 사항 추적을 위한 맵 (ID -> 구 정보)
  Map<String, StudentModel> _originalStudents = {};

  bool _isParsed = false;
  bool _isLoading = false;
  bool _processWithdrawals = false; // 종료 처리 포함 여부

  void _parseData() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentStudents = context.read<StudentProvider>().students;
    final Map<String, StudentModel> studentMap = {
      for (var s in currentStudents) s.id: s,
    };
    final Map<String, StudentModel> studentNameMap = {
      for (var s in currentStudents) s.name: s,
    };

    final lines = text.split('\n');

    List<StudentModel> toAddList = [];
    List<StudentModel> toUpdateList = [];
    Set<String> processedIds = {};

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      List<String> parts = line.split('\t');
      if (parts.length < 2 && line.contains(',')) {
        parts = line.split(',');
      }

      String? id;
      String? name;
      int? grade;
      String? classNumber;
      String? studentNumber;
      int? session;
      String? parentPhone;
      String? note;

      List<String> remainingParts = [];

      for (var i = 0; i < parts.length; i++) {
        final p = parts[i].trim();
        if (p.isEmpty) continue;

        // 1. ID 감지 (첫 번째 열이거나 ID 형태인 경우)
        if (i == 0 && p.length > 15 && !p.contains(' ')) {
          id = p;
          continue;
        }

        if (p.contains('교시') || p.contains('부')) {
          final numStr = p.replaceAll(RegExp(r'[^0-9]'), '');
          if (numStr.isNotEmpty) {
            int val = int.parse(numStr);
            if (p.contains('교시')) {
              session = (val >= 6) ? val - 5 : val;
            } else {
              session = val;
            }
          }
          continue;
        }

        if (p.contains('-') ||
            (p.length >= 9 && int.tryParse(p.replaceAll('-', '')) != null)) {
          parentPhone = p;
          continue;
        }

        bool isNumeric = int.tryParse(p) != null;
        if (!isNumeric && name == null) {
          name = p;
          continue;
        }

        remainingParts.add(p);
      }

      if (remainingParts.isNotEmpty) grade = int.tryParse(remainingParts[0]);
      if (remainingParts.length > 1) classNumber = remainingParts[1];
      if (remainingParts.length > 2) studentNumber = remainingParts[2];
      if (remainingParts.length > 3) note = remainingParts[3];

      if (name == null && id != null && studentMap.containsKey(id)) {
        name = studentMap[id]!.name;
      }

      if (name != null) {
        // 매칭 시도
        StudentModel? existing;
        if (id != null && studentMap.containsKey(id)) {
          existing = studentMap[id];
        } else if (studentNameMap.containsKey(name)) {
          existing = studentNameMap[name];
        }

        if (existing != null) {
          processedIds.add(existing.id);
          _originalStudents[existing.id] = existing;

          toUpdateList.add(
            existing.copyWith(
              grade: grade ?? existing.grade,
              classNumber: classNumber ?? existing.classNumber,
              studentNumber: studentNumber ?? existing.studentNumber,
              session: session ?? existing.session,
              parentPhone: parentPhone ?? existing.parentPhone,
              note: note ?? existing.note,
            ),
          );
        } else {
          toAddList.add(
            StudentModel(
              id: '',
              academyId: widget.academyId,
              ownerId: widget.ownerId,
              name: name,
              grade: grade,
              classNumber: classNumber,
              studentNumber: studentNumber,
              session: session,
              parentPhone: parentPhone,
              note: note,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    // 종료 후보 추출 (DB에는 있으나 엑셀에는 없는 학생)
    List<StudentModel> toDeleteList = currentStudents
        .where((s) => !processedIds.contains(s.id))
        .toList();

    setState(() {
      _toAdd = toAddList;
      _toUpdate = toUpdateList;
      _toDelete = toDeleteList;
      _isParsed = true;
    });
  }

  Future<void> _registerStudents() async {
    final totalCurrent = context.read<StudentProvider>().students.length;
    if (_processWithdrawals &&
        _toDelete.length > totalCurrent / 2 &&
        totalCurrent > 5) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ 대량 수강 종료 경고'),
          content: Text(
            '전체 인원의 절반 이상(${_toDelete.length}명)이 수강 종료 대상으로 분석되었습니다. 전체 명단이 아닌 일부 명단만 업로드하신 것은 아닌가요?\n\n무시하고 진행하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('진행 (주의)'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<StudentProvider>();
      await provider.batchProcessStudents(
        toUpdate: _toUpdate,
        toAdd: _toAdd,
        toDelete: _processWithdrawals
            ? _toDelete.map((s) => s.id).toList()
            : null,
        academyId: widget.academyId,
        ownerId: widget.ownerId,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('등록 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '학생 명단 일괄 등록',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isParsed) ...[
              const Text(
                '엑셀이나 표에서 아래 순서대로 복사(Ctrl+C)해서 붙여넣으세요.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[100],
                child: const Text('이름  |  학년  |  반  |  번호  |  전화번호  |  부(교시)'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '여기에 붙여넣기 (Ctrl+V)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _parseData,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('명단 분석하기'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '수정: ${_toUpdate.length}명, 신규: ${_toAdd.length}명',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      if (_toDelete.isNotEmpty)
                        Text(
                          '누락(종력후보): ${_toDelete.length}명',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _toDelete.length > 5
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isParsed = false;
                        _toUpdate = [];
                        _toAdd = [];
                        _toDelete = [];
                        _originalStudents = {};
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('다시 입력'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_toUpdate.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '📝 정보 수정 대상',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ..._toUpdate.map((s) {
                          final old = _originalStudents[s.id]!;
                          List<String> changes = [];
                          if (old.grade != s.grade)
                            changes.add('학년: ${old.grade ?? "-"} → ${s.grade}');
                          if (old.classNumber != s.classNumber)
                            changes.add(
                              '반: ${old.classNumber ?? "-"} → ${s.classNumber}',
                            );
                          if (old.studentNumber != s.studentNumber)
                            changes.add(
                              '번호: ${old.studentNumber ?? "-"} → ${s.studentNumber}',
                            );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                changes.isEmpty
                                    ? '변경 사항 없음'
                                    : changes.join(', '),
                              ),
                              trailing: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                          );
                        }),
                      ],
                      if (_toAdd.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '✨ 신규 등록 대상',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ..._toAdd.map(
                          (s) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(s.name),
                              subtitle: Text(
                                '${s.grade ?? "-"}학년 ${s.classNumber ?? "-"}반',
                              ),
                              trailing: const Icon(
                                Icons.add,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_toDelete.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '⚠️ 누락(퇴원 / 수강종료 후보)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: _processWithdrawals,
                                onChanged: (val) => setState(
                                  () => _processWithdrawals = val ?? false,
                                ),
                                title: const Text('위 학생들을 퇴원 / 수강종료 처리합니다.'),
                                subtitle: const Text(
                                  '체크하지 않으면 정보는 유지되지만 엑셀 명단에는 없습니다.',
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                              Wrap(
                                spacing: 8,
                                children: _toDelete
                                    .map(
                                      (s) => Chip(
                                        label: Text(
                                          s.name,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.white,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _registerStudents,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? '처리 중...' : '일괄 적용하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
