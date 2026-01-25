import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/academy_model.dart';

/// 기관 관리 서비스
class AcademyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 기관 생성
  Future<AcademyModel> createAcademy({
    required String name,
    required AcademyType type,
    required String ownerId,
    int totalSessions = 1,
    List<int> lessonDays = const [],
    List<String> usingTextbookIds = const [],
    String? phoneNumber,
    String? address,
  }) async {
    try {
      final docRef = _firestore.collection('academies').doc();

      final academy = AcademyModel(
        id: docRef.id,
        name: name,
        type: type,
        ownerId: ownerId,
        totalSessions: totalSessions,
        lessonDays: lessonDays,
        usingTextbookIds: usingTextbookIds,
        phoneNumber: phoneNumber,
        address: address,
        createdAt: DateTime.now(),
      );

      await docRef.set(academy.toFirestore());
      return academy;
    } catch (e) {
      debugPrint('Error creating academy: $e');
      throw Exception('기관 생성 실패: $e');
    }
  }

  /// 기관 조회
  Future<AcademyModel?> getAcademy(String academyId) async {
    try {
      final doc = await _firestore
          .collection('academies')
          .doc(academyId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        return null;
      }

      return AcademyModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting academy: $e');
      throw Exception('기관 조회 실패: $e');
    }
  }

  /// 소유자별 기관 목록 조회 (삭제되지 않은 것만)
  Future<List<AcademyModel>> getAcademiesByOwner(String ownerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('academies')
          .where('ownerId', isEqualTo: ownerId)
          .where('isDeleted', isEqualTo: false) // Soft Delete 필터링
          .get()
          .timeout(const Duration(seconds: 10));

      return querySnapshot.docs
          .map((doc) => AcademyModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting academies by owner: $e');
      throw Exception('기관 목록 조회 실패: $e');
    }
  }

  /// 모든 기관 조회 (개발자용) - 삭제된 것 포함 여부 선택 가능하면 좋으나, 기본은 활성만
  Future<List<AcademyModel>> getAllAcademies() async {
    try {
      final querySnapshot = await _firestore
          .collection('academies')
          .where('isDeleted', isEqualTo: false)
          .get();

      return querySnapshot.docs
          .map((doc) => AcademyModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting all academies: $e');
      throw Exception('전체 기관 목록 조회 실패: $e');
    }
  }

  /// 기관 수정
  Future<AcademyModel> updateAcademy(AcademyModel academy) async {
    try {
      final updatedAt = DateTime.now();
      final updatedAcademy = academy.copyWith(updatedAt: updatedAt);

      final data = updatedAcademy.toFirestore();

      // Firestore에 명시적으로 업데이트 실행
      await _firestore
          .collection('academies')
          .doc(academy.id)
          .set(data, SetOptions(merge: true)) // set(merge:true)가 가장 안전함
          .timeout(const Duration(seconds: 8));

      return updatedAcademy;
    } catch (e) {
      debugPrint('Academy Update Error: $e');
      rethrow;
    }
  }

  /// 기관 삭제 (Soft Delete)
  Future<void> deleteAcademy(String academyId) async {
    try {
      await _firestore.collection('academies').doc(academyId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error deleting academy: $e');
      throw Exception('기관 삭제 실패: $e');
    }
  }

  /// --- 관리자 기능 ---

  /// 삭제된 기관 목록 조회 (관리자용)
  /// ownerId가 있으면 해당 유저 것만, date가 있으면 해당 날짜 삭제분만
  Future<List<AcademyModel>> getDeletedAcademies({
    String? ownerId,
    DateTime? date,
  }) async {
    try {
      Query query = _firestore
          .collection('academies')
          .where('isDeleted', isEqualTo: true)
          .orderBy('deletedAt', descending: true);

      if (ownerId != null && ownerId.isNotEmpty) {
        query = query.where('ownerId', isEqualTo: ownerId);
      }

      // 날짜 필터링 (해당 날짜의 00:00 ~ 23:59)
      if (date != null) {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .where(
              'deletedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('deletedAt', isLessThan: Timestamp.fromDate(endOfDay));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => AcademyModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting deleted academies: $e');
      throw Exception('삭제된 기관 목록 조회 실패: $e');
    }
  }

  /// 기관 복구 (Restore)
  Future<void> restoreAcademy(String academyId) async {
    try {
      await _firestore.collection('academies').doc(academyId).update({
        'isDeleted': false,
        'deletedAt': null,
      });
    } catch (e) {
      debugPrint('Error restoring academy: $e');
      throw Exception('기관 복구 실패: $e');
    }
  }
}
