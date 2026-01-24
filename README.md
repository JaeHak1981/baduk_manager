# 바둑 학원 관리 시스템

Firebase 기반 크로스 플랫폼 학원 관리 애플리케이션

## 지원 플랫폼

### ✅ Android (주요)
- 학원 태블릿용
- Firebase Auth 완벽 지원
- 실시간 데이터 동기화

### ✅ Windows (보조)
- 사무실/집 PC용
- Firebase Auth 완벽 지원
- 실시간 데이터 동기화

### ❌ macOS (미지원)
- Firebase Auth keychain 이슈로 인해 지원 중단
- 개발 환경으로만 사용 (Android/Windows 타겟 빌드)

## 개발 환경

### macOS에서 개발하기
```bash
# Android 기기 연결 후
flutter devices
flutter run -d <android-device-id>

# Windows (원격 또는 VM)
flutter run -d windows
```

### 빌드 및 배포
```bash
# Android APK
flutter build apk --release

# Windows EXE
flutter build windows --release
```

## 기술 스택
- **Frontend**: Flutter
- **Backend**: Firebase (Authentication + Firestore)
- **상태관리**: Provider
- **플랫폼**: Android, Windows

## 다음 단계
1. Android 태블릿에서 테스트
2. 학원 관리 기능 구현
3. 학생 관리 기능 구현
4. Windows 버전 테스트
