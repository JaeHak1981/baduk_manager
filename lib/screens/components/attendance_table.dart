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

    // 학생 명단을 35명씩 청크로 나눔 (데이터 테이블 렌더링 최적화)
    final chunks = _chunkList(students, 35);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: chunks.length,
      itemBuilder: (context, index) {
        return _buildDataTable(context, chunks[index]);
      },
    );
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }

  Widget _buildDataTable(BuildContext context, List<StudentModel> chunk) {
    return DataTable(
      columnSpacing: 10,
      horizontalMargin: 12,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 48,
      headingRowHeight: 40,
      headingTextStyle: AppTheme.heading2.copyWith(fontSize: 13),
      columns: const [
        DataColumn(label: SizedBox(width: 80, child: Text('이름'))),
        DataColumn(label: SizedBox(width: 60, child: Text('학년/반'))),
        DataColumn(label: SizedBox(width: 50, child: Text('부'))),
        DataColumn(label: Center(child: Text('출결'))),
        DataColumn(label: Expanded(child: Text('비고'))),
      ],
      rows: chunk.map((student) {
        final isSelected = selectedStudentIds.contains(student.id);
        final record = attendanceMap[student.id];

        return DataRow(
          selected: isSelected,
          onSelectChanged: isSelectionMode
              ? (value) => onStudentSelected(student.id)
              : null,
          cells: [
            DataCell(
              Text(
                student.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            DataCell(
              Text('${student.grade ?? ""} / ${student.classNumber ?? ""}'),
            ),
            DataCell(
              Text(student.session == 0 ? "미배정" : "${student.session}부"),
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
      }).toList(),
    );
  }
}
