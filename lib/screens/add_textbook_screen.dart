import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/textbook_model.dart'; // Added this import
import '../providers/progress_provider.dart';

/// 교재 등록/수정 화면
class AddTextbookScreen extends StatefulWidget {
  final AcademyModel academy;
  final TextbookModel? textbook; // 수정 시에만 전달

  const AddTextbookScreen({super.key, required this.academy, this.textbook});

  @override
  State<AddTextbookScreen> createState() => _AddTextbookScreenState();
}

class _AddTextbookScreenState extends State<AddTextbookScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _volumesController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.textbook?.name ?? '');
    _volumesController = TextEditingController(
      text: widget.textbook?.totalVolumes.toString() ?? '1',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _volumesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool success;
    String successMessage;

    if (widget.textbook != null) {
      // 수정 모드
      success = await context.read<ProgressProvider>().editTextbook(
        textbookId: widget.textbook!.id,
        ownerId: widget.academy.ownerId,
        name: _nameController.text.trim(),
        totalVolumes: int.parse(_volumesController.text),
      );
      successMessage = '교재 정보가 수정되었습니다';
    } else {
      // 등록 모드
      success = await context.read<ProgressProvider>().registerTextbook(
        ownerId: widget.academy.ownerId,
        name: _nameController.text.trim(),
        totalVolumes: int.parse(_volumesController.text),
      );
      successMessage = '교재 시리즈가 등록되었습니다';
    }

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
        Navigator.pop(context);
      } else {
        final error = context.read<ProgressProvider>().errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? '등록 실패'),
            backgroundColor: Colors.red,
            action: error != null
                ? SnackBarAction(
                    label: '복사',
                    textColor: Colors.white,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: error));
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.textbook != null ? '교재 정보 수정' : '새 교재 등록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '교재 이름 (시리즈명) *',
                  hintText: '예: 창의 바둑, 기초 전술',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? '이름을 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _volumesController,
                      decoration: const InputDecoration(
                        labelText: '전체 권수 (시리즈 끝 번호) *',
                        hintText: '예: 12 (1~12권)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                          ? '1권 이상이어야 합니다'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          '교재 등록하기',
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
