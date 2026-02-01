import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/education_report_model.dart';
import '../services/education_report_service.dart';
import '../utils/report_utils.dart';
import '../services/ai_service.dart';
import '../services/local_storage_service.dart';
import '../constants/default_comment_templates.dart';

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
        _templates = getDefaultCommentTemplates();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('템플릿 로드 실패: $e. 기본 템플릿으로 폴백.');
      // 로드 실패 시에도 기본 템플릿 사용
      _templates = getDefaultCommentTemplates();
      notifyListeners();
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
          totalClasses > 0 && (attendanceCount / totalClasses) > 0.8, // 임시 로직
    );

    // 2. 가장 최근 리포트 조회 (성장 추합용, 보안 강화)
    final lastReport = await _service.getLastReport(
      studentId,
      academyId: academyId,
      ownerId: ownerId,
    );

    // 3. 중복 방지 문구 추천 (Hybrid)
    String recommendedComment;
    String source = 'template'; // 'ai' or 'template'

    // [TAG 전략]: AI에게 전달할 기본 추천 문구(템플릿 기반) 먼저 생성
    final referenceTemplates = _recommendComment(
      studentName,
      textbookNames.isNotEmpty ? textbookNames.first : '교재',
      level: maxVolume,
    );

    // API 키 확인 및 AI 모드 활성화 여부 체크
    final storage = LocalStorageService();
    final apiKey = await storage.getAiApiKey();
    final modelName = await storage.getAiModelName(); // 모델명 로드

    if (isAiMode && apiKey != null && apiKey.isNotEmpty) {
      // AI 생성 시도
      _isGenerating = true; // 로딩 시작
      notifyListeners(); // 로딩 상태 알림

      try {
        final aiService = AiService();
        final isFastProgress =
            totalClasses > 0 && (attendanceCount / totalClasses) > 0.8;

        final aiComment = await aiService.generateReportComment(
          apiKey: apiKey,
          studentName: studentName,
          textbookName: textbookNames.isNotEmpty ? textbookNames.first : '교재',
          scores: scores,
          attendanceRate: attendanceRate,
          modelName: modelName,
          userInstructions: userInstructions,
          referenceText: referenceTemplates, // TAG: 템플릿 문구를 참고용으로 전달
          isFastProgress: isFastProgress, // 데이터 상세화
        );

        if (aiComment != null) {
          recommendedComment = aiComment;
          source = 'ai';
        } else {
          // AI 실패 시 폴백
          recommendedComment = referenceTemplates;
        }
      } catch (e) {
        debugPrint('AI Generation Error: $e');
        recommendedComment = referenceTemplates;
      } finally {
        _isGenerating = false; // 로딩 종료
        notifyListeners();
      }
    } else {
      // 키 없음 -> 기존 로직
      recommendedComment = referenceTemplates;
    }

    // 소스 정보를 TeacherComment 앞부분에 메타데이터로 숨기거나, 별도 필드가 없으므로
    // 임시로 Provider 상태에 저장하여 UI에서 읽을 수 있게 하거나,
    // 여기서는 UI에서 확인하기 쉽게 스낵바 호출을 위해 리턴값에 포함하지 않고
    // Provider의 멤버 변수로 최근 생성 소스를 저장함.
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

  String _lastGenerationSource = 'none';
  String get lastGenerationSource => _lastGenerationSource;

  // 문구 추천 로직 (간단한 버전)
  String _recommendComment(String name, String textbook, {int? level}) {
    if (_templates.isEmpty) {
      return '$name 학생은 이번 기간 동안 $textbook 학습을 성실히 수행하였습니다. 대국 중 집중력이 눈에 띄게 좋아졌으며, 앞으로의 성장이 더욱 기대됩니다.';
    }

    // 1. 카테고리별로 템플릿 분류
    final achievement = _templates.where((t) => t.category == '학습 성취').toList();
    final attitude = _templates.where((t) => t.category == '학습 태도').toList();
    final encouragement = _templates.where((t) => t.category == '격려').toList();

    String result = '';
    final random = Random();

    // 2. 학습 성취 (급수/레벨 고려)
    if (achievement.isNotEmpty) {
      final levelMatches = achievement.where((t) => t.level == level).toList();
      final targetList = levelMatches.isNotEmpty ? levelMatches : achievement;
      final t = targetList[random.nextInt(targetList.length)];
      result += '${t.content} ';
    }

    // 3. 학습 태도
    if (attitude.isNotEmpty) {
      final t = attitude[random.nextInt(attitude.length)];
      result += '${t.content} ';
    }

    // 4. 격려
    if (encouragement.isNotEmpty) {
      final t = encouragement[random.nextInt(encouragement.length)];
      result += t.content;
    }

    if (result.trim().isEmpty) {
      return '$name 학생은 이번 기간 동안 $textbook 학습을 성실히 수행하였습니다.';
    }

    return result
        .replaceAll('{{name}}', name)
        .replaceAll('{{textbook}}', textbook)
        .trim();
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
