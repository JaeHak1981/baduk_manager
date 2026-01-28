import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/temporary_order_model.dart';

class TemporaryOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'temporaryOrders';

  /// 임시 주문 저장 (학원별 1건 유지)
  Future<void> saveTemporaryOrder(TemporaryOrderModel order) async {
    await _firestore
        .collection(_collection)
        .doc(order.academyId)
        .set(order.toFirestore());
  }

  /// 임시 주문 조회
  Future<TemporaryOrderModel?> getTemporaryOrder(String academyId) async {
    final doc = await _firestore.collection(_collection).doc(academyId).get();
    if (!doc.exists) return null;
    return TemporaryOrderModel.fromFirestore(doc);
  }

  /// 임시 주문 삭제
  Future<void> deleteTemporaryOrder(String academyId) async {
    await _firestore.collection(_collection).doc(academyId).delete();
  }
}
