import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/student_progress_model.dart';
import '../providers/progress_provider.dart';

/// 진도 수정 화면
class ProgressEditScreen extends StatefulWidget {
  final StudentProgressModel progress;

  const ProgressEditScreen({super.key, required this.progress});

  @override
  State<ProgressEditScreen> createState() => _ProgressEditScreenState();
}

class _ProgressEditScreenState extends State<ProgressEditScreen> {
  late TextEditingController _pageController;
  late int _currentPage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.progress.currentPage;
    _pageController = TextEditingController(text: _currentPage.toString());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newPage = int.tryParse(_pageController.text);
    if (newPage == null ||
        newPage < 0 ||
        newPage > widget.progress.totalPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('0에서 ${widget.progress.totalPages} 사이의 숫자를 입력해주세요'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await context.read<ProgressProvider>().updateCurrentPage(
      widget.progress.id,
      widget.progress.studentId,
      newPage,
      widget.progress.totalPages,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        final error = context.read<ProgressProvider>().errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? '진도 업데이트 실패'),
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
        title: const Text('진도 업데이트'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.progress.textbookName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '전체 페이지: ${widget.progress.totalPages}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            Text('현재 기록된 페이지: ${widget.progress.currentPage}'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _pageController,
              decoration: const InputDecoration(
                labelText: '진행 중인 페이지',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),

            const SizedBox(height: 32),

            // 프리셋 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickButton(-5),
                _buildQuickButton(-1),
                _buildQuickButton(1),
                _buildQuickButton(5),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        '저장하기',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(int delta) {
    return ActionChip(
      label: Text(delta > 0 ? '+$delta' : '$delta'),
      onPressed: () {
        final val = int.tryParse(_pageController.text) ?? 0;
        _pageController.text = (val + delta)
            .clamp(0, widget.progress.totalPages)
            .toString();
      },
    );
  }
}
