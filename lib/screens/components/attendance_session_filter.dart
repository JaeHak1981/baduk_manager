import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../config/app_theme.dart';

class AttendanceSessionFilter extends StatelessWidget {
  final int totalSessions;
  final int? selectedSession;
  final List<StudentModel> students;
  final int year;
  final int month;
  final DateTime? targetDate;
  final Function(int? session) onSessionSelected;
  final VoidCallback onSave;
  final bool hasPendingChanges;
  final List<Widget>? actions;

  const AttendanceSessionFilter({
    super.key,
    required this.totalSessions,
    required this.selectedSession,
    required this.students,
    required this.year,
    required this.month,
    this.targetDate,
    required this.onSessionSelected,
    required this.onSave,
    required this.hasPendingChanges,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  (() {
                    // 해당 연/월에 수강 중인 학생만 카운트 대상으로 정의
                    final filterDate = targetDate ?? DateTime(year, month, 1);
                    final enrolledStudents = students.where((s) {
                      return s.isEnrolledInMonth(year, month);
                    }).toList();

                    return Row(
                      children: [
                        ChoiceChip(
                          label: Text('전체(${enrolledStudents.length})'),
                          selected: selectedSession == null,
                          onSelected: (_) => onSessionSelected(null),
                        ),
                        (() {
                          final unassignedCount = enrolledStudents
                              .where(
                                (st) => (st.getSessionAt(filterDate) ?? 0) == 0,
                              )
                              .length;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text('미배정($unassignedCount)'),
                              selected: selectedSession == 0,
                              onSelected: (_) => onSessionSelected(0),
                            ),
                          );
                        })(),
                        ...List.generate(totalSessions, (i) => i + 1).map((s) {
                          // 해당 시점(filterDate)의 부 이력 기준으로 카운트
                          final count = enrolledStudents
                              .where(
                                (st) => (st.getSessionAt(filterDate) ?? 0) == s,
                              )
                              .length;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text('$s부($count)'),
                              selected: selectedSession == s,
                              onSelected: (_) => onSessionSelected(s),
                            ),
                          );
                        }),
                      ],
                    );
                  })(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: Icon(
              Icons.save,
              color: hasPendingChanges ? Colors.black : Colors.grey,
            ),
            label: Text(
              '저장하기',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasPendingChanges ? Colors.black : Colors.grey,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPendingChanges
                  ? AppTheme.accentColor
                  : Colors.grey.shade200,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: hasPendingChanges ? 2 : 0,
            ),
          ),
          if (actions != null) ...[const SizedBox(width: 12), ...actions!],
        ],
      ),
    );
  }
}
