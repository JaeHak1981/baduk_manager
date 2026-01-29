import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/education_report_model.dart';

class EducationReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'educationReports';
  static const String _templateCollection = 'commentTemplates';

  // 교육 통지표 저장
  Future<void> saveReport(EducationReportModel report) async {
    await _db.collection(_collection).doc(report.id).set(report.toFirestore());
  }

  // 특정 학생의 교육 통지표 목록 조회 (보안 강화)
  Future<List<EducationReportModel>> getReportsForStudent(
    String studentId, {
    required String academyId,
    required String ownerId,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where('studentId', isEqualTo: studentId);

    if (ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final snapshot = await query.get();

    final reports = snapshot.docs
        .map((doc) => EducationReportModel.fromFirestore(doc))
        .toList();

    // 메모리 정렬
    reports.sort((a, b) => b.endDate.compareTo(a.endDate));
    return reports;
  }

  // 가장 최근 통지표 조회 (성장 추이 비교용, 보안 강화)
  Future<EducationReportModel?> getLastReport(
    String studentId, {
    required String academyId,
    required String ownerId,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where('studentId', isEqualTo: studentId);

    if (ownerId.isNotEmpty) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) return null;

    final reports = snapshot.docs
        .map((doc) => EducationReportModel.fromFirestore(doc))
        .toList();

    // 메모리 정렬 후 최신 항목 반환
    reports.sort((a, b) => b.endDate.compareTo(a.endDate));
    return reports.first;
  }

  // 총평 문구 템플릿 로드 (시스템 공용 + 학원 전용, 보안 강화)
  Future<List<CommentTemplateModel>> getCommentTemplates(
    String academyId, {
    required String ownerId,
  }) async {
    // 1. 시스템 공용 템플릿
    final systemSnapshot = await _db
        .collection(_templateCollection)
        .where('academyId', isEqualTo: 'system')
        .get();

    // 2. 학원 전용 템플릿 (보안 필터)
    final academySnapshot = await _db
        .collection(_templateCollection)
        .where('academyId', isEqualTo: academyId)
        .get();

    final List<CommentTemplateModel> templates = [];
    templates.addAll(
      systemSnapshot.docs.map((doc) => CommentTemplateModel.fromFirestore(doc)),
    );
    templates.addAll(
      academySnapshot.docs.map(
        (doc) => CommentTemplateModel.fromFirestore(doc),
      ),
    );

    return templates;
  }

  // 새 문구 템플릿 저장 (학원 전용)
  Future<void> saveCommentTemplate(CommentTemplateModel template) async {
    await _db
        .collection(_templateCollection)
        .doc(template.id)
        .set(template.toFirestore());
  }

  // 엑셀 일괄 업로드용 템플릿 매스 업데이트 (샘플)
  Future<void> batchUpdateTemplates(
    List<CommentTemplateModel> templates,
  ) async {
    final batch = _db.batch();
    for (var t in templates) {
      final docRef = _db.collection(_templateCollection).doc(t.id);
      batch.set(docRef, t.toFirestore());
    }
    await batch.commit();
  }
}
