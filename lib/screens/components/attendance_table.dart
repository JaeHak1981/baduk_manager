import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../config/app_theme.dart';
import 'attendance_circular_toggle.dart';
import 'remark_cell.dart';

class AttendanceTable extends StatelessWidget {
  final List<StudentModel> students;
  final AttendanceProvider attendanceProvider;
  final Map<String, AttendanceRecord> attendanceMap;
  final DateTime selectedDate;
  final String ownerId;
  final bool isSelectionMode;
  final Set<String> selectedStudentIds;
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
            Expanded(child: _buildDataTable(context, rightColumn, halfLength)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.topLeft,
        child: _buildDataTable(context, students, 0),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    List<StudentModel> chunk,
    int startOffset,
  ) {
    return DataTable(
      columnSpacing: 8,
      horizontalMargin: 8,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 44,
      headingRowHeight: 36,
      headingTextStyle: AppTheme.heading2.copyWith(fontSize: 12),
      columns: const [
        DataColumn(label: SizedBox(width: 25, child: Text('No.'))),
        DataColumn(label: SizedBox(width: 60, child: Text('이름'))),
        DataColumn(label: Center(child: Text('출결'))),
        DataColumn(label: Expanded(child: Text('비고'))),
      ],
      rows: List.generate(chunk.length, (index) {
        final student = chunk[index];
        final record = attendanceMap[student.id];
        final globalIndex = startOffset + index + 1;

        return DataRow(
          cells: [
            DataCell(
              Text(
                '$globalIndex',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            DataCell(
              Text(
                student.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            DataCell(
              Center(
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
            DataCell(
              RemarkCell(
                provider: attendanceProvider,
                studentId: student.id,
                academyId: student.academyId,
                ownerId: ownerId,
                date: selectedDate,
                initialNote: record?.note ?? "",
              ),
            ),
          ],
        );
      }),
    );
  }
}
