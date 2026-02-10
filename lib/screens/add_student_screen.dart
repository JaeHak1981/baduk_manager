import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../constants/ui_constants.dart';

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
  DateTime _startDate = DateTime.now();
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final now = DateTime.now();
      if (widget.student != null) {
        // 수정 모드
        var updatedStudent = widget.student!.copyWith(
          ownerId: widget.academy.ownerId,
          name: _nameController.text.trim(),
          birthDate: _birthDateController.text.trim().isEmpty
              ? null
              : _birthDateController.text.trim(),
          parentPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          level: _selectedLevel,
          session: _selectedSession, // Legacy 필드도 일단 유지
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
          updatedAt: now,
        );

        // 만약 세션이 변경되었고 이력이 비어있다면 (마이그레이션 전 데이터 등)
        // 현재 시점의 이력을 하나 추가해줌 (정합성 유지)
        if (updatedStudent.sessionHistory.isEmpty && _selectedSession != null) {
          updatedStudent = updatedStudent.copyWith(
            sessionHistory: [
              SessionHistory(effectiveDate: now, sessionId: _selectedSession!),
            ],
          );
        }

        await provider.updateStudent(updatedStudent);
      } else {
        // 등록 모드
        final createdAt = now;
        final initialSession = _selectedSession ?? 0;

        final newStudent = StudentModel(
          id: '',
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
          session: initialSession,
          grade: int.tryParse(_gradeController.text),
          classNumber: _classController.text.trim().isEmpty
              ? null
              : _classController.text.trim(),
          studentNumber: _studentNumberController.text.trim().isEmpty
              ? null
              : _studentNumberController.text.trim(),
          createdAt: createdAt,
          // [MODIFIED] 시작일을 사용자가 선택한 날짜로 설정
          enrollmentHistory: [EnrollmentPeriod(startDate: _startDate)],
          sessionHistory: [
            SessionHistory(
              effectiveDate: _startDate,
              sessionId: initialSession,
            ),
          ],
        );

        await provider.addStudent(newStudent);
      }

      if (!context.mounted) return;
      final error = provider.errorMessage;
      setState(() => _isLoading = false);

      if (error == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.student != null ? '정보가 수정되었습니다' : '학생이 등록되었습니다',
            ),
          ),
        );
        navigator.pop();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
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
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      setState(() => _isLoading = true);
      final provider = context.read<StudentProvider>();
      final success = await provider.deleteStudent(
        widget.student!.id,
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      if (!context.mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        messenger.showSnackBar(const SnackBar(content: Text('학생이 삭제되었습니다')));
        navigator.pop();
      } else {
        final error = provider.errorMessage;
        messenger.showSnackBar(
          SnackBar(
            content: Text(error ?? '삭제 실패'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 부 이동 예약 다이얼로그
  Future<void> _showSessionReservation() async {
    final s = widget.student;
    if (s == null) return;

    DateTime effectiveDate = DateTime.now().add(const Duration(days: 1));
    int targetSession = _selectedSession ?? 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('부 이동 예약'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('이동할 부와 적용 날짜를 선택하세요.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: targetSession,
                decoration: const InputDecoration(
                  labelText: '이동할 부',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(widget.academy.totalSessions, (i) => i + 1)
                    .map(
                      (val) =>
                          DropdownMenuItem(value: val, child: Text('$val부')),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => targetSession = val);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('적용 시작일'),
                subtitle: Text(
                  '${effectiveDate.year}-${effectiveDate.month}-${effectiveDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: effectiveDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null)
                    setDialogState(() => effectiveDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('예약 등록'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final newHistory = List<SessionHistory>.from(s.sessionHistory);
      newHistory.add(
        SessionHistory(effectiveDate: effectiveDate, sessionId: targetSession),
      );

      final updated = s.copyWith(sessionHistory: newHistory);
      await context.read<StudentProvider>().updateStudent(updated);
      if (mounted) Navigator.pop(context);
    }
  }

  /// 퇴원 예약 다이얼로그
  Future<void> _showRetireReservation() async {
    final s = widget.student;
    if (s == null) return;

    DateTime retireDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('퇴원 예약'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('수강 종료(퇴원) 날짜를 선택하세요.\n해당 날짜까지는 명단에 포함됩니다.'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('퇴원 예정일'),
                subtitle: Text(
                  '${retireDate.year}-${retireDate.month}-${retireDate.day}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: retireDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => retireDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('퇴원 예정 등록'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final history = List<EnrollmentPeriod>.from(s.enrollmentHistory);
      if (history.isEmpty) {
        // 이력이 없으면 신규로 하나 만들어줌 (마이그레이션 대응)
        history.add(
          EnrollmentPeriod(startDate: s.createdAt, endDate: retireDate),
        );
      } else {
        // 가장 최근 이력의 종료일을 설정
        final last = history.last;
        history[history.length - 1] = EnrollmentPeriod(
          startDate: last.startDate,
          endDate: retireDate,
        );
      }

      final updated = s.copyWith(
        enrollmentHistory: history,
        updatedAt: DateTime.now(),
      );
      await context.read<StudentProvider>().updateStudent(updated);
      if (mounted) Navigator.pop(context);
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
              if (widget.student == null) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                    ),
                    title: const Text('수강 시작일 (등록일)'),
                    subtitle: Text(
                      '${_startDate.year}-${_startDate.month}-${_startDate.day}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '* 오늘 이후 날짜를 선택하면 미래의 출석부에 자동 등재됩니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
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
              if (widget.student != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '예약 및 이력 관리',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSessionReservation,
                        icon: const Icon(Icons.schedule_send),
                        label: const Text('부 이동 예약'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showRetireReservation,
                        icon: const Icon(Icons.person_off_outlined),
                        label: const Text('퇴원 예약'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '* 예약 등록 시 미래 시점의 출결 및 교재 주문 명단에 자동 반영됩니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 16),
              // 버튼에 가려지지 않도록 하단부 여백 확보
              SizedBox(height: AppDimensions.getFormBottomInset(context)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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
                const SizedBox(height: 8),
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
