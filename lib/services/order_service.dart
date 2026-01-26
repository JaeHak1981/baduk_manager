import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveOrder(OrderModel order) async {
    try {
      await _firestore.collection('orders').add(order.toFirestore());
    } catch (e) {
      debugPrint('Error saving order: $e');
      throw Exception('주문 이력 저장 실패: $e');
    }
  }

  Future<List<OrderModel>> getOrdersByAcademy(
    String academyId, {
    String? ownerId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('orders')
          .where('academyId', isEqualTo: academyId);

      if (ownerId != null) {
        query = query.where('ownerId', isEqualTo: ownerId);
      }

      final snapshot = await query.orderBy('orderDate', descending: true).get();

      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting orders: $e');
      throw Exception('주문 이력 조회 실패: $e');
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e) {
      debugPrint('Error deleting order: $e');
      throw Exception('주문 이력 삭제 실패: $e');
    }
  }
}
