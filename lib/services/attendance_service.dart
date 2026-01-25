import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

/// 출결 관리 서비스
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'attendance';

  /// 출결 기록 저장 (중복 방지를 위해 학생ID와 날짜 조합을 ID로 사용)
  Future<void> saveAttendance(AttendanceRecord record) async {
    final dateStr =
        "${record.timestamp.year}${record.timestamp.month.toString().padLeft(2, '0')}${record.timestamp.day.toString().padLeft(2, '0')}";
    final docId = "${record.studentId}_$dateStr";

    await _firestore
        .collection(_collection)
        .doc(docId)
        .set(record.toFirestore());
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
    required String ownerId,
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
        .where('ownerId', isEqualTo: ownerId)
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
