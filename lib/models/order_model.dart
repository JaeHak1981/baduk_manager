import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String textbookName;
  final Map<int, int> volumeCounts; // 권호: 수량

  OrderItem({required this.textbookName, required this.volumeCounts});

  Map<String, dynamic> toMap() {
    return {
      'textbookName': textbookName,
      'volumeCounts': volumeCounts.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      textbookName: map['textbookName'] as String,
      volumeCounts: (map['volumeCounts'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as int),
      ),
    );
  }
}

class OrderModel {
  final String id;
  final String academyId;
  final String ownerId;
  final DateTime orderDate;
  final List<OrderItem> items;
  final int totalCount;
  final String message;

  OrderModel({
    required this.id,
    required this.academyId,
    required this.ownerId,
    required this.orderDate,
    required this.items,
    required this.totalCount,
    required this.message,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'academyId': academyId,
      'ownerId': ownerId,
      'orderDate': Timestamp.fromDate(orderDate),
      'items': items.map((e) => e.toMap()).toList(),
      'totalCount': totalCount,
      'message': message,
    };
  }

  factory OrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return OrderModel(
      id: snapshot.id,
      academyId: data['academyId'] as String,
      ownerId: data['ownerId'] as String,
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      items: (data['items'] as List)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalCount: data['totalCount'] as int,
      message: data['message'] as String,
    );
  }
}
