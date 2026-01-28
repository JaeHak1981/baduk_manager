import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/platform_helper.dart';
import '../../providers/system_provider.dart';

/// 스마트 다운로드 안내 다이얼로그
class DownloadDialog extends StatelessWidget {
  const DownloadDialog({super.key});

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemProvider = context.watch<SystemProvider>();
    final recommendedOSName = PlatformHelper.recommendedOSName;

    // 플랫폼 판별
    String platformKey = '';
    if (PlatformHelper.isAndroid ||
        (PlatformHelper.isWeb &&
            Theme.of(context).platform == TargetPlatform.android)) {
      platformKey = 'android';
    } else if (PlatformHelper.isWindows ||
        (PlatformHelper.isWeb &&
            Theme.of(context).platform == TargetPlatform.windows)) {
      platformKey = 'windows';
    } else if (PlatformHelper.isMacOS ||
        (PlatformHelper.isWeb &&
            Theme.of(context).platform == TargetPlatform.macOS)) {
      platformKey = 'macos';
    }

    final downloadUrl = systemProvider.getDownloadUrl(platformKey);
    final isUpdateRequired = systemProvider.isUpdateRequired;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isUpdateRequired ? Icons.new_releases : Icons.system_update_alt,
            color: isUpdateRequired ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 10),
          Text(isUpdateRequired ? '새로운 버전 업데이트' : '스마트 다운로드'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUpdateRequired) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '최신 버전(${systemProvider.latestVersion})이 출시되었습니다.\n현재 버전: ${systemProvider.currentVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '현재 접속하신 기기는 [$recommendedOSName] 입니다.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            '기기에 최적화된 앱을 설치하시면 훨씬 더 빠르고 안정적으로 출석부와 진도를 관리하실 수 있습니다.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 20),

          // 추천 버튼 (가장 크게)
          _buildPlatformButton(
            context,
            label: downloadUrl.isEmpty
                ? '$recommendedOSName 버전 준비 중'
                : (isUpdateRequired
                      ? '최신 버전으로 업데이트 설치'
                      : '$recommendedOSName용 설치 파일 다운로드'),
            icon: _getIconForOS(recommendedOSName),
            onPressed: downloadUrl.isNotEmpty
                ? () => _launchUrl(downloadUrl)
                : () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('현재 $recommendedOSName 버전은 준비 중입니다.'),
                    ),
                  ),
            isRecommended: downloadUrl.isNotEmpty,
            isUpdate: isUpdateRequired && downloadUrl.isNotEmpty,
            isEnabled: downloadUrl.isNotEmpty,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildPlatformButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isRecommended = false,
    bool isUpdate = false,
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? (isUpdate ? Colors.red : (isRecommended ? Colors.blue : null))
              : Colors.grey.shade300,
          foregroundColor: isEnabled
              ? ((isUpdate || isRecommended) ? Colors.white : null)
              : Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: (isUpdate || isRecommended) ? 4 : 1,
        ),
      ),
    );
  }

  IconData _getIconForOS(String osName) {
    if (osName.contains('안드로이드')) return Icons.android;
    if (osName.contains('윈도우')) return Icons.window;
    if (osName.contains('맥')) return Icons.apple;
    return Icons.laptop;
  }
}
