import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import '../models/education_report_model.dart';
import '../models/student_progress_model.dart';
import '../models/student_model.dart';

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

  /// 학생 명단 일괄 수정을 위해 ID를 포함한 엑셀 내보내기 [NEW]
  static void exportStudentListForUpdate({
    required List<StudentModel> students,
    required String academyName,
  }) {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    // 헤더 추가 - 첫 번째 열에 수정 금지 표시와 함께 ID 배치
    List<CellValue> header = [
      TextCellValue('수정금지_고유번호'),
      TextCellValue('이름(수정금지)'),
      TextCellValue('학년'),
      TextCellValue('반'),
      TextCellValue('번호'),
      TextCellValue('보호자 연락처'),
      TextCellValue('부'),
      TextCellValue('메모'),
    ];
    sheet.appendRow(header);

    for (var s in students) {
      sheet.appendRow([
        TextCellValue(s.id),
        TextCellValue(s.name),
        TextCellValue(s.grade?.toString() ?? ''),
        TextCellValue(s.classNumber ?? ''),
        TextCellValue(s.studentNumber ?? ''),
        TextCellValue(s.parentPhone ?? ''),
        TextCellValue(s.session?.toString() ?? ''),
        TextCellValue(s.note ?? ''),
      ]);
    }

    // 파일 저장
    final bytes = excel.save();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName =
          "${academyName}_학생명단_수정용_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx";

      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();

      html.Url.revokeObjectUrl(url);
    }
  }

  /// 학생별 교재 배정(주문) 상세 내역을 엑셀로 내보내기
  static void exportStudentOrderHistory({
    required List<StudentProgressModel> progressList,
    required List<StudentModel> students,
    required String academyName,
  }) {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    // 헤더 추가
    List<CellValue> header = [
      TextCellValue('배정일'),
      TextCellValue('학생 이름'),
      TextCellValue('교재명'),
      TextCellValue('권호'),
      TextCellValue('상태'),
    ];
    sheet.appendRow(header);

    // 데이터 추가 (날짜 내림차순 정렬)
    final sortedProgress = List<StudentProgressModel>.from(progressList)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    for (var p in sortedProgress) {
      final student = students.firstWhere(
        (s) => s.id == p.studentId,
        orElse: () => StudentModel(
          id: '',
          name: '퇴소/누락 학생',
          academyId: '',
          ownerId: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      sheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(p.updatedAt)),
        TextCellValue(student.name),
        TextCellValue(p.textbookName),
        TextCellValue('${p.volumeNumber}권'),
        TextCellValue(p.isCompleted ? '완료' : '학습중'),
      ]);
    }

    // 파일 저장
    final bytes = excel.save();
    if (bytes != null) {
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName =
          "${academyName}_교재배정내역_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx";

      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();

      html.Url.revokeObjectUrl(url);
    }
  }
}
