import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastLoadedAcademyId;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadOrders(
    String academyId, {
    String? ownerId,
    bool force = false,
  }) async {
    if (!force && _lastLoadedAcademyId == academyId && _orders.isNotEmpty)
      return;

    _isLoading = true;
    _errorMessage = null;
    _lastLoadedAcademyId = academyId;
    if (force || _lastLoadedAcademyId != academyId) {
      _orders = []; // 다른 학교거나 강제 로드면 일단 비움
    }
    notifyListeners();

    try {
      _orders = await _orderService.getOrdersByAcademy(
        academyId,
        ownerId: ownerId,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveOrder(OrderModel order) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _orderService.saveOrder(order);
      // 저장 후 해당 학교 내역을 다시 불러옴 (Firestore ID 등 최신화)
      await loadOrders(order.academyId, ownerId: order.ownerId, force: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOrder(
    String orderId,
    String academyId, {
    required String ownerId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _orderService.deleteOrder(orderId);
      await loadOrders(academyId, ownerId: ownerId, force: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
