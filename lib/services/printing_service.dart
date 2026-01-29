import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/education_report_model.dart';
import '../utils/report_template_utils.dart';

class PrintingService {
  /// 단일 교육 통지표 인쇄/저장
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
