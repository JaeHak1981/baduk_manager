import '../models/attendance_model.dart';
import '../utils/date_extensions.dart';

/// 출결 관련 복잡한 일괄 처리 로직을 담당하는 도메인 서비스
class AttendanceBatchProcessor {
  /// 기간별 출결 레코드 생성 (수업 요일 필터 포함)
  static List<AttendanceRecord> createRecordsForPeriod({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime startDate,
    required DateTime endDate,
    required AttendanceType type,
    List<int>? lessonDays,
    bool applyOnlyLessonDays = true,
    String? note = '[일괄 처리]',
  }) {
    final List<AttendanceRecord> records = [];
    DateTime current = startDate.startOfDay;
    final last = endDate.startOfDay;

    while (!current.isAfter(last)) {
      // 수업 요일 필터링 (가이드라인에 따라 academy.lessonDays 참조)
      if (applyOnlyLessonDays && lessonDays != null) {
        if (!lessonDays.contains(current.weekday)) {
          current = current.add(const Duration(days: 1));
          continue;
        }
      }

      records.add(
        AttendanceRecord(
          id: '', // 서비스/Firestore에서 자동 생성
          studentId: studentId,
          academyId: academyId,
          ownerId: ownerId,
          timestamp: current,
          type: type,
          note: note,
        ),
      );

      current = current.add(const Duration(days: 1));
    }

    return records;
  }
}
