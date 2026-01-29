import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/education_report_model.dart';
import '../services/education_report_service.dart';
import '../utils/report_utils.dart';

class EducationReportProvider with ChangeNotifier {
  final EducationReportService _service = EducationReportService();

  List<EducationReportModel> _reports = [];
  List<CommentTemplateModel> _templates = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<EducationReportModel> get reports => _reports;
  List<CommentTemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 특정 학생의 리포트 목록 로드 (보안 강화)
  Future<void> loadReports(
    String studentId, {
    required String academyId,
    required String ownerId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reports = await _service.getReportsForStudent(
        studentId,
        academyId: academyId,
        ownerId: ownerId,
      );
    } catch (e) {
      _errorMessage = '리포트 목록을 불러오지 못했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 문구 라이브러리 로드 (보안 강화)
  Future<void> loadTemplates(
    String academyId, {
    required String ownerId,
  }) async {
    try {
      _templates = await _service.getCommentTemplates(
        academyId,
        ownerId: ownerId,
      );
      if (_templates.isEmpty) {
        // 데이터가 없으면 초기 테스트 데이터 시딩
        await _seedInitialTemplates(academyId, ownerId: ownerId);
        _templates = await _service.getCommentTemplates(
          academyId,
          ownerId: ownerId,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('템플릿 로드 실패: $e');
    }
  }

  // 지능형 리포트 초안 생성 로직
  Future<EducationReportModel> generateDraft({
    required String academyId,
    required String ownerId,
    required String studentId,
    required String studentName,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> textbookNames,
    required List<String> textbookIds,
    required List<int> volumes,
    required int attendanceCount,
    required int totalClasses,
  }) async {
    // 1. 성취도 점수 자동 산출 (교재 권수 등에 따른 베이스라인 + 가변성)
    final maxVolume = volumes.isNotEmpty
        ? volumes.reduce((a, b) => a > b ? a : b)
        : 1;
    final attendanceRate = ReportUtils.calculateAttendanceRate(
      attendanceCount,
      totalClasses,
    );

    final scores = ReportUtils.calculateBaselineScores(
      maxVolume: maxVolume,
      attendanceRate: attendanceRate,
      isFastProgress:
          totalClasses > 0 && (attendanceCount / totalClasses) > 0.8, // 임시 로직
    );

    // 2. 가장 최근 리포트 조회 (성장 추합용, 보안 강화)
    final lastReport = await _service.getLastReport(
      studentId,
      academyId: academyId,
      ownerId: ownerId,
    );

    // 3. 중복 방지 문구 추천
    String recommendedComment = _recommendComment(
      studentName,
      textbookNames.isNotEmpty ? textbookNames.first : '교재',
    );

    return EducationReportModel(
      id: const Uuid().v4(),

      academyId: academyId,
      ownerId: ownerId,
      studentId: studentId,
      startDate: startDate,
      endDate: endDate,
      textbookIds: textbookIds,
      scores: scores,
      previousScores: lastReport?.scores,
      attendanceCount: attendanceCount,
      totalClasses: totalClasses,
      teacherComment: recommendedComment,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // 문구 추천 로직 (간단한 버전)
  String _recommendComment(String name, String textbook) {
    if (_templates.isEmpty)
      return '$name 학생은 이번 기간 동안 $textbook 학습을 성실히 수행하였습니다.';

    // 랜덤하게 하나 선택 (실제로는 중복 필터링 로직 추가 필요)
    final template = _templates[DateTime.now().millisecond % _templates.length];
    return template.content
        .replaceAll('{{name}}', name)
        .replaceAll('{{textbook}}', textbook);
  }

  // 리포트 저장
  Future<bool> saveReport(EducationReportModel report) async {
    try {
      await _service.saveReport(report);
      // 목록 업데이트
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _reports[index] = report;
      } else {
        _reports.insert(0, report);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '저장 실패: $e';
      notifyListeners();
      return false;
    }
  }

  // 초기 테스트 문구 10선 시딩 (보안 필터 포함)
  Future<void> _seedInitialTemplates(
    String academyId, {
    required String ownerId,
  }) async {
    final initialTemplates = [
      CommentTemplateModel(
        id: 't1',
        academyId: academyId,
        ownerId: ownerId,
        category: '칭찬',
        content: '{{name}} 학생은 {{textbook}} 과정을 통해 바둑의 기초를 아주 탄탄하게 다졌습니다.',
      ),
      CommentTemplateModel(
        id: 't2',
        academyId: academyId,
        ownerId: ownerId,
        category: '성취',
        content:
            '{{textbook}}의 난이도가 높아졌음에도 불구하고 {{name}} 학생만의 끈기로 멋지게 완수해냈습니다.',
      ),
      CommentTemplateModel(
        id: 't3',
        academyId: academyId,
        ownerId: ownerId,
        category: '집중',
        content: '대국 중 집중력이 눈에 띄게 좋아졌습니다. {{name}} 학생의 성장이 기대됩니다.',
      ),
      CommentTemplateModel(
        id: 't4',
        academyId: academyId,
        ownerId: ownerId,
        category: '창의',
        content: '정석에 얽매이지 않는 {{name}} 학생만의 독창적인 수가 인상적인 한 달이었습니다.',
      ),
      CommentTemplateModel(
        id: 't5',
        academyId: academyId,
        ownerId: ownerId,
        category: '태도',
        content: '예의 바른 태도로 대국에 임하며 친구들에게 좋은 본보기가 되고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't6',
        academyId: academyId,
        ownerId: ownerId,
        category: '격려',
        content: '수읽기 부분에서 조금만 더 신중함을 갖춘다면 훨씬 더 큰 도약이 가능할 것입니다.',
      ),
      CommentTemplateModel(
        id: 't7',
        academyId: academyId,
        ownerId: ownerId,
        category: '성실',
        content: '한 번도 거르지 않고 과제를 수행하는 성실함이 {{name}} 학생의 가장 큰 자산입니다.',
      ),
      CommentTemplateModel(
        id: 't8',
        academyId: academyId,
        ownerId: ownerId,
        category: '수기',
        content: '복기 과정에서 자신의 실수를 정확히 찾아내는 능력이 몰라보게 향상되었습니다.',
      ),
      CommentTemplateModel(
        id: 't9',
        academyId: academyId,
        ownerId: ownerId,
        category: '도전',
        content: '어려운 사활 문제에 도전하며 끝까지 포기하지 않는 모습이 대견합니다.',
      ),
      CommentTemplateModel(
        id: 't10',
        academyId: academyId,
        ownerId: ownerId,
        category: '종합',
        content: '종합적인 실력이 고르게 발달하고 있으며, 바둑을 즐기는 모습이 가장 보기 좋습니다.',
      ),
    ];

    await _service.batchUpdateTemplates(initialTemplates);
  }

  // 개별 템플릿 저장 (학원 전용)
  Future<bool> saveTemplate(CommentTemplateModel template) async {
    try {
      await _service.saveCommentTemplate(template);
      // 로컬 목록에 반영
      final index = _templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        _templates[index] = template;
      } else {
        _templates.add(template);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('템플릿 저장 실패: $e');
      return false;
    }
  }
}
