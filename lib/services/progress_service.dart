import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_progress_model.dart';

/// 학생 진도 관리 서비스
class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'studentProgress';

  /// 새 진도 기록 시작 (교재 할당)
  Future<String> startProgress(StudentProgressModel progress) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(progress.toFirestore());
    return docRef.id;
  }

  /// 특정 학생의 모든 진도 기록 조회 (소유자 필터 추가)
  Future<List<StudentProgressModel>> getStudentProgress(
    String studentId,
    String? ownerId,
  ) async {
    Query query = _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId);

    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final snapshot = await query.orderBy('updatedAt', descending: true).get();

    return snapshot.docs
        .map(
          (doc) => StudentProgressModel.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .toList();
  }

  /// 실시간 학생 진도 스트림 (소유자 필터 추가)
  Stream<List<StudentProgressModel>> getStudentProgressStream(
    String studentId,
    String? ownerId,
  ) {
    Query query = _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId);

    if (ownerId != null && ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => StudentProgressModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// 진도 업데이트 (페이지 변경)
  Future<void> updateProgress(
    String progressId,
    int currentPage,
    bool isCompleted,
  ) async {
    final data = {
      'currentPage': currentPage,
      'isCompleted': isCompleted,
      'updatedAt': Timestamp.now(),
    };

    if (isCompleted) {
      data['endDate'] = Timestamp.now();
    }

    await _firestore.collection(_collection).doc(progressId).update(data);
  }

  /// 진도 기록 삭제
  Future<void> deleteProgress(String progressId) async {
    await _firestore.collection(_collection).doc(progressId).delete();
  }
}
