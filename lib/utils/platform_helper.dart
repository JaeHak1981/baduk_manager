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
      // 웹의 경우 상세 판별 시도
      return _getWebRecommendedOS();
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '안드로이드 태블릿/폰';
      case TargetPlatform.windows:
        return '윈도우 PC';
      case TargetPlatform.macOS:
        return '맥(macOS)';
      default:
        return '기기';
    }
  }

  static String _getWebRecommendedOS() {
    // 1. TargetPlatform 기반 기본 판별
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
        return '기기';
    }
  }

  /// 현재 플랫폼이 안드로이드(또는 안드로이드 기반 웹)인지 확인
  static bool get isAndroid {
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    return false;
  }

  /// 현재 플랫폼이 윈도우(또는 윈도우 기반 웹)인지 확인
  static bool get isWindows {
    if (defaultTargetPlatform == TargetPlatform.windows) return true;
    return false;
  }

  /// 현재 플랫폼이 맥(또는 맥 기반 웹)인지 확인
  static bool get isMacOS {
    if (defaultTargetPlatform == TargetPlatform.macOS) return true;
    return false;
  }
}
