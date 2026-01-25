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

  List<AttendanceRecord> get todayRecords => _todayRecords;
  List<AttendanceRecord> get monthlyRecords => _monthlyRecords;
  bool get isLoading => _isLoading;

  /// 월별 출결 기록 로드
  Future<void> loadMonthlyAttendance({
    required String academyId,
    required int year,
    required int month,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _monthlyRecords = await _attendanceService.getMonthlyAttendance(
        academyId: academyId,
        year: year,
        month: month,
      );
    } catch (e) {
      debugPrint('Error loading monthly attendance: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 특정 날짜/학생의 출결 상태 직접 지정 (출석/결석/지각/취소)
  Future<void> updateStatus({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
    required AttendanceType? type, // null이면 기록 삭제
  }) async {
    final targetDate = DateTime(date.year, date.month, date.day);

    // 기존 기록 찾기
    AttendanceRecord? existing;
    try {
      existing = _monthlyRecords.firstWhere((r) {
        final rDate = DateTime(
          r.timestamp.year,
          r.timestamp.month,
          r.timestamp.day,
        );
        return r.studentId == studentId && rDate.isAtSameMomentAs(targetDate);
      });
    } catch (_) {
      existing = null;
    }

    if (type == null) {
      if (existing != null) {
        await deleteAttendance(existing.id, studentId);
      }
    } else {
      if (existing == null) {
        await markAttendance(
          studentId: studentId,
          academyId: academyId,
          ownerId: ownerId,
          type: type,
          date: targetDate,
        );
      } else {
        if (existing.type != type) {
          await updateAttendance(existing.copyWith(type: type));
        }
      }
    }

    await loadMonthlyAttendance(
      academyId: academyId,
      year: targetDate.year,
      month: targetDate.month,
    );
  }

  /// 특정 날짜/학생의 출결 상태 토글
  Future<void> toggleAttendance({
    required String studentId,
    required String academyId,
    required String ownerId,
    required DateTime date,
  }) async {
    // 해당 날짜의 0시 0분으로 정규화
    final targetDate = DateTime(date.year, date.month, date.day);

    // 기존 기록 찾기
    AttendanceRecord? existing;
    try {
      existing = _monthlyRecords.firstWhere((r) {
        final rDate = DateTime(
          r.timestamp.year,
          r.timestamp.month,
          r.timestamp.day,
        );
        return r.studentId == studentId && rDate.isAtSameMomentAs(targetDate);
      });
    } catch (_) {
      existing = null;
    }

    if (existing == null) {
      // 기록 없음 -> 출석으로 생성
      await markAttendance(
        studentId: studentId,
        academyId: academyId,
        ownerId: ownerId,
        type: AttendanceType.present,
        date: targetDate,
      );
    } else {
      // 기록 있음 -> 순환 (출석 -> 결석 -> 지각 -> 삭제)
      switch (existing.type) {
        case AttendanceType.present:
          await updateAttendance(
            existing.copyWith(type: AttendanceType.absent),
          );
          break;
        case AttendanceType.absent:
          await updateAttendance(existing.copyWith(type: AttendanceType.late));
          break;
        case AttendanceType.late:
        case AttendanceType.manual:
          await deleteAttendance(existing.id, studentId);
          break;
      }
    }

    // 로드 없이도 로컬 상태 반영을 위해 다시 로드 (최적화 가능하지만 일단 안전하게)
    await loadMonthlyAttendance(
      academyId: academyId,
      year: targetDate.year,
      month: targetDate.month,
    );
  }

  /// 오늘의 출결 현황 구독 (실시간)
  void subscribeToTodayAttendance({
    required String academyId,
    required String ownerId,
  }) {
    _isLoading = true;
    notifyListeners();

    _attendanceService
        .getTodayAttendanceStream(
          academyId: academyId,
          ownerId: ownerId,
          date: DateTime.now(),
        )
        .listen((records) {
          _todayRecords = records;
          _isLoading = false;
          notifyListeners();
        });
  }

  /// 출결 기록 저장
  Future<void> markAttendance({
    required String studentId,
    required String academyId,
    required String ownerId,
    required AttendanceType type,
    String? note,
    DateTime? date, // 선택적 날짜 파라미터 추가
  }) async {
    final record = AttendanceRecord(
      id: '', // Firestore에서 자동 생성
      studentId: studentId,
      academyId: academyId,
      ownerId: ownerId,
      timestamp: date ?? DateTime.now(), // 날짜가 있으면 사용, 없으면 현재 시간
      type: type,
      note: note,
    );

    await _attendanceService.recordAttendance(record);
    // 기록 추가 후 해당 학생의 기록 다시 로드 (히스토리 화면 갱신용)
    await loadStudentAttendance(studentId);
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
  double getAttendanceRate(List<AttendanceRecord> records) {
    if (records.isEmpty) return 0;
    final presentOrLate = records
        .where(
          (r) =>
              r.type == AttendanceType.present || r.type == AttendanceType.late,
        )
        .length;
    return (presentOrLate / records.length) * 100;
  }

  /// 출결 기록 수정
  Future<void> updateAttendance(AttendanceRecord record) async {
    await _attendanceService.updateAttendance(record);
    // 수정 후 해당 학생의 기록 다시 로드
    await loadStudentAttendance(record.studentId);
  }

  /// 출결 기록 삭제
  Future<void> deleteAttendance(String id, String studentId) async {
    await _attendanceService.deleteAttendance(id);
    // 삭제 후 해당 학생의 기록 다시 로드
    await loadStudentAttendance(studentId);
  }
}
