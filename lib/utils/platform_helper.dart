import 'package:flutter/foundation.dart';

/// 앱이 실행 중인 플랫폼 정보를 제공하는 헬퍼 클래스
class PlatformHelper {
  /// 현재 웹 브라우저에서 실행 중인지 여부
  static bool get isWeb => kIsWeb;

  /// 현재 플랫폼 명칭 반환 (Android, iOS, Windows, macOS, Linux, Web)
  static String get platformName {
    if (kIsWeb) return 'Web';
    return defaultTargetPlatform.name.toUpperCase();
  }

  /// 현재 기기가 데스크탑(Windows, macOS, Linux)인지 여부
  static bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// 접속 환경에 따른 권장 안내 명칭
  static String get recommendedOSName {
    if (kIsWeb) {
      // 웹 브라우저의 경우 UserAgent를 통해 상세 체크가 필요할 수 있으나
      // 기본적으로 defaultTargetPlatform이 어느 정도 판별해줌
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return '안드로이드 태블릿/폰';
        case TargetPlatform.iOS:
          return '아이폰/아이패드';
        case TargetPlatform.windows:
          return '윈도우 PC';
        case TargetPlatform.macOS:
          return '맥(macOS)';
        default:
          return '기기 전용 앱';
      }
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      default:
        return '시스템';
    }
  }

  /// 현재 플랫폼이 안드로이드인지 확인
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 현재 플랫폼이 윈도우인지 확인
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// 현재 플랫폼이 맥인지 확인
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
}
