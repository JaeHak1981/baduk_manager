import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import 'package:provider/provider.dart';

class BatchAttendanceDialog extends StatefulWidget {
  final StudentModel student;
  final String academyId;
  final String ownerId;
  final DateTime initialDate;

  const BatchAttendanceDialog({
    super.key,
    required this.student,
    required this.academyId,
    required this.ownerId,
    required this.initialDate,
  });

  @override
  State<BatchAttendanceDialog> createState() => _BatchAttendanceDialogState();
}

class _BatchAttendanceDialogState extends State<BatchAttendanceDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  AttendanceType _selectedType = AttendanceType.absent;
  bool _skipWeekends = true;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _endDate = widget.initialDate.add(const Duration(days: 4)); // 기본 5일(한 주)
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '일괄 처리 기간 선택',
      saveText: '선택됨',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('[${widget.student.name}] 기간별 일괄 출결'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('기간 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_startDate.year}.${_startDate.month}.${_startDate.day} ~ ${_endDate.year}.${_endDate.month}.${_endDate.day}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('출결 상태', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusChip(AttendanceType.absent, '결석', Colors.red),
                _buildStatusChip(
                  AttendanceType.manual,
                  '공결/기타',
                  Colors.blueGrey,
                ),
                _buildStatusChip(AttendanceType.late, '지각', Colors.orange),
              ],
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text('주말(토/일) 제외'),
              value: _skipWeekends,
              onChanged: (val) => setState(() => _skipWeekends = val ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            final provider = context.read<AttendanceProvider>();
            final success = await provider.updateAttendanceForPeriod(
              studentId: widget.student.id,
              academyId: widget.academyId,
              ownerId: widget.ownerId,
              startDate: _startDate,
              endDate: _endDate,
              type: _selectedType,
              skipWeekends: _skipWeekends,
            );

            if (success && mounted) {
              Navigator.pop(context, true);
            }
          },
          child: const Text('일괄 적용'),
        ),
      ],
    );
  }

  Widget _buildStatusChip(AttendanceType type, String label, Color color) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      onSelected: (selected) {
        if (selected) setState(() => _selectedType = type);
      },
    );
  }
}
