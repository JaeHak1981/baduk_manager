import '../models/attendance_model.dart';
import '../utils/date_extensions.dart';

/// 출결 관련 복잡한 일괄 처리 로직을 담당하는 도메인 서비스
class AttendanceBatchProcessor {
  /// 기간별 출결 레코드 생성 (주말 제외 옵션 포함)
  static List<AttendanceRecord> createRecordsForPeriod({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime startDate,
    required DateTime endDate,
    required AttendanceType type,
    bool skipWeekends = true,
    String? note = '[일괄 처리]',
  }) {
    final List<AttendanceRecord> records = [];
    DateTime current = startDate.startOfDay;
    final last = endDate.startOfDay;

    while (!current.isAfter(last)) {
      // 주말 제외 로직
      if (skipWeekends &&
          (current.weekday == DateTime.saturday ||
              current.weekday == DateTime.sunday)) {
        current = current.add(const Duration(days: 1));
        continue;
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
