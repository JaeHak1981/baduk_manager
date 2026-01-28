import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/student_progress_model.dart';
import '../providers/progress_provider.dart';

class StudentHistoryTable extends StatefulWidget {
  final String studentId;
  final String ownerId;

  const StudentHistoryTable({
    super.key,
    required this.studentId,
    required this.ownerId,
  });

  @override
  State<StudentHistoryTable> createState() => _StudentHistoryTableState();
}

class _StudentHistoryTableState extends State<StudentHistoryTable> {
  final Set<String> _selectedIds = {};

  void _toggleSelectAll(List<StudentProgressModel> history) {
    setState(() {
      if (_selectedIds.length == history.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(history.map((p) => p.id));
      }
    });
  }

  Future<void> _handleBulkComplete() async {
    // 일괄 완료 로직 (필요 시 구현)
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일괄 삭제'),
        content: Text('선택한 ${_selectedIds.length}개의 기록을 삭제하시겠습니까?'),
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
      final provider = context.read<ProgressProvider>();
      debugPrint(
        '🚀🚀🚀 [StudentHistoryTable] Bulk delete started for ${_selectedIds.length} items',
      );

      for (var id in _selectedIds) {
        try {
          final success = await provider.removeProgress(
            id,
            widget.studentId,
            ownerId: widget.ownerId,
          );
          debugPrint(
            '🚀🚀🚀 [StudentHistoryTable] Delete item $id result: $success',
          );
        } catch (e) {
          debugPrint('❌❌❌ [StudentHistoryTable] ERROR deleting $id: $e');
        }
      }
      setState(() => _selectedIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, provider, child) {
        final history = provider.getProgressForStudent(widget.studentId);

        if (history.isEmpty) {
          return const Center(child: Text('학습 이력이 없습니다.'));
        }

        return Column(
          children: [
            if (_selectedIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length}개 선택됨',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _handleBulkComplete,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 18,
                      ),
                      label: const Text(
                        '일괄 완료',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _handleBulkDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: const Text(
                        '일괄 삭제',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 24,
                    columns: [
                      DataColumn(
                        label: Checkbox(
                          value:
                              _selectedIds.isNotEmpty &&
                              _selectedIds.length == history.length,
                          onChanged: (_) => _toggleSelectAll(history),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '순번',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '교재명',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '권수',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '할당일',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '완료일',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '상태',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          '작업',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: List.generate(history.length, (index) {
                      final p = history[index];
                      final isSelected = _selectedIds.contains(p.id);

                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: (val) {
                          setState(() {
                            if (val == true)
                              _selectedIds.add(p.id);
                            else
                              _selectedIds.remove(p.id);
                          });
                        },
                        cells: [
                          DataCell(
                            const SizedBox.shrink(),
                          ), // DataTable 자체 선택 기능 사용 위해 비워둠
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(p.textbookName)),
                          DataCell(Text('${p.volumeNumber}권')),
                          DataCell(
                            Text(DateFormat('yy-MM-dd').format(p.startDate)),
                          ),
                          DataCell(
                            Text(
                              p.endDate != null
                                  ? DateFormat('yy-MM-dd').format(p.endDate!)
                                  : '-',
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: p.isCompleted
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.isCompleted ? '완료' : '학습 중',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.isCompleted
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            p.isCompleted
                                ? TextButton.icon(
                                    onPressed: () async {
                                      final success = await provider
                                          .restoreProgress(
                                            p.id,
                                            widget.studentId,
                                            ownerId: widget.ownerId,
                                          );
                                      if (success && mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('학습 상태가 복원되었습니다.'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.restore, size: 16),
                                    label: const Text(
                                      '복원',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  )
                                : const Text(
                                    '-',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
