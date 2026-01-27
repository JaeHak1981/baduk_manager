import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student_progress_model.dart';

/// 학생 진도 관리 서비스
class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'studentProgress';

  /// 새 진도 기록 시작 (교재 할당)
  Future<String> startProgress(StudentProgressModel progress) async {
    print(
      'DEBUG: ProgressService.startProgress - data: ${progress.toFirestore()}',
    );
    final docRef = await _firestore
        .collection(_collection)
        .add(progress.toFirestore());
    return docRef.id;
  }

  /// 특정 기관의 모든 진도 기록 조회 (Bulk Load)
  Future<List<StudentProgressModel>> getAcademyProgress(
    String academyId, {
    required String ownerId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where('ownerId', isEqualTo: ownerId)
        .get();

    return snapshot.docs
        .map(
          (doc) => StudentProgressModel.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .where((p) => p.isDeleted != true) // 인 메모리 필터링
        .toList();
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

    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => StudentProgressModel.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .where((p) => p.isDeleted != true) // 인 메모리 필터링
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

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => StudentProgressModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .where((p) => p.isDeleted != true) // 인 메모리 필터링
          .toList(),
    );
  }

  /// 진도 상태 업데이트 (완료 여부만)
  Future<void> updateStatus(String progressId, bool isCompleted) async {
    final data = <String, dynamic>{
      'isCompleted': isCompleted,
      'updatedAt': Timestamp.now(),
    };

    if (isCompleted) {
      data['endDate'] = Timestamp.now();
    } else {
      data['endDate'] = null; // 미완료로 변경 시 종료일 제거
    }

    await _firestore.collection(_collection).doc(progressId).update(data);
  }

  /// 진도 권수 업데이트
  Future<void> updateVolume(String progressId, int newVolume) async {
    final data = <String, dynamic>{
      'volumeNumber': newVolume,
      'updatedAt': Timestamp.now(),
    };

    await _firestore.collection(_collection).doc(progressId).update(data);
  }

  /// 진도 권수 업데이트 및 상태 리셋 (다시 할당하는 경우 대응)
  Future<void> updateVolumeAndResetStatus(
    String progressId,
    int newVolume,
  ) async {
    final data = <String, dynamic>{
      'volumeNumber': newVolume,
      'isCompleted': false,
      'endDate': null,
      'isDeleted': false,
      'updatedAt': Timestamp.now(),
    };

    await _firestore.collection(_collection).doc(progressId).update(data);
  }

  /// 진도 기록 삭제 (Soft Delete)
  Future<void> deleteProgress(String progressId) async {
    await _firestore.collection(_collection).doc(progressId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 진도 기록 복구 (Restore: 완료 -> 진행 중)
  Future<void> restoreProgress(String progressId) async {
    await _firestore.collection(_collection).doc(progressId).update({
      'isCompleted': false,
      'endDate': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 동일 시리즈의 이전 권수들 자동 완료 처리
  Future<void> completePreviousVolumes(
    String studentId,
    String textbookId,
    int currentVolume, {
    required String ownerId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId)
        .where('textbookId', isEqualTo: textbookId)
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final isCompleted = data['isCompleted'] as bool? ?? false;
      final isDeleted = data['isDeleted'] as bool? ?? false;

      if (!isCompleted && !isDeleted) {
        final vol = data['volumeNumber'] as int? ?? 0;
        if (vol < currentVolume) {
          batch.update(doc.reference, {
            'isCompleted': true,
            'endDate': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
    await batch.commit();
  }

  /// 30일이 지난 삭제된 진도 데이터 영구 삭제
  Future<void> purgeOldDeletedProgress() async {
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

  /// 기존 진도 데이터 정규화
  Future<void> normalizeProgress() async {
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
      debugPrint('정기화 완료: $count 개의 진도 데이터 수정됨');
    }
  }
}
