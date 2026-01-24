import 'package:cloud_firestore/cloud_firestore.dart';

/// 기관 전용 교재 모델 (선생님별 통합 관리용)
class TextbookModel {
  final String id;
  final String ownerId; // 등록한 선생님(소유주) ID
  final String name; // 교재 이름 (시리즈명)
  final int totalVolumes; // 전체 권수 (시리즈)
  final DateTime createdAt;

  TextbookModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.totalVolumes,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'totalVolumes': totalVolumes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TextbookModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return TextbookModel(
      id: snapshot.id,
      ownerId:
          data['ownerId'] as String? ??
          (data['academyId'] as String? ?? 'common'),
      name: data['name'] as String,
      totalVolumes: data['totalVolumes'] as int? ?? 1,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
