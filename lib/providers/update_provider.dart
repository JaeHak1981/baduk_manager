import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateProvider with ChangeNotifier {
  final UpdateService _updateService = UpdateService();

  bool _isInit = false;
  bool _showUpdateDialog = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  bool get showUpdateDialog => _showUpdateDialog;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;

  UpdateService get service => _updateService;

  /// 앱 시작 시 초기화 및 업데이트 체크
  Future<void> checkUpdate() async {
    if (!_isInit) {
      await _updateService.initialize();
      await _updateService.clearTempFiles(); // 구 버전 APK 자동 정리
      _isInit = true;
    }

    final available = await _updateService.checkUpdateAvailable();
    if (available) {
      _showUpdateDialog = true;
      notifyListeners();
    }
  }

  /// 업데이트 다이얼로그 닫기 (나중에 하기)
  void dismissDialog() {
    _showUpdateDialog = false;
    notifyListeners();
  }

  /// 업데이트 시작
  Future<void> startUpdate() async {
    _isDownloading = true;
    _errorMessage = null;
    _downloadProgress = 0.0;
    notifyListeners();

    await _updateService.downloadAndInstall(
      onProgress: (progress) {
        _downloadProgress = progress;
        notifyListeners();
      },
      onError: (error) {
        _isDownloading = false;
        _errorMessage = error;
        notifyListeners();
      },
      onSuccess: () {
        _isDownloading = false;
        _showUpdateDialog = false;
        notifyListeners();
      },
    );
  }

  /// 점검 모드 등 긴급 상황 체크
  bool get isUnderMaintenance => _isInit && _updateService.isUnderMaintenance;
}
