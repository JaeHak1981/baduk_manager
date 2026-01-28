import 'package:flutter/material.dart';
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
        _isUpdateRequired = _service.isUpdateRequired(
          _currentVersion,
          _latestVersion,
        );
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
        return _config!['downloadUrlAndroid'] ?? '';
      case 'windows':
        return _config!['downloadUrlWindows'] ?? '';
      case 'macos':
        return _config!['downloadUrlMac'] ?? '';
      default:
        return '';
    }
  }
}
