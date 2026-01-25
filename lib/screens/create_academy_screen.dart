import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../providers/academy_provider.dart';
import '../providers/auth_provider.dart';

/// 기관 등록/수정 화면
class CreateAcademyScreen extends StatefulWidget {
  final AcademyModel? academy;

  const CreateAcademyScreen({super.key, this.academy});

  @override
  State<CreateAcademyScreen> createState() => _CreateAcademyScreenState();
}

class _CreateAcademyScreenState extends State<CreateAcademyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  late AcademyType _selectedType;
  int _selectedSessions = 1;
  final List<int> _selectedDays = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _daysOfWeek = [
    {'id': 1, 'label': '월'},
    {'id': 2, 'label': '화'},
    {'id': 3, 'label': '수'},
    {'id': 4, 'label': '목'},
    {'id': 5, 'label': '금'},
    {'id': 6, 'label': '토'},
    {'id': 7, 'label': '일'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.academy?.name ?? '');
    _selectedType = widget.academy?.type ?? AcademyType.academy;
    _selectedSessions =
        widget.academy?.totalSessions ??
        (_selectedType == AcademyType.school ? 4 : 1);
    if (widget.academy != null) {
      _selectedDays.addAll(widget.academy!.lessonDays);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final academyProvider = context.read<AcademyProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      }
      return;
    }

    setState(() => _isLoading = true);
    _selectedDays.sort(); // 정렬해서 저장

    try {
      bool success;
      if (widget.academy != null) {
        // 수정 모드
        final updatedAcademy = widget.academy!.copyWith(
          name: _nameController.text.trim(),
          type: _selectedType,
          totalSessions: _selectedSessions,
          lessonDays: List<int>.from(_selectedDays),
        );
        success = await academyProvider.updateAcademy(updatedAcademy);
      } else {
        // 등록 모드
        success = await academyProvider.createAcademy(
          name: _nameController.text.trim(),
          type: _selectedType,
          ownerId: currentUser.uid,
          totalSessions: _selectedSessions,
          lessonDays: List<int>.from(_selectedDays),
        );
      }

      if (mounted) {
        if (success) {
          // 성공 시 다이얼로그 표시 (사용자 요청 반영: "수정 완료")
          final shouldPop = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('완료'),
              content: Text(widget.academy != null ? '수정 완료' : '등록 완료'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('확인'),
                ),
              ],
            ),
          );

          // 다이얼로그 결과가 true(확인 클릭)이고 화면이 아직 붙어있다면 화면을 닫음
          if (mounted && shouldPop == true) {
            Navigator.pop(context, true);
          }
        } else {
          // Provider에서 설정한 에러 메시지 표시
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('오류'),
              content: Text(academyProvider.errorMessage ?? '처리에 실패했습니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Submission Error: $e');
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('시스템 오류'),
            content: Text('통신 중 문제가 발생했습니다: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.academy != null ? '기관 수정' : '기관 등록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: '홈으로 이동',
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
              // 기관 타입 선택
              Text(
                '기관 타입',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...AcademyType.values.map((type) {
                return RadioListTile<AcademyType>(
                  title: Row(
                    children: [
                      Icon(
                        type.icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(type.displayName),
                    ],
                  ),
                  value: type,
                  groupValue: _selectedType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        // 학교면 기본 4부, 아니면 1부로 자동 제안 (사용자가 수정 가능)
                        _selectedSessions = value == AcademyType.school ? 4 : 1;
                      });
                    }
                  },
                );
              }),

              const SizedBox(height: 24),

              // 수업 요일 선택
              Text(
                '수업 요일 (중복 선택 가능)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: _daysOfWeek.map((day) {
                  final isSelected = _selectedDays.contains(day['id']);
                  return FilterChip(
                    label: Text(day['label']),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day['id']);
                        } else {
                          _selectedDays.remove(day['id']);
                        }
                      });
                    },
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  );
                }).toList(),
              ),
              if (_selectedDays.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '주 ${_selectedDays.length}회 수업',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 총 운영 부수
              Text(
                '총 운영 부수',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedSessions,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                items: List.generate(4, (i) => i + 1)
                    .map((s) => DropdownMenuItem(value: s, child: Text('$s부')))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSessions = val!),
              ),

              const SizedBox(height: 24),

              // 기관명
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '기관명',
                  hintText: '예: 서울바둑학원',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '기관명을 입력해주세요';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.academy != null ? '수정 완료' : '등록하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
