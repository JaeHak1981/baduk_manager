---
description: 전체 배포(웹 및 안드로이드) 절차 및 규칙
---

사용자가 "배포해" 또는 "빌드 및 배포"라고 요청할 시, **반드시** 아래 절차를 먼저 수행해야 합니다. **전달 없이 즉시 빌드를 시작하지 마십시오.**

### 1단계: 배포 정보 고지 및 확인 (필수)
빌드를 시작하기 전에 사용자에게 다음 사항을 먼저 보고하고 확인받아야 합니다.
1.  **배포 버전 이름**: `pubspec.yaml`의 현재 버전과 업데이트될 새 버전 명시 (예: `1.3.3+17`)
2.  **저장 및 배포 위치**:
    *   **웹**: Firebase Hosting (`baduk-teacher.web.app`)
    *   **안드로이드(APK)**: 로컬 `releases/` 폴더 및 클라우드(Google Drive, OneDrive) 경로

### 2단계: 승인 후 배포 실행
사용자가 확인하면 아래 명령어를 순차적으로 실행합니다.

#### 안드로이드 빌드 및 클라우드 배포
```bash
bash scripts/build_android.sh
```
*이 스크립트는 APK 빌드, 버전별 파일명 변경, 구글 드라이브 및 원드라이브 복사를 모두 수행합니다.*

#### 웹 빌드 및 Firebase 배포
```bash
flutter build web --release
firebase deploy --only hosting
```

### 3단계: 결과 보고
배포 완료 후 다음 정보를 최종 안내합니다.
- 웹 접속 URL
- 클라우드 내 APK 파일 이름 및 경로
- Remote Config 업데이트용 SHA256 체크섬 값
