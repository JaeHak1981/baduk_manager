#!/bin/bash

# 설정: 프로젝트 루트에서 실행되어야 함
PROJECT_ROOT=$(pwd)

if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 오류: 프로젝트 루트(pubspec.yaml이 있는 곳)에서 실행해주세요."
    exit 1
fi

# 1. pubspec.yaml에서 버전 및 빌드 번호 추출
VERSION_LINE=$(grep "version: " pubspec.yaml)
VERSION_FULL=${VERSION_LINE#version: }
VERSION_NAME=${VERSION_FULL%+*}
VERSION_CODE=${VERSION_FULL#*+}

echo "🚀 안드로이드 빌드 시작: 버전 $VERSION_NAME, 빌드 번호 $VERSION_CODE"

# 2. Flutter 빌드 실행
flutter build apk --release

if [ $? -eq 0 ]; then
    # 3. releases 폴더 생성
    mkdir -p releases
    
    # 4. 파일명 정의 및 복사
    NEW_FILENAME="baduk_manager_v${VERSION_NAME}_${VERSION_CODE}.apk"
    TARGET_PATH="releases/$NEW_FILENAME"
    
    cp build/app/outputs/flutter-apk/app-release.apk "$TARGET_PATH"
    
    # 4-1. OneDrive 경로로 추가 복사 (사용자 요청)
    ONEDRIVE_PATH="/Users/jae_hak/Library/CloudStorage/OneDrive-개인/baduk_manager_개발"
    if [ -d "$ONEDRIVE_PATH" ]; then
        cp "$TARGET_PATH" "$ONEDRIVE_PATH/$NEW_FILENAME"
        echo "📂 OneDrive로 복사 완료: $ONEDRIVE_PATH/$NEW_FILENAME"
    else
        echo "⚠️ 경고: OneDrive 경로를 찾을 수 없어 복사를 건너뜁니다: $ONEDRIVE_PATH"
    fi
    echo "=================================================="
    echo "✅ 빌드 및 아카이빙 완료!"
    echo "파일 위치: $TARGET_PATH"
    echo "=================================================="
    
    # 5. SHA256 체크섬 계산 (Firebase Remote Config 업로드용)
    echo "🔍 SHA256 체크섬 (Remote Config용):"
    shasum -a 256 "$TARGET_PATH" | awk '{ print $1 }'
    echo "=================================================="
    
    # 6. 폴더 열기 (macOS용)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "releases/"
    fi
else
    echo "❌ 빌드 중 오류가 발생했습니다."
    exit 1
fi
