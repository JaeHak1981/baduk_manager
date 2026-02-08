import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/schedule_provider.dart';
import '../../config/app_theme.dart';

class BatchHolidayDialog extends StatefulWidget {
  final String academyId;
  final DateTime initialDate;

  const BatchHolidayDialog({
    super.key,
    required this.academyId,
    required this.initialDate,
  });

  @override
  State<BatchHolidayDialog> createState() => _BatchHolidayDialogState();
}

class _BatchHolidayDialogState extends State<BatchHolidayDialog> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _rangeStart = widget.initialDate;
    _rangeEnd = widget.initialDate.add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('기간별 휴강 설정'),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. 휴강 기간 선택', style: AppTheme.heading2),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TableCalendar(
                  locale: 'ko_KR',
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2030),
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
                  ),
                  daysOfWeekHeight: 20,
                  rowHeight: 35,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    rangeStartDecoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    rangeEndDecoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    rangeHighlightColor: Colors.red.withOpacity(0.1),
                    withinRangeTextStyle: const TextStyle(color: Colors.red),
                    outsideDaysVisible: false,
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
              const Text('2. 휴강 사유', style: AppTheme.heading2),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: '예: 여름방학 등 (공백 시 "휴강"으로 표시)',
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
              const Text(
                '※ 설정된 기간은 모든 학생의 출석부에서 휴강으로 표시되며, 별도의 출결 입력이 차단됩니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            if (_rangeStart == null || _rangeEnd == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('기간을 선택해주세요.')));
              return;
            }
            final provider = context.read<ScheduleProvider>();
            await provider.setHolidayRange(
              academyId: widget.academyId,
              startDate: _rangeStart!,
              endDate: _rangeEnd!,
              reason: _reasonController.text.trim().isEmpty
                  ? '휴강'
                  : _reasonController.text.trim(),
            );

            if (mounted) {
              Navigator.pop(context, true);
            }
          },
          child: const Text('기간 휴강 적용'),
        ),
      ],
    );
  }
}
