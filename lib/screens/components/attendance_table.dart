import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../config/app_theme.dart';
import 'attendance_circular_toggle.dart';
import 'remark_cell.dart';
import 'batch_attendance_dialog.dart';

class AttendanceTable extends StatelessWidget {
  final List<StudentModel> students;
  final AttendanceProvider attendanceProvider;
  final Map<String, AttendanceRecord> attendanceMap;
  final DateTime selectedDate;
  final String ownerId;
  final bool isSelectionMode;
  final Set<String> selectedStudentIds;
  final String academyId;
  final List<int> lessonDays;
  final Function(String studentId) onStudentSelected;

  const AttendanceTable({
    super.key,
    required this.students,
    required this.attendanceProvider,
    required this.attendanceMap,
    required this.selectedDate,
    required this.ownerId,
    required this.isSelectionMode,
    required this.selectedStudentIds,
    required this.onStudentSelected,
    required this.academyId,
    required this.lessonDays,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(
        child: Text('해당 조건의 학생이 없습니다.', style: AppTheme.caption),
      );
    }

    final isWide = students.length > 10;

    if (isWide) {
      final halfLength = (students.length / 2).ceil();
      final leftColumn = students.take(halfLength).toList();
      final rightColumn = students.skip(halfLength).toList();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDataTable(context, leftColumn, 0)),
            const VerticalDivider(width: 1),
            const SizedBox(width: 8),
            Expanded(child: _buildDataTable(context, rightColumn, halfLength)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildDataTable(context, students, 0),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    List<StudentModel> chunk,
    int startOffset,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double noWidth = 30;
        const double nameWidth = 80;
        const double attendanceWidth = 50;
        const double batchWidth = 60;

        // 웹 버전에서 maxWidth가 Infinite일 경우를 대비한 방어 로직
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final double remarkWidth =
            (availableWidth -
                    (noWidth + nameWidth + attendanceWidth + batchWidth + 40))
                .clamp(100.0, 1200.0);

        return Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: noWidth,
                    child: Text(
                      'No.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: nameWidth,
                    child: Text(
                      '이름',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: attendanceWidth,
                    child: Center(
                      child: Text(
                        '출결',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: batchWidth,
                    child: Center(
                      child: Text(
                        '일괄',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '비고',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView.builder(
                itemCount: chunk.length,
                itemExtent: 52, // 고정 높이로 성능 최적화
                itemBuilder: (context, index) {
                  final student = chunk[index];
                  final record = attendanceMap[student.id];
                  final globalIndex = startOffset + index + 1;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: noWidth,
                          child: Text(
                            '$globalIndex',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: nameWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              if (student.getStatusLabelAt(selectedDate) !=
                                  null)
                                Text(
                                  student.getStatusLabelAt(selectedDate)!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: attendanceWidth,
                          child: Center(
                            child: AttendanceCircularToggle(
                              provider: attendanceProvider,
                              studentId: student.id,
                              academyId: student.academyId,
                              ownerId: ownerId,
                              date: selectedDate,
                              record: record,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: batchWidth,
                          child: Center(
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit_calendar,
                                size: 20,
                                color: Colors.blue,
                              ),
                              onPressed: () async {
                                await showDialog<bool>(
                                  context: context,
                                  builder: (context) => BatchAttendanceDialog(
                                    student: student,
                                    academyId: academyId,
                                    ownerId: ownerId,
                                    initialDate: selectedDate,
                                    lessonDays: lessonDays,
                                  ),
                                );
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        Expanded(
                          child: RemarkCell(
                            provider: attendanceProvider,
                            studentId: student.id,
                            academyId: student.academyId,
                            ownerId: ownerId,
                            date: selectedDate,
                            initialNote: record?.note ?? "",
                            width: remarkWidth,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
