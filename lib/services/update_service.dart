import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final Dio _dio = Dio();

  /// 업데이트 관련 초기 설정
  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(minutes: 1),
      ),
    );
    await _remoteConfig.setDefaults({
      'latest_version': '1.0.0',
      'update_url': '',
      'changelog': '• 시스템 성능 및 안정성 개선',
      'checksum_sha256': '',
      'is_mandatory': false,
      'is_under_maintenance': false,
    });
    await _remoteConfig.fetchAndActivate();
  }

  /// 최신 버전 정보 가져오기
  String get latestVersion => _remoteConfig.getString('latest_version');
  String get updateUrl => _remoteConfig.getString('update_url');
  String get changelog => _remoteConfig.getString('changelog');
  String get checksumSha256 => _remoteConfig.getString('checksum_sha256');
  bool get isMandatory => _remoteConfig.getBool('is_mandatory');
  bool get isUnderMaintenance => _remoteConfig.getBool('is_under_maintenance');

  /// 업데이트 필요 여부 확인
  Future<bool> checkUpdateAvailable() async {
    if (kIsWeb) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    return _isNewerVersion(currentVersion, latestVersion);
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      return current != latest;
    }
    return false;
  }

  /// APK 다운로드 및 설치 (이어받기 지원)
  Future<void> downloadAndInstall({
    required Function(double) onProgress,
    required Function(String) onError,
    required VoidCallback onSuccess,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // 1. 권한 확인 (Android 8.0+)
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }

      final directory = await getExternalStorageDirectory();
      final filePath = '${directory!.path}/update.apk';
      final file = File(filePath);

      int downloadedBytes = 0;
      if (await file.exists()) {
        downloadedBytes = await file.length();
      }

      // 2. 다운로드 시작 (이어받기 지원)
      await _dio.download(
        updateUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
        options: Options(
          headers: downloadedBytes > 0
              ? {'Range': 'bytes=$downloadedBytes-'}
              : null,
          responseType: ResponseType.bytes,
        ),
        deleteOnError: false, // 실패 시 삭제하지 않고 이어받기 위해
      );

      // 3. 무결성 검증 (Checksum)
      if (checksumSha256.isNotEmpty) {
        final downloadedFile = File(filePath);
        final bytes = await downloadedFile.readAsBytes();
        final digest = sha256.convert(bytes);

        if (digest.toString() != checksumSha256) {
          await downloadedFile.delete();
          onError('파일 무결성 검증 실패 (해시 불일치)');
          return;
        }
      }

      // 4. 설치 실행
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        onError('설치 실행 실패: ${result.message}');
      } else {
        onSuccess();
      }
    } catch (e) {
      onError('다운로드 중 오류 발생: $e');
    }
  }

  /// 임시 파일 정리
  Future<void> clearTempFiles() async {
    try {
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory!.path}/update.apk';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('임시 파일 삭제 실패: $e');
    }
  }
}
