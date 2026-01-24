#!/bin/bash

# macOS 개발 환경 키체인 설정 스크립트
# 이 스크립트는 한 번만 실행하면 됩니다.

echo "======================================"
echo "macOS 개발 환경 키체인 설정"
echo "======================================"
echo ""
echo "이 스크립트는 Firebase Auth가 키체인에 접근할 수 있도록 설정합니다."
echo "한 번만 실행하면 이후로는 키체인 프롬프트가 나타나지 않습니다."
echo ""

# 키체인 잠금 해제 시간 연장 (4시간)
security set-keychain-settings -t 14400 -l ~/Library/Keychains/login.keychain-db

echo "✅ 키체인 설정 완료!"
echo ""
echo "이제 'flutter run -d macos'를 실행하세요."
echo "키체인 프롬프트가 나타나면:"
echo "  1. macOS 로그인 암호 입력"
echo "  2. '항상 허용' 클릭"
echo ""
echo "이후로는 절대 다시 나타나지 않습니다!"
