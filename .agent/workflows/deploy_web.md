---
description: 웹 버전 빌드 및 Firebase Hosting 배포 방법
---

이 워크플로우는 Flutter 웹 버전을 빌드하고 Firebase Hosting에 배포하는 단계를 안내합니다.
**주의: 배포 전 반드시 [.agent/workflows/deploy.md](file:///Users/jae_hak/Documents/flutter_pro/baduk_textbook_manager/.agent/workflows/deploy.md)의 확인 절차를 준수하십시오.**


// turbo
1. Flutter 웹 빌드 실행
```bash
flutter build web --release
```

// turbo
2. Firebase Hosting에 배포
```bash
firebase deploy --only hosting
```

3. 배포 완료 후 하단에 표시된 `Hosting URL`로 접속하여 확인하십시오.
