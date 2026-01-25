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
  late bool _isCompleted;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.progress.isCompleted;
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);

    final success = await context.read<ProgressProvider>().updateVolumeStatus(
      widget.progress.id,
      widget.progress.studentId,
      _isCompleted,
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('진도 기록 삭제'),
        content: const Text('이 교재의 학습 기록을 삭제하시겠습니까?\n잘못 할당된 경우에만 삭제해 주세요.'),
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
      final success = await context.read<ProgressProvider>().removeProgress(
        widget.progress.id,
        widget.progress.studentId,
      );
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('진도 기록이 삭제되었습니다')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('진도 업데이트'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _isLoading ? null : _confirmDelete,
            tooltip: '기록 삭제',
          ),
        ],
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
              '현재 ${widget.progress.volumeNumber}권 / 총 ${widget.progress.totalVolumes}권',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),

            Center(
              child: Column(
                children: [
                  Text(
                    _isCompleted ? '학습 완료' : '학습 중',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isCompleted ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Transform.scale(
                    scale: 1.5,
                    child: Switch(
                      value: _isCompleted,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() => _isCompleted = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isCompleted ? '이 권의 학습을 마쳤습니다.' : '아직 학습을 진행하고 있습니다.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCompleted ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '저장하기',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
