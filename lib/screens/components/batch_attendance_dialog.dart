import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../config/app_theme.dart';

class BatchAttendanceDialog extends StatefulWidget {
  final StudentModel student;
  final String academyId;
  final String ownerId;
  final DateTime initialDate;
  final List<int> lessonDays;

  const BatchAttendanceDialog({
    super.key,
    required this.student,
    required this.academyId,
    required this.ownerId,
    required this.initialDate,
    required this.lessonDays,
  });

  @override
  State<BatchAttendanceDialog> createState() => _BatchAttendanceDialogState();
}

class _BatchAttendanceDialogState extends State<BatchAttendanceDialog> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  AttendanceType _selectedType = AttendanceType.absent;
  bool _applyOnlyLessonDays = true;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _rangeStart = widget.initialDate;
    _rangeEnd = widget.initialDate.add(const Duration(days: 4));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month + 1,
      0,
    );

    return AlertDialog(
      title: Text('[${widget.student.name}] 기간별 일괄 출결'),
      content: SizedBox(
        width: 350, // 달력이 잘리지 않도록 너비 확보
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. 기간 선택', style: AppTheme.heading2),
              const SizedBox(height: 8),
              // 다이얼로그 내 직접 달력 노출
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TableCalendar(
                  locale: 'ko_KR',
                  firstDay: firstDayOfMonth,
                  lastDay: lastDayOfMonth,
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_rangeStart, day),
                  rangeStartDay: _rangeStart,
                  rangeEndDay: _rangeEnd,
                  rangeSelectionMode: RangeSelectionMode.enforced,
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                    rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                  ),
                  daysOfWeekHeight: 20,
                  rowHeight: 35,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    rangeStartDecoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    rangeEndDecoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    rangeHighlightColor: AppTheme.primaryColor.withOpacity(0.1),
                    withinRangeTextStyle: const TextStyle(color: Colors.black),
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(fontSize: 12),
                    weekendTextStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                  onRangeSelected: (start, end, focusedDay) {
                    setState(() {
                      _rangeStart = start;
                      _rangeEnd = end;
                      _focusedDay = focusedDay;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('2. 출결 상태', style: AppTheme.heading2),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusChip(AttendanceType.absent, '결석', Colors.red),
                  _buildStatusChip(AttendanceType.present, '출석', Colors.green),
                ],
              ),
              const SizedBox(height: 20),
              const Text('3. 비고 (사유)', style: AppTheme.heading2),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: '예: 가족 여행, 병가 등',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('수업 일수만 적용 (권장)'),
                subtitle: const Text(
                  '정해진 수업 요일에만 출결을 기록합니다.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _applyOnlyLessonDays,
                onChanged: (val) =>
                    setState(() => _applyOnlyLessonDays = val ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_rangeStart == null || _rangeEnd == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('기간을 선택해주세요.')));
              return;
            }
            final provider = context.read<AttendanceProvider>();
            final success = await provider.updateAttendanceForPeriod(
              studentId: widget.student.id,
              academyId: widget.academyId,
              ownerId: widget.ownerId,
              startDate: _rangeStart!,
              endDate: _rangeEnd!,
              type: _selectedType,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              lessonDays: widget.lessonDays,
              applyOnlyLessonDays: _applyOnlyLessonDays,
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
