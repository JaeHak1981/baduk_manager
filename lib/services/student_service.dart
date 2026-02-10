import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student_model.dart';

/// 학생 관리 서비스
class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'students';

  /// 학생 등록
  Future<String> createStudent(StudentModel student) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(student.toFirestore());
    return docRef.id;
  }

  /// 특정 기관의 학생 목록 조회
  Future<List<StudentModel>> getStudentsByAcademy(
    String academyId, {
    String? ownerId,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId);

    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final snapshot = await query.orderBy('name').get();
    return snapshot.docs.map((doc) => StudentModel.fromFirestore(doc)).toList();
  }

  /// 특정 기관의 학생 목록 스트림 (실시간 업데이트)
  Stream<List<StudentModel>> getStudentsStream(
    String academyId, {
    String? ownerId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId);

    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    return query
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              .where((s) => s.isDeleted != true) // 인 메모리 필터링
              .toList(),
        );
  }

  /// 학생 정보 수정
  Future<void> updateStudent(StudentModel student) async {
    await _firestore
        .collection(_collection)
        .doc(student.id)
        .update(student.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  /// 학생 삭제 (Soft Delete)
  Future<void> deleteStudent(String studentId) async {
    await _firestore.collection(_collection).doc(studentId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 학생 일괄 업데이트 및 삭제 처리 [NEW]
  Future<void> batchProcessStudents({
    List<StudentModel>? toUpdate,
    List<StudentModel>? toAdd,
    List<String>? toDelete,
  }) async {
    final batch = _firestore.batch();

    // 1. 수정 대상 처리
    if (toUpdate != null) {
      for (var s in toUpdate) {
        batch.update(
          _firestore.collection(_collection).doc(s.id),
          s.copyWith(updatedAt: DateTime.now()).toFirestore(),
        );
      }
    }

    // 2. 추가 대상 처리
    if (toAdd != null) {
      for (var s in toAdd) {
        batch.set(_firestore.collection(_collection).doc(), s.toFirestore());
      }
    }

    // 3. 삭제(수강종료) 대상 처리
    if (toDelete != null) {
      for (var id in toDelete) {
        batch.update(_firestore.collection(_collection).doc(id), {
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  /// 학생 일괄 삭제 (Soft Delete)
  Future<void> deleteStudents(List<String> studentIds) async {
    final batch = _firestore.batch();
    for (var id in studentIds) {
      batch.update(_firestore.collection(_collection).doc(id), {
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// 학생 일괄 이력 업데이트 (재등록 또는 퇴원 예약)
  Future<void> bulkUpdateEnrollmentHistory(
    List<String> studentIds, {
    DateTime? startDate,
    DateTime? endDate,
    int? sessionId,
  }) async {
    final batch = _firestore.batch();

    for (var id in studentIds) {
      final docRef = _firestore.collection(_collection).doc(id);
      final snapshot = await docRef.get();
      if (!snapshot.exists) continue;

      final data = snapshot.data()!;

      // 1. 수강 이력(enrollmentHistory) 업데이트
      final historyData = data['enrollmentHistory'] as List? ?? [];
      final List<EnrollmentPeriod> history = historyData
          .map((e) => EnrollmentPeriod.fromMap(e as Map<String, dynamic>))
          .toList();

      if (startDate != null) {
        history.add(EnrollmentPeriod(startDate: startDate));
      } else if (endDate != null) {
        if (history.isEmpty) {
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          history.add(EnrollmentPeriod(startDate: createdAt, endDate: endDate));
        } else {
          final last = history.last;
          history[history.length - 1] = EnrollmentPeriod(
            startDate: last.startDate,
            endDate: endDate,
          );
        }
      }

      // 2. 부 이동 이력(sessionHistory) 업데이트 (시작일이 있고 세션이 선택된 경우)
      final sessionHistoryData = data['sessionHistory'] as List? ?? [];
      final List<SessionHistory> sessionHistory = sessionHistoryData
          .map((e) => SessionHistory.fromMap(e as Map<String, dynamic>))
          .toList();

      Map<String, dynamic> updates = {
        'isDeleted': false,
        'deletedAt': null,
        'enrollmentHistory': history.map((e) => e.toFirestore()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (startDate != null && sessionId != null) {
        sessionHistory.add(
          SessionHistory(effectiveDate: startDate, sessionId: sessionId),
        );
        updates['sessionHistory'] = sessionHistory
            .map((e) => e.toFirestore())
            .toList();
        updates['session'] = sessionId; // Legacy 필드 보정
      }

      batch.update(docRef, updates);
    }

    await batch.commit();
  }

  /// 학생 복구 (Simple Restore)
  Future<void> restoreStudent(String studentId) async {
    await _firestore.collection(_collection).doc(studentId).update({
      'isDeleted': false,
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 학생 재등록 (이력 동반 복구)
  Future<void> reEnrollStudent(String studentId, DateTime startDate) async {
    final docRef = _firestore.collection(_collection).doc(studentId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final historyData = data['enrollmentHistory'] as List? ?? [];

    // 신규 수강 기간 생성
    final newPeriod = EnrollmentPeriod(startDate: startDate).toFirestore();
    final updatedHistory = List.from(historyData)..add(newPeriod);

    await docRef.update({
      'isDeleted': false,
      'deletedAt': null,
      'enrollmentHistory': updatedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 학생 일괄 이동 (부 이동)
  Future<void> moveStudents(List<String> studentIds, int targetSession) async {
    final batch = _firestore.batch();
    for (var id in studentIds) {
      batch.update(_firestore.collection(_collection).doc(id), {
        'session': targetSession,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// 30일이 지난 삭제된 학생 데이터 영구 삭제
  Future<void> purgeOldDeletedStudents() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await _firestore
        .collection(_collection)
        .where('isDeleted', isEqualTo: true)
        .where('deletedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// 기존 데이터 이력 기반 마이그레이션 (EnrollmentHistory, SessionHistory 초기화)
  Future<int> migrateHistoryData(
    String academyId, {
    required String ownerId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final eHistory = data['enrollmentHistory'] as List?;

      // 이력이 없거나 비어있는 경우에만 초기화 (누락 방지)
      if (eHistory == null || eHistory.isEmpty) {
        // 기존 데이터를 기반으로 초기 이력 생성
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2024, 1, 1);
        final isDeleted = data['isDeleted'] as bool? ?? false;
        final deletedAt = (data['deletedAt'] as Timestamp?)?.toDate();

        final enrollment = [
          {
            'startDate': Timestamp.fromDate(createdAt),
            'endDate': isDeleted
                ? (deletedAt != null ? Timestamp.fromDate(deletedAt) : null)
                : null,
          },
        ];

        final currentSession = data['session'] as int? ?? 0;
        final sessions = [
          {
            'effectiveDate': Timestamp.fromDate(createdAt),
            'sessionId': currentSession,
          },
        ];

        batch.update(doc.reference, {
          'enrollmentHistory': enrollment,
          'sessionHistory': sessions,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('이력 마이그레이션 완료: $count 명의 학생 데이터 최신화됨');
    }
    return count;
  }
}
