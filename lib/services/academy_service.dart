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

  /// 소유자별 기관 목록 조회
  Future<List<AcademyModel>> getAcademiesByOwner(String ownerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('academies')
          .where('ownerId', isEqualTo: ownerId)
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

  /// 모든 기관 조회 (개발자용)
  Future<List<AcademyModel>> getAllAcademies() async {
    try {
      final querySnapshot = await _firestore.collection('academies').get();

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

  /// 기관 삭제
  Future<void> deleteAcademy(String academyId) async {
    try {
      await _firestore.collection('academies').doc(academyId).delete();
    } catch (e) {
      debugPrint('Error deleting academy: $e');
      throw Exception('기관 삭제 실패: $e');
    }
  }
}
