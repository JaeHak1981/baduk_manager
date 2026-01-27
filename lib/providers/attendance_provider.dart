import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

/// 출결 상태 관리 프로바이더
class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();

  List<AttendanceRecord> _todayRecords = [];
  List<AttendanceRecord> _monthlyRecords = [];
  Map<String, List<AttendanceRecord>> _historyMap = {}; // Key: studentId
  bool _isLoading = false;
  int _stateCounter = 0; // UI 강제 갱신을 위한 카운터

  // --- 수동 저장용 필드 ---
  // Key: studentId_YYYYMMDD, Value: AttendanceRecord
  final Map<String, AttendanceRecord> _pendingChanges = {};
  final Set<String> _pendingDeletions = {}; // 삭제할 ID 목록
  bool get hasPendingChanges =>
      _pendingChanges.isNotEmpty || _pendingDeletions.isNotEmpty;
  // -----------------------

  List<AttendanceRecord> get todayRecords => _todayRecords;
  List<AttendanceRecord> get monthlyRecords => _monthlyRecords;
  bool get isLoading => _isLoading;
  int get stateCounter => _stateCounter;

  /// 월별 출결 기록 로드
  Future<void> loadMonthlyAttendance({
    required String academyId,
    required String ownerId,
    required int year,
    required int month,
    bool showLoading = true,
  }) async {
    // 저장되지 않은 변경 사항이 있다면 로드 시 초기화될 수 있음을 주의 (기획상 필요시 경고 필요)
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _monthlyRecords = await _attendanceService.getMonthlyAttendance(
        academyId: academyId,
        ownerId: ownerId,
        year: year,
        month: month,
      );
      // 로드 성공 시 해당 월의 펜딩 데이터는 그대로 두거나, 정책에 따라 처리
    } catch (e) {
      debugPrint('Error loading monthly attendance: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// 변경 사항 일괄 저장
  Future<bool> savePendingChanges() async {
    if (_pendingChanges.isEmpty && _pendingDeletions.isEmpty) return true;

    _isLoading = true;
    notifyListeners();

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

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving pending changes: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 보류 중인 변경 사항 취소 (원래대로 되돌리기)
  void discardPendingChanges() {
    _pendingChanges.clear();
    _pendingDeletions.clear();
    _stateCounter++;
    notifyListeners();
  }

  /// 특정 날짜/학생의 출결 상태 직접 지정 (수동 저장 방식으로 개선)
  void updateStatus({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
    required AttendanceType? type, // null이면 기록 삭제
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final dateStr =
        "${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}";
    final docKey = "${studentId}_$dateStr";

    if (type == null) {
      // --- 삭제(초기화) 로직 ---
      _pendingChanges.remove(docKey);
      _pendingDeletions.add(docKey);

      // 로컬 리스트에서 제거
      _monthlyRecords = _monthlyRecords
          .where(
            (r) =>
                !(r.studentId == studentId &&
                    r.timestamp.year == targetDate.year &&
                    r.timestamp.month == targetDate.month &&
                    r.timestamp.day == targetDate.day),
          )
          .toList();
    } else {
      // --- 추가/수정 로직 ---
      _pendingDeletions.remove(docKey); // 혹시 삭제에 있었다면 제거

      final newRecord = AttendanceRecord(
        id: docKey,
        studentId: studentId,
        academyId: academyId,
        ownerId: ownerId,
        timestamp: targetDate,
        type: type,
      );

      _pendingChanges[docKey] = newRecord;

      // 로컬 리스트 반영
      bool found = false;
      final List<AttendanceRecord> newList = _monthlyRecords.map((r) {
        final rDate = DateTime(
          r.timestamp.year,
          r.timestamp.month,
          r.timestamp.day,
        );
        if (r.studentId == studentId && rDate.isAtSameMomentAs(targetDate)) {
          found = true;
          return newRecord.copyWith(note: r.note);
        }
        return r;
      }).toList();

      if (!found) {
        newList.add(newRecord);
      }
      _monthlyRecords = newList;
    }

    _stateCounter++;
    notifyListeners();
  }

  /// 순환 토글 방식 출결 업데이트 (수동 저장 방식)
  void toggleStatus({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    AttendanceRecord? existing;

    for (var r in _monthlyRecords) {
      final rDate = DateTime(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      if (r.studentId == studentId && rDate.isAtSameMomentAs(targetDate)) {
        existing = r;
        break;
      }
    }

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

  /// 특정 기록의 비고(Note)만 업데이트 (수동 저장 방식)
  void updateNote({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
    required String note,
  }) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final dateStr =
        "${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}";
    final docKey = "${studentId}_$dateStr";

    // 1. 기존 기록 찾기 (메모 업데이트를 위해)
    AttendanceRecord? existing;
    for (var r in _monthlyRecords) {
      final rDate = DateTime(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      if (r.studentId == studentId && rDate.isAtSameMomentAs(targetDate)) {
        existing = r;
        break;
      }
    }

    // 2. 펜딩 맵 업데이트용 객체 생성
    final record = AttendanceRecord(
      id: docKey,
      studentId: studentId,
      academyId: academyId,
      ownerId: ownerId,
      timestamp: targetDate,
      type: existing?.type ?? AttendanceType.present,
      note: note,
    );

    _pendingChanges[docKey] = record;

    // 3. 로컬 상태 즉시 반영 (UI 업데이트용)
    bool found = false;
    final List<AttendanceRecord> newList = _monthlyRecords.map((r) {
      final rDate = DateTime(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      if (r.studentId == studentId && rDate.isAtSameMomentAs(targetDate)) {
        found = true;
        return r.copyWith(note: note);
      }
      return r;
    }).toList();

    if (!found) {
      newList.add(record);
    }

    _monthlyRecords = newList;
    _stateCounter++;
    notifyListeners();
  }

  /// 특정 학생이 오늘 출석했는지 확인
  bool isStudentPresent(String studentId) {
    return _todayRecords.any(
      (r) => r.studentId == studentId && r.type == AttendanceType.present,
    );
  }

  /// 특정 학생의 오늘 출결 기록 가져오기
  AttendanceRecord? getTodayRecord(String studentId) {
    if (_todayRecords.isEmpty) return null;
    try {
      return _todayRecords.firstWhere((r) => r.studentId == studentId);
    } catch (_) {
      return null;
    }
  }

  /// 특정 학생의 모든 출결 내역 로드
  Future<void> loadStudentAttendance(String studentId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final records = await _attendanceService.getAttendanceByStudent(
        studentId,
      );
      _historyMap[studentId] = records;
    } catch (e) {
      debugPrint('Error loading attendance history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 특정 학생의 통계데이터 가져오기
  List<AttendanceRecord> getHistoryForStudent(String studentId) {
    return _historyMap[studentId] ?? [];
  }

  /// 출석률 계산 (Present + Late) / Total
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

  /// 출결 기록 수정
  Future<void> updateAttendance(AttendanceRecord record) async {
    await _attendanceService.saveAttendance(record);
    // 수정 후 해당 학생의 기록 다시 로드
    await loadStudentAttendance(record.studentId);
  }

  /// 기간별 출결 기록 로드 (시작 월 ~ 종료 월)
  Future<List<AttendanceRecord>> getRecordsForPeriod({
    required String academyId,
    required String ownerId,
    required DateTime start,
    required DateTime end,
  }) async {
    List<Future<List<AttendanceRecord>>> futures = [];

    // 시작 월부터 종료 월까지 반복
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

      // 다음 달로 이동
      if (current.month == 12) {
        current = DateTime(current.year + 1, 1);
      } else {
        current = DateTime(current.year, current.month + 1);
      }
    }

    final results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  }

  /// 출결 기록 삭제
  Future<void> deleteAttendance(String id, String studentId) async {
    await _attendanceService.deleteAttendance(id);
    // 삭제 후 해당 학생의 기록 다시 로드
    await loadStudentAttendance(studentId);
  }
}
