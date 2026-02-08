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

  /// 학생 복구 (Restore)
  Future<void> restoreStudent(String studentId) async {
    await _firestore.collection(_collection).doc(studentId).update({
      'isDeleted': false,
      'deletedAt': null,
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

  /// 기존 데이터 정규화 (isDeleted 필드가 없는 데이터에 false 추가)
  Future<void> normalizeStudents() async {
    final snapshot = await _firestore.collection(_collection).get();
    final batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('isDeleted')) {
        batch.update(doc.reference, {'isDeleted': false});
        count++;
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('정규화 완료: $count 명의 학생 데이터 수정됨');
    }
  }
}
