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
    return LayoutBuilder(
      builder: (context, constraints) {
        const double noWidth = 25;
        const double nameWidth = 60; // 이름 너비 복원
        const double attendanceWidth = 40; // 출결 영역 너비
        const double batchWidth = 65; // 일괄 버튼 너비
        const double spacing = 8; // 간격 복원
        const double remarkPadding = 12; // 출격-비고 사이 여백 추가
        final double totalFixed =
            noWidth +
            nameWidth +
            attendanceWidth +
            batchWidth +
            (spacing * 4) +
            16 +
            remarkPadding; // 16은 margin
        final double remarkWidth = (constraints.maxWidth - totalFixed).clamp(
          100.0,
          500.0,
        );

        return DataTable(
          columnSpacing: spacing,
          horizontalMargin: 8,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 44,
          headingRowHeight: 36,
          headingTextStyle: AppTheme.heading2.copyWith(fontSize: 12),
          columns: [
            const DataColumn(
              label: SizedBox(width: noWidth, child: Text('No.')),
            ),
            const DataColumn(
              label: SizedBox(width: nameWidth, child: Text('이름')),
            ),
            const DataColumn(
              label: SizedBox(
                width: attendanceWidth,
                child: Center(child: Text('출결')),
              ),
            ),
            const DataColumn(
              label: SizedBox(
                width: batchWidth,
                child: Center(child: Text('일괄')),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.only(left: remarkPadding),
                child: SizedBox(width: remarkWidth, child: const Text('비고')),
              ),
            ),
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
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      student.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                DataCell(
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
                ),
                DataCell(
                  SizedBox(
                    width: batchWidth,
                    child: Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => BatchAttendanceDialog(
                              student: student,
                              academyId: academyId,
                              ownerId: ownerId,
                              initialDate: selectedDate,
                              lessonDays: lessonDays,
                            ),
                          );
                          if (result == true && context.mounted) {
                            // 리로드 필요 시 처리
                          }
                        },
                        child: const Text(
                          '일괄',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.only(left: remarkPadding),
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
                ),
              ],
            );
          }),
        );
      },
    );
  }
}
