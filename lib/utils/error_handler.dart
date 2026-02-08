import 'package:flutter/material.dart';

/// 앱 전체의 에러 처리 및 사용자 알림을 담당하는 유틸리티
class AppErrorHandler {
  /// context 없이 스낵바를 띄우기 위한 키
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 사용자에게 스낵바 알림 표시
  static void showSnackBar(
    String message, {
    bool isError = true,
    VoidCallback? onRetry,
  }) {
    scaffoldMessengerKey.currentState?.clearSnackBars();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: onRetry != null ? 6 : 3),
        action: onRetry != null
            ? SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// 발생한 에러를 처리하고 사용자에게 알림
  static void handle(
    dynamic error, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    debugPrint(' [AppErrorHandler] Error: $error');

    String message = customMessage ?? _parseErrorMessage(error);
    showSnackBar(message, isError: true, onRetry: onRetry);
  }

  /// 에러 객체로부터 읽기 쉬운 메시지 추출
  static String _parseErrorMessage(dynamic error) {
    if (error is String) return error;

    // Firebase 또는 일반 Exception 처리 로직 추가 가능
    final errorStr = error.toString();
    if (errorStr.contains('network-request-failed')) {
      return '네트워크 연결이 원활하지 않습니다.';
    }
    if (errorStr.contains('permission-denied')) {
      return '권한이 없습니다.';
    }

    return errorStr;
  }
}
