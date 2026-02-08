import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/schedule_provider.dart';
import '../../utils/holiday_helper.dart';
import '../../config/app_theme.dart';
import 'package:provider/provider.dart';
import 'batch_holiday_dialog.dart';

class AttendanceCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime focusedDay;
  final String academyId;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final Function(DateTime focusedDay) onPageChanged;

  const AttendanceCalendar({
    super.key,
    required this.selectedDate,
    required this.focusedDay,
    required this.academyId,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();

    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(20, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(right: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: AppTheme.heading2,
              leftChevronIcon: Icon(Icons.chevron_left, size: 20),
              rightChevronIcon: Icon(Icons.chevron_right, size: 20),
              headerPadding: EdgeInsets.symmetric(vertical: 4),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekendStyle: TextStyle(color: Colors.red),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              weekendTextStyle: const TextStyle(color: Colors.red),
              holidayTextStyle: const TextStyle(color: Colors.red),
              outsideDaysVisible: false,
            ),
            holidayPredicate: (day) =>
                HolidayHelper.isHoliday(day) ||
                scheduleProvider.isDateHoliday(day),
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('학원 휴강 설정', style: AppTheme.caption),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: scheduleProvider.isDateHoliday(selectedDate),
                        onChanged: (value) async {
                          await scheduleProvider.toggleHoliday(
                            academyId: academyId,
                            year: selectedDate.year,
                            month: selectedDate.month,
                            day: selectedDate.day,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        '선택한 날짜를 휴강으로 지정합니다.',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(50, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => BatchHolidayDialog(
                            academyId: academyId,
                            initialDate: selectedDate,
                          ),
                        );
                        if (result == true && context.mounted) {
                          // 필요한 추가 작업 수행
                        }
                      },
                      child: const Text(
                        '[기간 설정]',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
