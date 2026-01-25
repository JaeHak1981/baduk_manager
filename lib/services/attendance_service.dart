import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

/// 출결 관리 서비스
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'attendance';

  /// 출결 기록 저장
  Future<String> recordAttendance(AttendanceRecord record) async {
    // 같은 학생, 같은 날표(YYYY-MM-DD)에 이미 기록이 있는지 확인하고 업데이트하거나 새로 생성
    // 이 부분은 비즈니스 로직에 따라 다를 수 있음 (중복 허용 여부)
    // 여기서는 단순히 추가하는 방식으로 구현
    final docRef = await _firestore
        .collection(_collection)
        .add(record.toFirestore());
    return docRef.id;
  }

  /// 특정 학생의 출결 내역 조회
  Future<List<AttendanceRecord>> getAttendanceByStudent(
    String studentId,
  ) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc))
        .toList();
  }

  /// 특정 기관/소유자의 오늘 출결 현황 조회
  Stream<List<AttendanceRecord>> getTodayAttendanceStream({
    required String academyId,
    required String ownerId,
    required DateTime date,
  }) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where('ownerId', isEqualTo: ownerId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AttendanceRecord.fromFirestore(doc))
              .toList(),
        );
  }

  /// 특정 기관의 특정 월 전체 출결 내역 조회
  Future<List<AttendanceRecord>> getMonthlyAttendance({
    required String academyId,
    required int year,
    required int month,
  }) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(
      year,
      month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc))
        .toList();
  }

  /// 출결 기록 삭제
  Future<void> deleteAttendance(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// 출결 기록 수정
  Future<void> updateAttendance(AttendanceRecord record) async {
    await _firestore
        .collection(_collection)
        .doc(record.id)
        .update(record.toFirestore());
  }
}
