import 'package:cloud_firestore/cloud_firestore.dart';

/// 임시 주문 항목 모델
class TemporaryOrderItem {
  final String studentId;
  final String type; // 'none', 'select', 'extension'
  final String? textbookId;
  final String? textbookName;
  final int volume;

  TemporaryOrderItem({
    required this.studentId,
    required this.type,
    this.textbookId,
    this.textbookName,
    this.volume = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'type': type,
      'textbookId': textbookId,
      'textbookName': textbookName,
      'volume': volume,
    };
  }

  factory TemporaryOrderItem.fromMap(Map<String, dynamic> map) {
    return TemporaryOrderItem(
      studentId: map['studentId'] as String,
      type: map['type'] as String,
      textbookId: map['textbookId'] as String?,
      textbookName: map['textbookName'] as String?,
      volume: map['volume'] as int? ?? 1,
    );
  }
}

/// 학원별 임시 저장 전체 모델
class TemporaryOrderModel {
  final String academyId;
  final String ownerId;
  final List<TemporaryOrderItem> items;
  final String message;
  final DateTime updatedAt;

  TemporaryOrderModel({
    required this.academyId,
    required this.ownerId,
    required this.items,
    required this.message,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'academyId': academyId,
      'ownerId': ownerId,
      'items': items.map((i) => i.toMap()).toList(),
      'message': message,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TemporaryOrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return TemporaryOrderModel(
      academyId: data['academyId'] as String,
      ownerId: data['ownerId'] as String,
      items: (data['items'] as List)
          .map((i) => TemporaryOrderItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      message: data['message'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
