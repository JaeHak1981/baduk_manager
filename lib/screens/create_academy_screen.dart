import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../providers/academy_provider.dart';
import '../providers/auth_provider.dart';

/// 기관 등록 화면
class CreateAcademyScreen extends StatefulWidget {
  const CreateAcademyScreen({super.key});

  @override
  State<CreateAcademyScreen> createState() => _CreateAcademyScreenState();
}

class _CreateAcademyScreenState extends State<CreateAcademyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  AcademyType _selectedType = AcademyType.academy;
  bool _isLoading = false;

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

    final success = await academyProvider.createAcademy(
      name: _nameController.text.trim(),
      type: _selectedType,
      ownerId: currentUser.uid,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기관이 등록되었습니다')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(academyProvider.errorMessage ?? '기관 등록 실패'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기관 등록'),
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
                      setState(() => _selectedType = value);
                    }
                  },
                );
              }),

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
                      : const Text(
                          '등록하기',
                          style: TextStyle(
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
