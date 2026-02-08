import 'package:flutter/material.dart';

/// 모든 Provider의 기반이 되는 클래스
class BaseProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 로딩 상태 설정
  void setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// 에러 메시지 설정
  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 비동기 작업 실행 헬퍼
  /// [showLoading]이 true이면 자동으로 로딩 상태를 관리합니다.
  Future<T?> runAsync<T>(
    Future<T> Function() action, {
    bool showLoading = true,
  }) async {
    if (showLoading) setLoading(true);
    clearError();

    try {
      return await action();
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      if (showLoading) setLoading(false);
    }
  }
}
