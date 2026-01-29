import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../models/education_report_model.dart';

class ExcelUtils {
  /// 총평 문구 라이브러리를 CSV로 내보내기
  static void exportCommentTemplates(List<CommentTemplateModel> templates) {
    List<List<dynamic>> rows = [
      ['ID', 'Category', 'Content'], // 헤더
    ];

    for (var t in templates) {
      rows.add([t.id, t.category, t.content]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute(
        "download",
        "comment_templates_${DateTime.now().millisecondsSinceEpoch}.csv",
      )
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// CSV 파일에서 총평 문구 리스트 파싱하기
  static List<CommentTemplateModel> parseCommentTemplates(
    String csvContent,
    String academyId, {
    required String ownerId,
  }) {
    List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);
    List<CommentTemplateModel> templates = [];

    // 첫 번째 행은 헤더이므로 제외 (ID, Category, Content)
    for (var i = 1; i < rows.length; i++) {
      if (rows[i].length < 3) continue;

      templates.add(
        CommentTemplateModel(
          id: rows[i][0].toString().isEmpty
              ? DateTime.now().millisecondsSinceEpoch.toString() + i.toString()
              : rows[i][0].toString(),
          academyId: academyId,
          ownerId: ownerId,
          category: rows[i][1].toString(),
          content: rows[i][2].toString(),
          isCustom: true,
        ),
      );
    }

    return templates;
  }
}
