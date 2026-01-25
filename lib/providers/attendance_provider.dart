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
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _monthlyRecords = await _attendanceService.getMonthlyAttendance(
        academyId: academyId,
        year: year,
        month: month,
      );
    } catch (e) {
      debugPrint('Error loading monthly attendance: $e');
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
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
    int existingIndex = -1;

    for (int i = 0; i < _monthlyRecords.length; i++) {
      final r = _monthlyRecords[i];
      final rDate = DateTime(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      if (r.studentId == studentId && rDate.isAtSameMomentAs(targetDate)) {
        existing = r;
        existingIndex = i;
        break;
      }
    }

    // --- 낙관적 업데이트 (Optimistic Update) ---
    final List<AttendanceRecord> newList = List.from(_monthlyRecords);
    if (type == null) {
      if (existingIndex != -1) {
        newList.removeAt(existingIndex);
      }
    } else {
      final newRecord = AttendanceRecord(
        id: (existing?.id.isNotEmpty ?? false)
            ? existing!.id
            : 'temp_${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        academyId: academyId,
        ownerId: ownerId,
        timestamp: targetDate,
        type: type,
      );
      if (existingIndex != -1) {
        newList[existingIndex] = newRecord;
      } else {
        newList.add(newRecord);
      }
    }
    _monthlyRecords = newList;
    notifyListeners(); // 즉시 UI 반영

    try {
      if (type == null) {
        if (existing != null && existing.id.isNotEmpty) {
          // 문서 ID가 있으면 삭제 (호환성을 위해)
          await _attendanceService.deleteAttendance(existing.id);
        } else {
          // 예측 가능한 ID로 삭제 시도
          final dateStr =
              "${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}";
          await _attendanceService.deleteAttendance("${studentId}_$dateStr");
        }
      } else {
        final newRecord = AttendanceRecord(
          id: '',
          studentId: studentId,
          academyId: academyId,
          ownerId: ownerId,
          timestamp: targetDate,
          type: type,
        );
        await _attendanceService.saveAttendance(newRecord);
      }
    } catch (e) {
      debugPrint('Error updating attendance: $e');
    }

    // 약간의 지연 후 서버 상태 재확인 (스피너 없이)
    await Future.delayed(const Duration(milliseconds: 500));
    await loadMonthlyAttendance(
      academyId: academyId,
      year: targetDate.year,
      month: targetDate.month,
      showLoading: false,
    );
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
    await _attendanceService.saveAttendance(record);
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
