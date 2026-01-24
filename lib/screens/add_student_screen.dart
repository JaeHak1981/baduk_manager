import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';

/// 학생 등록/수정 화면
class AddStudentScreen extends StatefulWidget {
  final AcademyModel academy;
  final StudentModel? student;

  const AddStudentScreen({super.key, required this.academy, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _birthDateController;
  late TextEditingController _phoneController;
  late TextEditingController _gradeController;
  late TextEditingController _classController;
  late TextEditingController _studentNumberController;
  late TextEditingController _noteController;

  late int _selectedLevel;
  int? _selectedSession;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?.name ?? '');
    _birthDateController = TextEditingController(text: s?.birthDate ?? '');
    _phoneController = TextEditingController(text: s?.parentPhone ?? '');
    _gradeController = TextEditingController(text: s?.grade?.toString() ?? '');
    _classController = TextEditingController(text: s?.classNumber ?? '');
    _studentNumberController = TextEditingController(
      text: s?.studentNumber ?? '',
    );
    _noteController = TextEditingController(text: s?.note ?? '');

    _selectedLevel = s?.level ?? 30;
    _selectedSession = s?.session;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _gradeController.dispose();
    _classController.dispose();
    _studentNumberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = context.read<StudentProvider>();

    try {
      if (widget.student != null) {
        // 수정 모드
        final updatedStudent = widget.student!.copyWith(
          ownerId: widget.academy.ownerId, // 소유자 ID 유지
          name: _nameController.text.trim(),
          birthDate: _birthDateController.text.trim().isEmpty
              ? null
              : _birthDateController.text.trim(),
          parentPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          level: _selectedLevel,
          session: _selectedSession,
          grade: int.tryParse(_gradeController.text),
          classNumber: _classController.text.trim().isEmpty
              ? null
              : _classController.text.trim(),
          studentNumber: _studentNumberController.text.trim().isEmpty
              ? null
              : _studentNumberController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
        await provider.updateStudent(updatedStudent);
      } else {
        // 등록 모드
        final newStudent = StudentModel(
          id: '', // Firestore에서 자동 생성
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
          name: _nameController.text.trim(),
          birthDate: _birthDateController.text.trim().isEmpty
              ? null
              : _birthDateController.text.trim(),
          parentPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          level: _selectedLevel,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          session: _selectedSession,
          grade: int.tryParse(_gradeController.text),
          classNumber: _classController.text.trim().isEmpty
              ? null
              : _classController.text.trim(),
          studentNumber: _studentNumberController.text.trim().isEmpty
              ? null
              : _studentNumberController.text.trim(),
          createdAt: DateTime.now(),
        );

        await provider.addStudent(newStudent);
      }

      if (mounted) {
        final error = provider.errorMessage;
        setState(() => _isLoading = false);

        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.student != null ? '정보가 수정되었습니다' : '학생이 등록되었습니다',
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학생 삭제'),
        content: Text(
          '[${widget.student!.name}] 학생의 모든 정보를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
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
      setState(() => _isLoading = true);
      final success = await context.read<StudentProvider>().deleteStudent(
        widget.student!.id,
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('학생이 삭제되었습니다')));
          Navigator.pop(context);
        } else {
          final error = context.read<StudentProvider>().errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error ?? '삭제 실패'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student != null ? '학생 정보 수정' : '학생 등록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (widget.student != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _handleDelete(context),
              tooltip: '학생 삭제',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '학생 이름 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? '이름을 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                '학교 정보 (선택사항)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int?>(
                      value: _selectedSession,
                      decoration: const InputDecoration(
                        labelText: '부',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('선택안함'),
                        ),
                        ...List.generate(
                          widget.academy.totalSessions,
                          (i) => i + 1,
                        ).map(
                          (s) => DropdownMenuItem(value: s, child: Text('$s부')),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedSession = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _gradeController,
                      decoration: const InputDecoration(
                        labelText: '학년',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _classController,
                      decoration: const InputDecoration(
                        labelText: '반',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _studentNumberController,
                      decoration: const InputDecoration(
                        labelText: '번호',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _birthDateController,
                      decoration: const InputDecoration(
                        labelText: '생년월일',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedLevel,
                      decoration: const InputDecoration(
                        labelText: '급수',
                        border: OutlineInputBorder(),
                      ),
                      menuMaxHeight: 300,
                      items: [
                        // 급: 30급 ~ 1급
                        ...List.generate(30, (i) => 30 - i).map(
                          (level) => DropdownMenuItem(
                            value: level,
                            child: Text(
                              '$level급',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        // 단: 1단 ~ 9단 (내부적으로 0 ~ -8로 저장)
                        ...List.generate(9, (i) => i).map(
                          (i) => DropdownMenuItem(
                            value: -i, // 0 -> 1단, -1 -> 2단, ...
                            child: Text(
                              '${i + 1}단',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedLevel = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '보호자 연락처',
                  hintText: '010-0000-0000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          widget.student != null ? '정보 수정하기' : '학생 등록하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (widget.student != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _isLoading ? null : () => _handleDelete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      '학생 정보 삭제하기',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
