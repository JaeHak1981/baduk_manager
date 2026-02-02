import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// 앱 전반에서 사용되는 UI 규격 및 치수 정의
class AppDimensions {
  /// 플랫폼 및 기기별 하단 여백 계산
  ///
  /// [Web/Desktop]: 16.0px (시스템 바 없음)
  /// [Mobile/Tablet]: SafeArea 하단 여백 + 최소 여유분(20.0px) 또는 60.0px 중 큰 값
  static double getBottomInset(BuildContext context) {
    if (kIsWeb) return 16.0;

    final viewPaddingBottom = MediaQuery.of(context).padding.bottom;

    // 데스크톱 플랫폼(Windows, macOS) 판별
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktop) return 16.0;

    // 모바일/태블릿: 시스템 바 영역(SafeArea)에 여유분 추가
    return (viewPaddingBottom > 0) ? (viewPaddingBottom + 20.0) : 60.0;
  }

  /// 입력 폼 최하단에서 버튼에 가려지지 않기 위해 필요한 여백
  static double getFormBottomInset(BuildContext context) {
    return getBottomInset(context) + 40.0;
  }
}
