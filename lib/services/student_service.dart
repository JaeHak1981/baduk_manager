import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// 학생 삭제
  Future<void> deleteStudent(String studentId) async {
    await _firestore.collection(_collection).doc(studentId).delete();
  }

  /// 학생 일괄 삭제
  Future<void> deleteStudents(List<String> studentIds) async {
    final batch = _firestore.batch();
    for (var id in studentIds) {
      batch.delete(_firestore.collection(_collection).doc(id));
    }
    await batch.commit();
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
}
