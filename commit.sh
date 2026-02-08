#!/bin/bash

# 원생 관리 시스템 - 자동 커밋 스크립트
# 사용법: ./commit.sh "단계" "기능명" "상세설명" "변경사항1" "변경사항2" ...

if [ $# -lt 3 ]; then
  echo "❌ 사용법: ./commit.sh \"단계\" \"기능명\" \"상세설명\" \"변경사항1\" \"변경사항2\" ..."
  echo ""
  echo "예시:"
  echo "./commit.sh \\"
  echo "  \"1단계-인증\" \\"
  echo "  \"AuthService 구현 완료\" \\"
  echo "  \"username을 이메일로 자동 변환하는 로그인 시스템\" \\"
  echo "  \"lib/services/auth_service.dart 생성\" \\"
  echo "  \"signIn, createDeveloperAccount 메서드 구현\""
  exit 1
fi

STAGE=$1
FEATURE=$2
DESCRIPTION=$3
shift 3

# 커밋 메시지 생성
echo "[$STAGE] $FEATURE: $DESCRIPTION" > /tmp/commit_msg.txt
echo "" >> /tmp/commit_msg.txt

if [ $# -gt 0 ]; then
  for change in "$@"; do
    echo "- $change" >> /tmp/commit_msg.txt
  done
fi

# Git 상태 확인
if [ ! -d .git ]; then
  echo "⚠️  Git 저장소가 초기화되지 않았습니다."
  echo "다음 명령어를 실행하세요:"
  echo "  git init"
  echo "  git remote add origin YOUR_GITHUB_URL"
  exit 1
fi

# 변경사항 확인
if [ -z "$(git status --porcelain)" ]; then
  echo "⚠️  커밋할 변경사항이 없습니다."
  exit 0
fi

# 커밋 및 푸시
echo "📝 커밋 메시지:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat /tmp/commit_msg.txt
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

git add .
git commit -F /tmp/commit_msg.txt

if [ $? -eq 0 ]; then
  echo "✅ 커밋 완료!"
  
  # 원격 저장소 확인
  if git remote | grep -q origin; then
    echo "📤 GitHub에 푸시 중..."
    git push origin main
    
    if [ $? -eq 0 ]; then
      echo "✅ GitHub 푸시 완료!"
    else
      echo "⚠️  푸시 실패. 수동으로 'git push origin main'을 실행하세요."
    fi
  else
    echo "⚠️  원격 저장소가 설정되지 않았습니다."
    echo "다음 명령어로 설정하세요:"
    echo "  git remote add origin YOUR_GITHUB_URL"
  fi
else
  echo "❌ 커밋 실패!"
  exit 1
fi
