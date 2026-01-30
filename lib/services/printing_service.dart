import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/education_report_model.dart';
import '../utils/report_template_utils.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
import 'package:universal_html/html.dart' as html;

class PrintingService {
  /// 위젯을 이미지로 캡처
  static Future<Uint8List?> captureWidgetToImage(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0); // 고해상도 캡처
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing widget: $e');
      return null;
    }
  }

  /// 캡처된 이미들을 PDF로 변환하여 출력/저장
  static Future<void> printCapturedImages({
    required List<Uint8List> images,
    required String fileName,
  }) async {
    final pdf = pw.Document();

    for (var imageBytes in images) {
      final image = pw.MemoryImage(imageBytes);
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero, // 이미지 기반이므로 여백 없이 꽉 채움
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
    );
  }

  /// 이미지를 파일로 직접 저장 (사용자가 위치 선택)
  static Future<bool> saveImageToFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return true;
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '통지표 이미지 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (outputFile == null) return false;

      final file = File(outputFile);
      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint('Error saving image file: $e');
      return false;
    }
  }

  /// (기존 HTML 방식 보존) 단일 교육 통지표 인쇄/저장
  static Future<void> printReport({
    required EducationReportModel report,
    required String studentName,
    required List<String> textbookNames,
    String? academyName,
  }) async {
    final htmlContent = ReportTemplateUtils.generateHtml(
      report: report,
      studentName: studentName,
      textbookNames: textbookNames,
      theme: report.templateId,
      academyName: academyName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: htmlContent,
      ),
      name: '교육통지표_${studentName}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// 여러 명의 교육 통지표 일괄 인쇄/저장
  static Future<void> printMultipleReports({
    required List<Map<String, dynamic>>
    reportDataList, // [{report, studentName, textbookNames}]
    String? academyName,
  }) async {
    // 여러 장을 하나의 PDF로 합치기 위해 html들을 결합 (간단한 방식: 각 페이지를 분리하도록 CSS 적용 필요)
    // 혹은 개별로 PDF 변환 후 합치기 (복잡함)
    // 간단히 하기 위해 HTML에 page-break-after: always; 를 추가하여 하나로 합칩니다.

    StringBuffer combinedHtml = StringBuffer();
    combinedHtml.write(
      '<html><head><style>@media print { .page-break { page-break-after: always; } }</style></head><body>',
    );

    for (int i = 0; i < reportDataList.length; i++) {
      final data = reportDataList[i];
      final html = ReportTemplateUtils.generateHtml(
        report: data['report'] as EducationReportModel,
        studentName: data['studentName'] as String,
        textbookNames: data['textbookNames'] as List<String>,
        theme: (data['report'] as EducationReportModel).templateId,
        academyName: academyName,
      );

      // body 내부 내용만 추출하거나, 전체를 래핑
      // 레이아웃 유틸을 조금 수정해서 body 내용만 가져오게 하거나, iframe처럼 활용
      // 여기서는 각 HTML을 div로 감싸고 페이지 분리를 적용합니다.
      combinedHtml.write('<div class="page-break">$html</div>');
    }

    combinedHtml.write('</body></html>');

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
        format: PdfPageFormat.a4,
        html: combinedHtml.toString(),
      ),
      name: '교육통지표_일괄발행_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
