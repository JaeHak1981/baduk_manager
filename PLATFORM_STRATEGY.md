# 원생 관리 시스템 - 플랫폼 전략

## 지원 플랫폼

### ✅ Android (주요 플랫폼)
- **용도**: 학원에서 태블릿으로 사용
- **Firebase Auth**: 문제 없음
- **개발**: `flutter run -d <android-device>`

### ✅ Windows (보조 플랫폼)
- **용도**: 사무실/집에서 PC로 사용
- **Firebase Auth**: 문제 없음
- **개발**: `flutter run -d windows`

### ❌ macOS (제외)
- **문제**: Firebase Auth keychain 무한 프롬프트
- **결정**: macOS 버전 개발 중단
- **이유**: 
  - 실제 사용자가 macOS를 사용하지 않음
  - Android + Windows만으로 모든 요구사항 충족
  - 개발 시간 절약

## 개발 환경 설정

### macOS에서 개발하기
macOS에서 개발하되, **Android와 Windows 타겟으로만 빌드**:

```bash
# Android 태블릿에서 테스트
flutter run -d <android-device-id>

# Windows에서 테스트 (원격 또는 VM)
flutter run -d windows

# macOS는 빌드하지 않음
```

### 배포
- **Android**: Google Play Store 또는 APK 직접 배포
- **Windows**: EXE 파일 배포

## 결론

**macOS 버전은 만들지 않습니다.** 
- Android 태블릿 + Windows PC = 완벽한 솔루션
- Firebase Auth 문제 완전히 회피
- 개발 및 유지보수 간소화
