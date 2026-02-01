import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/education_report_model.dart';
import '../services/education_report_service.dart';
import '../utils/report_utils.dart';
import '../services/ai_service.dart';
import '../services/local_storage_service.dart';
import '../utils/report_comment_utils.dart';
import '../utils/default_report_templates.dart';

class EducationReportProvider with ChangeNotifier {
  final EducationReportService _service = EducationReportService();

  List<EducationReportModel> _reports = [];
  List<CommentTemplateModel> _templates = [];
  bool _isLoading = false;
  bool _isGenerating = false; // 생성 로딩 상태 추가
  String? _errorMessage;
  ReportTemplateType _selectedTemplateType = ReportTemplateType.classic;

  List<EducationReportModel> get reports => _reports;
  List<CommentTemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  ReportTemplateType get selectedTemplateType => _selectedTemplateType;

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

      // Firestore에 데이터가 없으면 기본 템플릿 사용
      if (_templates.isEmpty) {
        debugPrint('Firestore 템플릿이 비어있음. 기본 템플릿 사용.');
        _templates = DefaultReportTemplates.getTemplates();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('템플릿 로드 실패: $e. 기본 템플릿으로 폴백.');
      // 로드 실패 시에도 기본 템플릿 사용
      _templates = DefaultReportTemplates.getTemplates();
      notifyListeners();
    }
  }

  String _lastGenerationSource = 'none';
  String get lastGenerationSource => _lastGenerationSource;

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
    String? userInstructions,
    bool isAiMode = true, // 명시적 AI 모드 파라미터 추가
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
          totalClasses > 0 && (attendanceCount / totalClasses) > 0.8,
    );

    // 2. 가장 최근 리포트 조회 (보안 강화)
    final lastReport = await _service.getLastReport(
      studentId,
      academyId: academyId,
      ownerId: ownerId,
    );

    // 3. 문구 추천 (Hybrid: ReportCommentUtils 기반의 고품질 문구를 AI의 기초로 활용)
    String recommendedComment;
    String source = 'template';

    // [고도화된 기초 문구 생성]
    final referenceText = ReportCommentUtils.autoGenerateComment(
      studentName: studentName,
      scores: scores,
      textbookNames: textbookNames,
      volumes: volumes,
      templates: _templates.isNotEmpty
          ? _templates
          : DefaultReportTemplates.getTemplates(),
    );

    // AI 모드 가동 여부 확인
    final storage = LocalStorageService();
    final apiKey = await storage.getAiApiKey();
    final modelName = await storage.getAiModelName();

    if (isAiMode && apiKey != null && apiKey.isNotEmpty) {
      _isGenerating = true;
      notifyListeners();

      try {
        final aiService = AiService();
        final aiComment = await aiService.generateReportComment(
          apiKey: apiKey,
          studentName: studentName,
          textbookName: textbookNames.isNotEmpty ? textbookNames.first : '교재',
          scores: scores,
          attendanceRate: attendanceRate,
          modelName: modelName,
          userInstructions: userInstructions,
          referenceText: referenceText, // 고도화된 템플릿 문구를 참고용으로 전달
          isFastProgress:
              totalClasses > 0 && (attendanceCount / totalClasses) > 0.8,
        );

        if (aiComment != null) {
          recommendedComment = aiComment;
          source = 'ai';
        } else {
          recommendedComment = referenceText;
        }
      } catch (e) {
        debugPrint('AI Generation Error: $e');
        recommendedComment = referenceText;
      } finally {
        _isGenerating = false;
        notifyListeners();
      }
    } else {
      recommendedComment = referenceText;
    }

    _lastGenerationSource = source;

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
        category: '학습 성취',
        level: 1,
        content:
            '{{name}} 학생은 {{textbook}} 과정을 통해 바둑의 기초 규칙과 착수 금지, 따먹기 등 기본 원리를 차근차근 익히고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't2',
        academyId: academyId,
        ownerId: ownerId,
        category: '학습 성취',
        level: 2,
        content: '{{textbook}} 학습을 통해 초급 전술과 수읽기의 기초를 다지며 실전 능력을 키워가고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't3',
        academyId: academyId,
        ownerId: ownerId,
        category: '학습 성취',
        level: 3,
        content: '{{textbook}} 과정을 통해 고급 행마와 사활, 복합적인 수읽기 전략을 깊이 있게 연구하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't4',
        academyId: academyId,
        ownerId: ownerId,
        category: '학습 태도',
        content: '대국 중 집중력이 눈에 띄게 좋아졌습니다. {{name}} 학생의 성장이 기대됩니다.',
      ),
      CommentTemplateModel(
        id: 't5',
        academyId: academyId,
        ownerId: ownerId,
        category: '학습 태도',
        content: '예의 바른 태도로 대국에 임하며 친구들에게 좋은 본보기가 되고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't6',
        academyId: academyId,
        ownerId: ownerId,
        category: '격려',
        level: 1,
        content: '기초를 탄탄히 다지면 곧 더 재미있는 바둑의 세계를 경험하게 될 것입니다.',
      ),
      CommentTemplateModel(
        id: 't7',
        academyId: academyId,
        ownerId: ownerId,
        category: '격려',
        level: 3,
        content: '난이도가 높은 고비마다 포기하지 않고 끝까지 수읽기를 해내는 끈기가 대견합니다.',
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
