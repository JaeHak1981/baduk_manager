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
  List<StudentModel> _parsedStudents = [];
  bool _isParsed = false;
  bool _isLoading = false;

  void _parseData() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final List<StudentModel> students = [];

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      // 탭(\t) 또는 쉼표(,)로 분리. 엑셀 복사는 보통 탭으로 옴.
      // 연속된 공백도 처리하고 싶다면 정규식 사용 가능하지만,
      // 엑셀 복붙은 탭이 확실하므로 탭 우선.
      List<String> parts = line.split('\t');
      if (parts.length < 2 && line.contains(',')) {
        parts = line.split(',');
      }

      // 스마트 파싱: 열의 위치가 바뀌어도 인식하도록 시도
      String? name;
      int? grade;
      String? classNumber;
      String? studentNumber;
      int? session;

      // 1. 이름 찾기 (한글 2~4글자이고 숫자가 포함되지 않은 경우 우선)
      // 2. 교시/부 찾기 ('교시', '부' 포함)
      // 3. 나머지는 숫자(학년, 반, 번호)로 추론

      final partCount = parts.length;
      List<String> remainingParts = []; // 이름/세션 제외한 숫자 후보들

      for (var part in parts) {
        final p = part.trim();
        if (p.isEmpty) continue;

        // 세션 감지 (6교시, 1부 등)
        if (p.contains('교시') || p.contains('부')) {
          final numStr = p.replaceAll(RegExp(r'[^0-9]'), '');
          if (numStr.isNotEmpty) {
            int val = int.parse(numStr);
            // 사용자 요청 매핑: 6교시 -> 1부, 7교시 -> 2부 ...
            // 초등학교 시간표 기준 6교시작 -> 1부로 매핑하는 로직 적용
            if (p.contains('교시')) {
              if (val >= 6)
                session = val - 5; // 6->1, 7->2, 8->3
              else
                session = val;
            } else {
              session = val; // 1부 -> 1
            }
          }
          continue;
        }

        // 이름 감지 (한글 등 문자열, 숫자로만 구성되지 않음)
        // 안영준 -> OK, 1 -> No, 1-1 -> No
        bool isNumeric = int.tryParse(p) != null;
        if (!isNumeric && name == null) {
          name = p;
          continue;
        }

        remainingParts.add(p);
      }

      // 남은 숫자들로 학년/반/번호 매핑 (순서대로)
      if (remainingParts.isNotEmpty) grade = int.tryParse(remainingParts[0]);
      if (remainingParts.length > 1)
        classNumber = remainingParts[1]; // 문자열 유지 (1-1 등 가능성)
      if (remainingParts.length > 2) studentNumber = remainingParts[2];

      // 만약 이름이 없는데 parts[0]이 있었다면, 기존 로직대로 0번을 이름으로 간주 (Fallback)
      if (name == null && parts.isNotEmpty && int.tryParse(parts[0]) == null) {
        name = parts[0].trim();
      }

      if (name != null) {
        students.add(
          StudentModel(
            id: '',
            academyId: widget.academyId,
            ownerId: widget.ownerId,
            name: name,
            grade: grade,
            classNumber: classNumber == '' ? null : classNumber,
            studentNumber: studentNumber == '' ? null : studentNumber,
            session: session,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    setState(() {
      _parsedStudents = students;
      _isParsed = true;
    });
  }

  Future<void> _registerStudents() async {
    if (_parsedStudents.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<StudentProvider>();
      // StudentProvider에 batchAddStudents 같은 메서드가 있으면 좋겠지만,
      // 일단 반복문으로 처리 or provider에 추가 구현.
      // 성능을 위해 Provider에 bulk insert가 있으면 좋음.
      // 기존에 deleteStudents는 만들었으므로 addStudents도 만드는 것이 좋음.
      // 우선 여기서는 하나씩 추가하는 로직 대신, Provider에 메서드를 추가하는 방향으로 진행.
      // (Provider 수정 필요 시 여기서는 로직만 작성하고 나중에 수정)
      // 일단 Provider에 `addStudent`는 있으니 for문으로 호출하거나,
      // `createStudents`를 추가하도록 하겠음.

      // 임시로 for문 사용 (혹은 이 대화 턴 내에서 Provider 업데이트 예정)
      for (var student in _parsedStudents) {
        await provider.addStudent(student);
      }

      if (mounted) {
        Navigator.pop(context, true); // 성공
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
                child: const Text('이름  |  학년  |  반  |  번호  |  부(교시)'),
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
                  Text(
                    '총 ${_parsedStudents.length}명 인식됨',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isParsed = false;
                        _parsedStudents = [];
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('다시 입력'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _parsedStudents.isEmpty
                    ? const Center(child: Text('인식된 데이터가 없습니다.'))
                    : SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('이름')),
                            DataColumn(label: Text('학년')),
                            DataColumn(label: Text('반')),
                            DataColumn(label: Text('번호')),
                            DataColumn(label: Text('부')),
                          ],
                          rows: _parsedStudents.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    s.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Text(s.grade?.toString() ?? '-')),
                                DataCell(Text(s.classNumber ?? '-')),
                                DataCell(Text(s.studentNumber ?? '-')),
                                DataCell(Text(s.session?.toString() ?? '-')),
                              ],
                            );
                          }).toList(),
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
                  label: Text(_isLoading ? '등록 중...' : '일괄 등록하기'),
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
