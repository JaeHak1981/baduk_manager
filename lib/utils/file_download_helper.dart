import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class FileDownloadHelper {
  /// 데이터를 CSV 파일로 다운로드합니다.
  static void downloadCsv({required String csvData, required String fileName}) {
    if (kIsWeb) {
      final bytes = utf8.encode(csvData);
      // 한글 깨짐 방지를 위한 BOM(Byte Order Mark) 추가
      final encodedBytes = [0xEF, 0xBB, 0xBF, ...bytes];
      _downloadWeb(encodedBytes, fileName, 'text/csv;charset=utf-8');
    } else {
      // 앱(Android/iOS/Desktop)은 추후 path_provider 등을 사용하여 구현 가능
      // 현재는 웹 버전 테스트 중이므로 웹 버전을 우선 구현합니다.
      debugPrint('App download not implemented yet');
    }
  }

  /// 바이너리 데이터(예: 엑셀 파일)를 다운로드합니다.
  static void downloadBytes({
    required List<int> bytes,
    required String fileName,
    String mimeType =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  }) {
    if (kIsWeb) {
      _downloadWeb(bytes, fileName, mimeType);
    } else {
      debugPrint('App download not implemented yet');
    }
  }

  /// 웹 브라우저에서 다운로드를 실행합니다.
  static void _downloadWeb(List<int> bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..setAttribute('download', fileName)
      ..click();

    // 즉시 revoke하면 일부 브라우저에서 다운로드가 실패할 수 있으므로
    // 충분한 시간(예: 30초) 뒤에 해제하여 브라우저가 처리를 마칠 수 있게 합니다.
    Future.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
