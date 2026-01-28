/**
 * GitHub Actions에서 Firestore의 버전 정보를 자동으로 업데이트하는 스크립트
 * 사용법: node update_version.js <version> <androidUrl> <windowsUrl> <macosUrl>
 */
const admin = require('firebase-admin');

// GitHub Secrets로부터 전달받은 서비스 계정 키 환경변수 사용
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const [,, version, androidUrl, windowsUrl, macosUrl] = process.argv;

if (!version || !androidUrl) {
  console.error("❌ 오류: 버전 정보와 안드로이드 URL은 필수입니다.");
  process.exit(1);
}

async function updateVersion() {
  try {
    const versionData = {
      latestVersion: version.startsWith('v') ? version.substring(1) : version,
      downloadUrlAndroid: androidUrl,
      downloadUrlWindows: windowsUrl || "",
      downloadUrlMac: macosUrl || "",
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('system_config').doc('app_version').set(versionData, { merge: true });
    
    console.log(`✅ 성공: Firestore에 버전 ${version} 정보가 성공적으로 업데이트되었습니다.`);
    process.exit(0);
  } catch (error) {
    console.error("❌ 실패: Firestore 업데이트 중 오류 발생:", error);
    process.exit(1);
  }
}

updateVersion();
