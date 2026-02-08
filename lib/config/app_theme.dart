import 'package:flutter/material.dart';

/// 앱 전체 디자인 시스템 상수 정의
class AppTheme {
  // --- Colors ---
  static const Color primaryColor = Colors.blue;
  static const Color accentColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;

  static Color get surfaceColor => Colors.grey.shade50;
  static Color get borderColor => Colors.grey.shade300;

  // --- Sizes & Spacing ---
  static const double cardPadding = 16.0;
  static const double cardMargin = 8.0;
  static const double cardBorderRadius = 12.0;

  /// 2단 리스트 개편을 위한 레이아웃 상수
  static const double listGutter = 12.0; // 카드 사이의 간격
  static const double screenHorizontalPadding = 20.0;

  // --- Text Styles ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle bodyText = TextStyle(fontSize: 14, color: blackDE);

  static const TextStyle caption = TextStyle(fontSize: 12, color: Colors.grey);

  static const Color blackDE = Color(0xFF333333);
}
