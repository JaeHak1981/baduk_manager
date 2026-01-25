import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/textbook_model.dart';

/// 교재 정보 서비스 (기관별 커스텀 시리즈 지원)
class TextbookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'textbooks';

  /// 교재 시리즈 생성 (학원별)
  Future<String> createTextbook(TextbookModel textbook) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(textbook.toFirestore());
    return docRef.id;
  }

  /// 선생님별 교재 목록 조회 (+ 공용 교재 포함)
  Future<List<TextbookModel>> getOwnerTextbooks(String ownerId) async {
    // 1. 선생님 소유 교재
    final ownerSnapshot = await _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .get();

    // 2. 공용 교재 (common) - academyId 혹은 ownerId가 common인 것들
    final commonSnapshot = await _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: 'common')
        .get();

    final List<TextbookModel> list = [];
    list.addAll(
      ownerSnapshot.docs.map((doc) => TextbookModel.fromFirestore(doc)),
    );
    list.addAll(
      commonSnapshot.docs.map((doc) => TextbookModel.fromFirestore(doc)),
    );

    return list;
  }

  /// 특정 교재 상세 정보 조회
  Future<TextbookModel?> getTextbook(String textbookId) async {
    final doc = await _firestore.collection(_collection).doc(textbookId).get();
    if (!doc.exists) return null;
    return TextbookModel.fromFirestore(doc);
  }

  /// 교재 시리즈 정보 수정
  Future<void> updateTextbook(
    String textbookId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(_collection).doc(textbookId).update(data);
  }

  /// 교재 삭제
  Future<void> deleteTextbook(String textbookId) async {
    await _firestore.collection(_collection).doc(textbookId).delete();
  }
}
