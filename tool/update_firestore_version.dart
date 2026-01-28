import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

void main() async {
  print('Firebase Firestore 업데이트 시작 (v1.0.7)...');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;
    final version = '1.0.7';
    final baseUrl =
        'https://github.com/JaeHak1981/baduk_manager/releases/download/v$version';

    await firestore.collection('system_config').doc('app_version').set({
      'latestVersion': version,
      'downloadUrlAndroid': '$baseUrl/baduk-manager-$version-android.apk',
      'downloadUrlWindows': '$baseUrl/baduk-manager-$version-windows.zip',
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('Firestore 업데이트 완료: v$version');
  } catch (e) {
    print('오류 발생: $e');
  }
}
