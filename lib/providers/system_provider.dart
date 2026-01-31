import 'package:flutter/foundation.dart';
import '../services/system_service.dart';

class SystemProvider extends ChangeNotifier {
  final SystemService _service = SystemService();

  String _currentVersion = '';
  String _latestVersion = '';
  bool _isUpdateRequired = false;
  Map<String, dynamic>? _config;
  bool _isLoading = false;

  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  bool get isUpdateRequired => _isUpdateRequired;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get config => _config;

  /// 초기 데이터 로드 및 버전 체크
  Future<void> checkUpdate() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentVersion = await _service.getCurrentVersion();
      _config = await _service.getLatestVersionConfig();

      if (_config != null && _config!['latestVersion'] != null) {
        _latestVersion = _config!['latestVersion'];

        // 버전이 높은지 먼저 확인
        bool versionNewer = _service.isUpdateRequired(
          _currentVersion,
          _latestVersion,
        );

        // 현재 플랫폼의 다운로드 링크가 있는지 확인 (링크가 없으면 업데이트 유도 안 함)
        String platform = '';
        if (kIsWeb) {
          // 웹에서는 안드로이드일 경우 로컬 파일 다운로드 허용
          _isUpdateRequired = versionNewer;
        } else {
          platform = defaultTargetPlatform.name.toLowerCase();
          String downloadUrl = getDownloadUrl(platform);
          _isUpdateRequired = versionNewer && downloadUrl.isNotEmpty;
        }
      }
    } catch (e) {
      print('업데이트 체크 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 특정 플랫폼의 다운로드 URL 가져오기
  String getDownloadUrl(String platform) {
    if (_config == null) return '';
    switch (platform.toLowerCase()) {
      case 'android':
        // 캐시 회피를 위해 쿼리 파라미터 추가
        if (kIsWeb)
          return '/app-release.zip?v=${DateTime.now().millisecondsSinceEpoch}';
        return _config!['downloadUrlAndroid'] ??
            _config!['downloadURLAndroid'] ??
            '';
      case 'windows':
        return _config!['downloadUrlWindows'] ??
            _config!['downloadURLWindows'] ??
            '';
      case 'macos':
        return _config!['downloadUrlMac'] ?? _config!['downloadURLMac'] ?? '';
      default:
        return '';
    }
  }
}
