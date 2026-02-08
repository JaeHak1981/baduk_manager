import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/attendance_batch_processor.dart';
import '../utils/date_extensions.dart';
import '../utils/error_handler.dart';
import 'base_provider.dart';

/// 출결 상태 관리 프로바이더
class AttendanceProvider extends BaseProvider {
  final AttendanceService _attendanceService = AttendanceService();

  List<AttendanceRecord> _monthlyRecords = [];
  Map<String, List<AttendanceRecord>> _historyMap = {}; // Key: studentId
  int _stateCounter = 0; // UI 강제 갱신을 위한 카운터

  // --- 수동 저장용 필드 ---
  // Key: studentId_YYYYMMDD, Value: AttendanceRecord
  final Map<String, AttendanceRecord> _pendingChanges = {};
  final Set<String> _pendingDeletions = {}; // 삭제할 ID 목록

  bool get hasPendingChanges =>
      _pendingChanges.isNotEmpty || _pendingDeletions.isNotEmpty;
  // -----------------------

  List<AttendanceRecord> get monthlyRecords => _monthlyRecords;
  int get stateCounter => _stateCounter;

  /// 특정 학생의 오늘 날짜 출결 기록을 반환합니다.
  AttendanceRecord? getTodayRecord(String studentId) {
    try {
      final now = DateTime.now();
      return _monthlyRecords.firstWhere(
        (r) =>
            r.studentId == studentId &&
            r.timestamp.year == now.year &&
            r.timestamp.month == now.month &&
            r.timestamp.day == now.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// 월별 출결 기록 로드
  Future<void> loadMonthlyAttendance({
    required String academyId,
    required String ownerId,
    required int year,
    required int month,
    bool showLoading = true,
  }) async {
    await runAsync(() async {
      _monthlyRecords = await _attendanceService.getMonthlyAttendance(
        academyId: academyId,
        ownerId: ownerId,
        year: year,
        month: month,
      );
    }, showLoading: showLoading);
  }

  /// 변경 사항 일괄 저장
  Future<bool> savePendingChanges() async {
    if (_pendingChanges.isEmpty && _pendingDeletions.isEmpty) return true;

    return await runAsync(() async {
          try {
            // 1. 삭제 먼저 처리
            for (var docId in _pendingDeletions) {
              await _attendanceService.deleteAttendance(docId);
            }
            _pendingDeletions.clear();

            // 2. 추가/수정 처리
            for (var record in _pendingChanges.values) {
              await _attendanceService.saveAttendance(record);
            }
            _pendingChanges.clear();

            AppErrorHandler.showSnackBar('출결 변경 사항이 저장되었습니다.', isError: false);
            return true;
          } catch (e) {
            AppErrorHandler.handle(
              e,
              customMessage: '출결 저장 중 오류가 발생했습니다.',
              onRetry: () => savePendingChanges(),
            );
            return false;
          }
        }) ??
        false;
  }

  /// 보류 중인 변경 사항 취소 (원래대로 되돌리기)
  void discardPendingChanges() {
    _pendingChanges.clear();
    _pendingDeletions.clear();
    _stateCounter++;
    notifyListeners();
  }

  /// 내부 상태 업데이트 공통 메서드
  void _internalUpdateStatus(
    String docKey,
    AttendanceRecord? record,
    DateTime targetDate,
    String studentId,
  ) {
    if (record == null) {
      // 삭제 처리
      _pendingChanges.remove(docKey);
      _pendingDeletions.add(docKey);
      _monthlyRecords = _monthlyRecords
          .where((r) => !(r.id == docKey))
          .toList();
    } else {
      // 추가/수정 처리
      _pendingDeletions.remove(docKey);
      _pendingChanges[docKey] = record;

      bool found = false;
      final List<AttendanceRecord> newList = _monthlyRecords.map((r) {
        if (r.id == docKey) {
          found = true;
          return record.copyWith(note: r.note);
        }
        return r;
      }).toList();

      if (!found) {
        newList.add(record);
      }
      _monthlyRecords = newList;
    }
    _stateCounter++;
    notifyListeners();
  }

  /// 특정 날짜/학생의 출결 상태 직접 지정
  void updateStatus({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
    required AttendanceType? type,
  }) {
    final targetDate = date.startOfDay;
    final docKey = AttendanceRecord.generateId(studentId, targetDate);

    if (type == null) {
      _internalUpdateStatus(docKey, null, targetDate, studentId);
    } else {
      final newRecord = AttendanceRecord(
        id: docKey,
        studentId: studentId,
        academyId: academyId,
        ownerId: ownerId,
        timestamp: targetDate,
        type: type,
      );
      _internalUpdateStatus(docKey, newRecord, targetDate, studentId);
    }
  }

  /// 순환 토글 방식 출결 업데이트
  void toggleStatus({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
  }) {
    final targetDate = date.startOfDay;
    final docKey = AttendanceRecord.generateId(studentId, targetDate);

    final existing = _monthlyRecords.where((r) => r.id == docKey).firstOrNull;

    AttendanceType? nextType;
    if (existing == null) {
      nextType = AttendanceType.present;
    } else if (existing.type == AttendanceType.present) {
      nextType = AttendanceType.absent;
    } else if (existing.type == AttendanceType.absent) {
      nextType = null; // 초기화 처리
    } else {
      nextType = AttendanceType.present;
    }

    updateStatus(
      studentId: studentId,
      academyId: academyId,
      ownerId: ownerId,
      date: date,
      type: nextType,
    );
  }

  /// 비고(Note) 업데이트
  void updateNote({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
    required String note,
  }) {
    final targetDate = date.startOfDay;
    final docKey = AttendanceRecord.generateId(studentId, targetDate);

    final existing = _monthlyRecords.where((r) => r.id == docKey).firstOrNull;

    final record = AttendanceRecord(
      id: docKey,
      studentId: studentId,
      academyId: academyId,
      ownerId: ownerId,
      timestamp: targetDate,
      type: existing?.type ?? AttendanceType.present,
      note: note,
    );

    _internalUpdateStatus(docKey, record, targetDate, studentId);
  }

  /// 특정 학생의 모든 출결 내역 로드
  Future<void> loadStudentAttendance(String studentId) async {
    await runAsync(() async {
      final records = await _attendanceService.getAttendanceByStudent(
        studentId,
      );
      _historyMap[studentId] = records;
    });
  }

  /// 특정 학생의 통계데이터 가져오기
  List<AttendanceRecord> getHistoryForStudent(String studentId) {
    return _historyMap[studentId] ?? [];
  }

  /// 출석률 계산
  double getAttendanceRate(List<AttendanceRecord> records, int totalClassDays) {
    if (totalClassDays == 0) return 0;
    final presentOrLate = records
        .where(
          (r) =>
              r.type == AttendanceType.present || r.type == AttendanceType.late,
        )
        .length;
    return (presentOrLate / totalClassDays) * 100;
  }

  /// 기간별 출결 기록 로드
  Future<List<AttendanceRecord>> getRecordsForPeriod({
    required String academyId,
    required String ownerId,
    required DateTime start,
    required DateTime end,
  }) async {
    return await runAsync(() async {
          List<Future<List<AttendanceRecord>>> futures = [];
          DateTime current = DateTime(start.year, start.month);
          final endTime = DateTime(end.year, end.month);

          while (!current.isAfter(endTime)) {
            futures.add(
              _attendanceService.getMonthlyAttendance(
                academyId: academyId,
                ownerId: ownerId,
                year: current.year,
                month: current.month,
              ),
            );

            current = DateTime(current.year, current.month + 1);
          }

          final results = await Future.wait(futures);
          return results.expand((x) => x).toList();
        }) ??
        [];
  }

  /// 출결 기록 삭제 (직접 삭제)
  Future<void> deleteAttendance(String id, String studentId) async {
    await runAsync(() async {
      await _attendanceService.deleteAttendance(id);
      await loadStudentAttendance(studentId);
    });
  }

  /// 기간별 출결 일괄 업데이트 (BatchProcessor 활용)
  Future<bool> updateAttendanceForPeriod({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime startDate,
    required DateTime endDate,
    required AttendanceType type,
    bool skipWeekends = true,
  }) async {
    return await runAsync(() async {
          try {
            final records = AttendanceBatchProcessor.createRecordsForPeriod(
              studentId: studentId,
              academyId: academyId,
              ownerId: ownerId,
              startDate: startDate,
              endDate: endDate,
              type: type,
              skipWeekends: skipWeekends,
            );

            if (records.isNotEmpty) {
              await _attendanceService.saveAttendanceBatch(records);

              // 리로드 로직 (시작일/종료일 포함된 달)
              await loadMonthlyAttendance(
                academyId: academyId,
                ownerId: ownerId,
                year: startDate.year,
                month: startDate.month,
                showLoading: false,
              );

              if (startDate.month != endDate.month ||
                  startDate.year != endDate.year) {
                await loadMonthlyAttendance(
                  academyId: academyId,
                  ownerId: ownerId,
                  year: endDate.year,
                  month: endDate.month,
                  showLoading: false,
                );
              }
            }
            return true;
          } catch (e) {
            AppErrorHandler.handle(
              e,
              customMessage: '일괄 출결 업데이트 중 오류가 발생했습니다.',
              onRetry: () => updateAttendanceForPeriod(
                studentId: studentId,
                academyId: academyId,
                ownerId: ownerId,
                startDate: startDate,
                endDate: endDate,
                type: type,
                skipWeekends: skipWeekends,
              ),
            );
            return false;
          }
        }) ??
        false;
  }
}
