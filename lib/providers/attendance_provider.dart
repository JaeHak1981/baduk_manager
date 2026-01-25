import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

/// 출결 상태 관리 프로바이더
class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();

  List<AttendanceRecord> _todayRecords = [];
  Map<String, List<AttendanceRecord>> _historyMap = {}; // Key: studentId
  bool _isLoading = false;

  List<AttendanceRecord> get todayRecords => _todayRecords;
  bool get isLoading => _isLoading;

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
