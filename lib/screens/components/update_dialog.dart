import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/update_provider.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final updateProvider = context.watch<UpdateProvider>();
    final service = updateProvider.service;

    return PopScope(
      canPop: !updateProvider.isDownloading && !service.isMandatory,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Text(
              updateProvider.isDownloading ? '업데이트 다운로드 중' : '새로운 업데이트 발견',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!updateProvider.isDownloading) ...[
              Text(
                '새 버전(${service.latestVersion})을 사용할 수 있습니다.\n최신 기능을 위해 업데이트를 권장합니다.',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              // 동적 ChangeLog 표시
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '새로운 변화:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.changelog.isNotEmpty
                          ? service.changelog
                          : '• 시스템 성능 및 안정성 개선',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: updateProvider.downloadProgress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  '${(updateProvider.downloadProgress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '다운로드가 끝나면 설치 화면으로 연결됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
            if (updateProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                updateProvider.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: updateProvider.isDownloading
            ? []
            : [
                if (!service.isMandatory)
                  TextButton(
                    onPressed: () => updateProvider.dismissDialog(),
                    child: const Text(
                      '나중에 하기',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () => updateProvider.startUpdate(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('지금 업데이트'),
                ),
              ],
      ),
    );
  }
}
