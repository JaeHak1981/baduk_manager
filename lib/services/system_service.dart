import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 시스템 관련 데이터(버전, 공지사항 등)를 처리하는 서비스
class SystemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 서버에서 최신 버전 정보를 가져옴
  Future<Map<String, dynamic>?> getLatestVersionConfig() async {
    try {
      final doc = await _firestore
          .collection('system_config')
          .doc('app_version')
          .get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('버전 정보 로드 실패: $e');
    }
    return null;
  }

  /// 현재 설치된 앱의 버전 정보를 가져옴 (네이티브 앱 전용)
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      return '1.0.0'; // 기본값 (웹 등에서 오류 시)
    }
  }

  /// 업데이트가 필요한지 확인 (현재 버전 < 서버 최신 버전)
  bool isUpdateRequired(String currentVersion, String latestVersion) {
    // 단순 문자열 비교보다 버전 포맷(x.y.z) 비교가 정확함
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final latestParts = latestVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true; // 서버 버전이 형식이 더 길면 업데이트 필요
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      // 파싱 실패 시 단순 비교
      return currentVersion != latestVersion;
    }
    return false;
  }
}
