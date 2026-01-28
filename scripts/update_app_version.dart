import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:baduk_textbook_manager/firebase_options.dart';

void main() {
  test('Update App Version Info in Firestore', () async {
    // This is a script-like test to update Firestore
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;

    final versionData = {
      'latestVersion': '1.0.9',
      'downloadUrlAndroid':
          'https://github.com/JaeHak1981/baduk_manager/releases/download/v1.0.9/baduk-manager-v1.0.9-android.apk',
      'downloadUrlWindows':
          'https://github.com/JaeHak1981/baduk_manager/releases/download/v1.0.9/baduk-manager-v1.0.9-windows.zip',
      'downloadUrlMac':
          'https://github.com/JaeHak1981/baduk_manager/releases/download/v1.0.9/baduk-manager-v1.0.9-macos.zip',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await firestore
          .collection('system_config')
          .doc('app_version')
          .set(versionData, SetOptions(merge: true));
      print('✅ 성공: Firestore에 버전 1.0.9 정보가 업데이트되었습니다.');
    } catch (e) {
      print('❌ 실패: Firestore 업데이트 중 오류 발생: $e');
    }
  });
}
