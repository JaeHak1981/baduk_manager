import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/textbook_model.dart';
import '../providers/progress_provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 디버깅용
import 'add_textbook_screen.dart';

/// 교재 센터 화면 (기관별 교재 목록 조회 및 권수별 할당)
class TextbookCenterScreen extends StatefulWidget {
  final AcademyModel academy;
  final String? studentId; // 특정 학생에게 할당할 경우 전달

  const TextbookCenterScreen({
    super.key,
    required this.academy,
    this.studentId,
  });

  @override
  State<TextbookCenterScreen> createState() => _TextbookCenterScreenState();
}

class _TextbookCenterScreenState extends State<TextbookCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().loadOwnerTextbooks(
        widget.academy.ownerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교재 관리 센터'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<ProgressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null &&
              provider.allOwnerTextbooks.isEmpty) {
            return _buildErrorState(provider.errorMessage!);
          }

          if (provider.allOwnerTextbooks.isEmpty) {
            return _buildEmptyState();
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () =>
                    provider.loadOwnerTextbooks(widget.academy.ownerId),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: () {
                    var list = provider.allOwnerTextbooks;
                    if (widget.academy.usingTextbookIds.isNotEmpty) {
                      list = list
                          .where(
                            (t) =>
                                widget.academy.usingTextbookIds.contains(t.id),
                          )
                          .toList();
                    }
                    return list.length;
                  }(),
                  itemBuilder: (context, index) {
                    var list = provider.allOwnerTextbooks;
                    if (widget.academy.usingTextbookIds.isNotEmpty) {
                      list = list
                          .where(
                            (t) =>
                                widget.academy.usingTextbookIds.contains(t.id),
                          )
                          .toList();
                    }
                    final textbook = list[index];
                    final isCustom = textbook.ownerId != 'common';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          Icons.menu_book,
                          color: isCustom ? Colors.blue : Colors.orange,
                        ),
                        title: Text(
                          textbook.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('총 ${textbook.totalVolumes}권'),
                        trailing: widget.studentId != null
                            ? ElevatedButton(
                                onPressed: provider.isAssigning
                                    ? null
                                    : () => _pickVolumeAndAssign(
                                        context,
                                        textbook,
                                      ),
                                child:
                                    provider.isAssigning &&
                                        widget.studentId != null
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('할당'),
                              )
                            : (isCustom
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () => _navigateToEdit(
                                            context,
                                            textbook,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () =>
                                              _confirmDelete(context, textbook),
                                        ),
                                      ],
                                    )
                                  : null),
                      ),
                    );
                  },
                ),
              ),
              if (provider.isAssigning)
                Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
      floatingActionButton: widget.studentId == null
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToRegister(context),
              label: const Text('새 교재 등록'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('아직 등록된 교재가 없습니다'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToRegister(context),
            icon: const Icon(Icons.add),
            label: const Text('우리 학원 교재 등록하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('복사되었습니다')));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('에러 복사'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTextbookScreen(academy: widget.academy),
      ),
    ).then((_) {
      if (mounted)
        context.read<ProgressProvider>().loadOwnerTextbooks(
          widget.academy.ownerId,
        );
    });
  }

  void _navigateToEdit(BuildContext context, TextbookModel textbook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTextbookScreen(academy: widget.academy, textbook: textbook),
      ),
    ).then((_) {
      if (mounted)
        context.read<ProgressProvider>().loadOwnerTextbooks(
          widget.academy.ownerId,
        );
    });
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TextbookModel textbook,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('교재 삭제'),
        content: Text(
          '[${textbook.name}] 교재를 삭제하시겠습니까?\n이 교재를 학습 중인 학생들의 기록에 영향을 줄 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ProgressProvider>().deleteAcademyTextbook(
        textbook.id,
        widget.academy.ownerId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('교재가 삭제되었습니다')));
      }
    }
  }

  /// 권수 및 페이지 선택 팝업 후 할당
  Future<void> _pickVolumeAndAssign(
    BuildContext context,
    TextbookModel textbook,
  ) async {
    int selectedVolume = 1;
    final volumesCount = textbook.totalVolumes;

    // 디버그 로그 추가
    print('DEBUG: Assigning textbook...');
    try {
      final curUid = FirebaseAuth.instance.currentUser?.uid;
      print('DEBUG: Current User ID: $curUid');
      print('DEBUG: Academy ID: ${widget.academy.id}');
      print('DEBUG: Academy Owner ID: ${widget.academy.ownerId}');
      print('DEBUG: Student ID: ${widget.studentId}');
    } catch (e) {
      print('DEBUG: Error printing debug info: $e');
    }

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${textbook.name} 할당'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('학습할 권수를 선택해 주세요:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: selectedVolume,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '권수',
              ),
              items: List.generate(volumesCount, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v권')))
                  .toList(),
              onChanged: (val) => selectedVolume = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, selectedVolume);
            },
            child: const Text('할당하기'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      // 이전에 발생했을 수 있는 에러 메시지 초기화
      context.read<ProgressProvider>().clearErrorMessage();

      final success = await context.read<ProgressProvider>().assignVolume(
        studentId: widget.studentId!,
        academyId: widget.academy.id,
        ownerId: widget.academy.ownerId,
        textbook: textbook,
        volumeNumber: result,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$result권이 할당되었습니다')));
          Navigator.pop(context);
        } else {
          final errorMsg =
              context.read<ProgressProvider>().errorMessage ?? '할당에 실패했습니다.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류: $errorMsg'),
              duration: const Duration(seconds: 10),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: '확인',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }
}
