import 'package:flutter/material.dart';
import '../models/temporary_order_model.dart';
import '../services/temporary_order_service.dart';

class TemporaryOrderProvider with ChangeNotifier {
  final TemporaryOrderService _service = TemporaryOrderService();

  TemporaryOrderModel? _tempOrder;
  bool _isLoading = false;
  String? _errorMessage;

  TemporaryOrderModel? get tempOrder => _tempOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 임시 주문 로드
  Future<void> loadTemporaryOrder(String academyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tempOrder = await _service.getTemporaryOrder(academyId);
    } catch (e) {
      _errorMessage = '임시 저장 데이터를 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 임시 주문 저장
  Future<bool> saveTemporaryOrder(TemporaryOrderModel order) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.saveTemporaryOrder(order);
      _tempOrder = order;
      return true;
    } catch (e) {
      _errorMessage = '임시 저장에 실패했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 임시 주문 삭제
  Future<void> deleteTemporaryOrder(String academyId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.deleteTemporaryOrder(academyId);
      _tempOrder = null;
    } catch (e) {
      _errorMessage = '임시 저장 데이터를 삭제하는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }
}
