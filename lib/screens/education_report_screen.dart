import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/student_progress_model.dart';
import '../models/education_report_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import '../services/printing_service.dart';
import 'components/radar_chart_widget.dart';
import 'components/resizable_draggable_wrapper.dart';
import 'components/comment_grid_picker.dart';
import '../providers/education_report_provider.dart';
import '../utils/report_comment_utils.dart';

class EducationReportScreen extends StatefulWidget {
  final AcademyModel academy;

  const EducationReportScreen({super.key, required this.academy});

  @override
  State<EducationReportScreen> createState() => _EducationReportScreenState();
}

class _EducationReportScreenState extends State<EducationReportScreen> {
  Set<String> _selectedStudentIds = {};
  String? _customAcademyName;
  String? _customReportTitle;
  String? _customReportDate;
  Map<String, String> _customStudentLevels = {}; // 학생 ID -> 커스텀 급수
  bool _showLevel = true; // 급수 표시 여부
  Map<String, AchievementScores> _customScores = {}; // 학생 ID -> 커스텀 점수
  bool _showRadarChart = true; // 레이더 차트 표시 여부
  bool _showProgress = true; // 교재 현황 표시 여부
  bool _showCompetency = true; // 역량 점수바 표시 여부
  Map<String, String> _customComments = {}; // 학생 ID -> 커스텀 의견
  bool _isLayoutEditing = false; // 레이아웃 편집 모드 여부
  Map<String, String> _customAcademyNames = {}; // 학생 ID -> 커스텀 학원명
  Map<String, String> _customReportTitles = {}; // 학생 ID -> 커스텀 제목
  Map<String, Map<String, WidgetLayout>> _studentLayouts =
      {}; // 학생 ID -> (위젯 ID -> 레이아웃)
  final Map<String, GlobalKey> _reportKeys = {}; // 학생 ID -> GlobalKey (이미지 캡처용)
  final ScrollController _previewScrollController = ScrollController();
  final PageController _pageController = PageController();
  bool _isPreviewMode = false; // 집중 미리보기 모드 여부

  @override
  void initState() {
    super.initState();
    // 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studentProvider = context.read<StudentProvider>();
      final progressProvider = context.read<ProgressProvider>();

      studentProvider.loadStudents(
        widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      progressProvider.loadAcademyProgress(
        widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
    });
  }

  @override
  void dispose() {
    _previewScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showStudentSelectionDialog() async {
    final studentProvider = context.read<StudentProvider>();
    final students = studentProvider.students;

    // 존재하는 모든 '부' 추출 (중복 제거 및 정렬)
    final sessions =
        students
            .map((s) => s.session ?? 0)
            .where((s) => s != 0)
            .toSet()
            .toList()
          ..sort();

    int? activeSessionFilter; // null이면 '전체'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 필터링된 학생 목록
            final filteredStudents = activeSessionFilter == null
                ? students
                : students
                      .where((s) => s.session == activeSessionFilter)
                      .toList();

            bool isAllFilteredSelected =
                filteredStudents.isNotEmpty &&
                filteredStudents.every(
                  (s) => _selectedStudentIds.contains(s.id),
                );

            return AlertDialog(
              title: const Text('통지표 대상 학생 선택'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 부 필터 칩 영역
                    const Text(
                      '부(session) 필터',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('전체'),
                            selected: activeSessionFilter == null,
                            onSelected: (val) {
                              setDialogState(() => activeSessionFilter = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ...sessions.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('$s부'),
                                selected: activeSessionFilter == s,
                                onSelected: (val) {
                                  setDialogState(
                                    () => activeSessionFilter = val ? s : null,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    CheckboxListTile(
                      title: Text(
                        activeSessionFilter == null
                            ? '전체 선택'
                            : '$activeSessionFilter부 전체 선택',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: isAllFilteredSelected,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            for (var s in filteredStudents) {
                              _selectedStudentIds.add(s.id);
                            }
                          } else {
                            for (var s in filteredStudents) {
                              _selectedStudentIds.remove(s.id);
                            }
                          }
                        });
                      },
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final isSelected = _selectedStudentIds.contains(
                            student.id,
                          );
                          return CheckboxListTile(
                            title: Text(student.name),
                            subtitle: Row(
                              children: [
                                if (student.grade != null)
                                  Text('${student.grade}학년 '),
                                if (student.session != null &&
                                    student.session != 0)
                                  Text('| ${student.session}부'),
                              ],
                            ),
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  _selectedStudentIds.add(student.id);
                                } else {
                                  _selectedStudentIds.remove(student.id);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // 메인 상태 반영
                    Navigator.pop(context);
                  },
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통지표 편집 및 미리보기'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: () {
              // 전체 자동 생성 로직
              final studentProvider = context.read<StudentProvider>();
              final progressProvider = context.read<ProgressProvider>();
              final selectedStudents = studentProvider.students
                  .where((s) => _selectedStudentIds.contains(s.id))
                  .toList();

              if (selectedStudents.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('자동 생성할 학생을 먼저 선택해주세요.')),
                );
                return;
              }

              setState(() {
                for (var student in selectedStudents) {
                  final progress = progressProvider.getProgressForStudent(
                    student.id,
                  );
                  final textbookNames = progress
                      .map((p) => p.textbookName)
                      .toList();
                  final volumes = progress.map((p) => p.volumeNumber).toList();

                  _customComments[student
                      .id] = ReportCommentUtils.autoGenerateComment(
                    studentName: student.name,
                    scores: _customScores[student.id] ?? AchievementScores(),
                    textbookNames: textbookNames,
                    volumes: volumes,
                    templates: _getSampleTemplates(),
                  );
                }
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${selectedStudents.length}명의 종합 의견이 자동 생성되었습니다. [결과 미리보기]로 확인 후 저장해주세요.',
                  ),
                  action: SnackBarAction(
                    label: '확인하기',
                    onPressed: () {
                      setState(() => _isPreviewMode = true);
                    },
                  ),
                ),
              );
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 20),
                Text(
                  '의견 자동 생성',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isPreviewMode = !_isPreviewMode);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPreviewMode ? Icons.edit_note : Icons.visibility_outlined,
                  size: 20,
                  color: _isPreviewMode ? Colors.indigo : null,
                ),
                Text(
                  '통지표 미리보기',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isPreviewMode ? Colors.indigo : null,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_for_offline_outlined, size: 20),
                Text(
                  '이미지 저장',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            onPressed: () async {
              // 1. 선택된 학생 목록 확인
              final studentProvider = context.read<StudentProvider>();
              final reportProvider = context.read<EducationReportProvider>();
              final progressProvider = context.read<ProgressProvider>();

              final selectedStudents = studentProvider.students
                  .where((s) => _selectedStudentIds.contains(s.id))
                  .toList();

              if (selectedStudents.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('저장할 학생을 먼저 선택해주세요.')),
                );
                return;
              }

              // 2. 저장 진행 확인
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('통지표 이미지 저장'),
                  content: Text(
                    '${selectedStudents.length}명의 통지표를 각각 이미지 파일(PNG)로 저장하시겠습니까?\n(현재 화면에 보이는 배치 그대로 저장됩니다.)',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('진행'),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              // 3. 루프를 돌며 개별 저장
              for (var student in selectedStudents) {
                final key = _reportKeys[student.id];
                if (key == null) continue;

                // 웹의 경우 브라우저 팝업 차단/지연 방지를 위해 미세한 지연 추가
                if (kIsWeb) {
                  await Future.delayed(const Duration(milliseconds: 500));
                }

                // 스낵바나 로딩으로 현재 진행 상황 알림 (생략 가능하지만 UX상 권장)

                final bytes = await PrintingService.captureWidgetToImage(key);
                if (bytes == null) continue;

                final success = await PrintingService.saveImageToFile(
                  bytes: bytes,
                  fileName:
                      '교육통지표_${student.name}_${DateFormat('yyyyMM').format(DateTime.now())}.png',
                );

                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${student.name} 통지표 저장에 실패했거나 취소되었습니다.'),
                    ),
                  );
                  continue; // 파일 저장 실패 시 다음 학생으로 진행
                }

                // 4. DB에 리포트 데이터 저장
                final progressList = progressProvider.getProgressForStudent(
                  student.id,
                );
                final textbookIds = progressList
                    .map((p) => p.textbookId)
                    .toList();

                final report = EducationReportModel(
                  id: '${student.id}_${DateFormat('yyyyMM').format(DateTime.now())}',
                  academyId: widget.academy.id,
                  ownerId: widget.academy.ownerId,
                  studentId: student.id,
                  startDate: DateTime.now().subtract(
                    const Duration(days: 30),
                  ), // 임시: 최근 1개월
                  endDate: DateTime.now(),
                  textbookIds: textbookIds,
                  scores: _customScores[student.id] ?? AchievementScores(),
                  attendanceCount: 0, // 출결 연동은 추후 필요시 추가
                  totalClasses: 0,
                  teacherComment: _customComments[student.id] ?? '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  layouts: _studentLayouts[student.id],
                );

                await reportProvider.saveReport(report);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('선택한 학생들의 통지표 저장이 완료되었습니다.')),
                );
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. 통지표 미리 보기 영역 (80%)
          Expanded(
            flex: 8,
            child: Consumer2<StudentProvider, ProgressProvider>(
              builder: (context, studentProvider, progressProvider, child) {
                final selectedStudents = studentProvider.students
                    .where((s) => _selectedStudentIds.contains(s.id))
                    .toList();

                // 학생이 선택되지 않았을 때 표시할 더미 데이터
                final List<dynamic> displayItems = selectedStudents.isEmpty
                    ? [
                        StudentModel(
                          id: 'sample',
                          academyId: widget.academy.id,
                          ownerId: widget.academy.ownerId,
                          name: '학생명 [샘플]',
                          session: 1,
                          grade: 1,
                          createdAt: DateTime.now(),
                        ),
                      ]
                    : selectedStudents;

                return Container(
                  color: Colors.grey.shade200,
                  child: Column(
                    children: [
                      if (selectedStudents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: Colors.amber.shade50.withOpacity(0.8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.amber.shade900,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '현재 샘플 양식입니다. 우측에서 학생을 선택하면 실제 데이터가 반영됩니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: _isPreviewMode
                            ? _buildFocusedPreview(displayItems)
                            : SingleChildScrollView(
                                controller: _previewScrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                  horizontal: 20,
                                ),
                                child: Column(
                                  children: displayItems.map((item) {
                                    final reportKey = _reportKeys.putIfAbsent(
                                      item.id,
                                      () => GlobalKey(),
                                    );

                                    // 실제 학생인 경우 진도 데이터를 가져오고, 샘플인 경우 더미 데이터 전달
                                    final isSample = item.id == 'sample';
                                    final progressList = isSample
                                        ? <StudentProgressModel>[
                                            StudentProgressModel(
                                              id: 'p1',
                                              studentId: 'sample',
                                              academyId: widget.academy.id,
                                              ownerId: widget.academy.ownerId,
                                              textbookId: 't1',
                                              textbookName: '바둑 입문',
                                              volumeNumber: 2,
                                              totalVolumes: 4,
                                              startDate: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            ),
                                            StudentProgressModel(
                                              id: 'p2',
                                              studentId: 'sample',
                                              academyId: widget.academy.id,
                                              ownerId: widget.academy.ownerId,
                                              textbookId: 't2',
                                              textbookName: '사활의 기초',
                                              volumeNumber: 1,
                                              totalVolumes: 3,
                                              startDate: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            ),
                                          ]
                                        : progressProvider
                                              .getProgressForStudent(item.id)
                                              .where((p) => !p.isCompleted)
                                              .toList();

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 40,
                                      ),
                                      child: Center(
                                        child: RepaintBoundary(
                                          key: reportKey,
                                          child: _EducationReportPaper(
                                            student: item,
                                            academy: widget.academy,
                                            progressList: progressList,
                                            academyName:
                                                _customAcademyName ??
                                                widget.academy.name,
                                            reportTitle:
                                                _customReportTitle ??
                                                '바둑 성장 레포트',
                                            reportDate:
                                                _customReportDate ??
                                                DateFormat(
                                                  'yyyy년 M월',
                                                ).format(DateTime.now()),
                                            studentLevel:
                                                _customStudentLevels[item.id] ??
                                                item.levelDisplayName,
                                            showLevel: _showLevel,
                                            showRadarChart: _showRadarChart,
                                            showProgress: _showProgress,
                                            showCompetency: _showCompetency,
                                            scores:
                                                _customScores[item.id] ??
                                                AchievementScores(),
                                            teacherComment:
                                                _customComments[item.id] ??
                                                '이번 달은 수읽기 교재를 중점적으로 학습하며 집중력이 많이 향상되었습니다. 특히 사활 문제 풀이 속도가 빨라진 점이 고무적입니다. 다음 달에는 실전 대국에서의 형세 판단 능력을 기르는 데 집중할 예정입니다.',
                                            onAcademyNameChanged: (newName) {
                                              setState(
                                                () => _customAcademyName =
                                                    newName,
                                              );
                                            },
                                            onReportTitleChanged: (newTitle) {
                                              setState(
                                                () => _customReportTitle =
                                                    newTitle,
                                              );
                                            },
                                            onReportDateChanged: (newDate) {
                                              setState(
                                                () =>
                                                    _customReportDate = newDate,
                                              );
                                            },
                                            onLevelChanged: (newLevel) {
                                              setState(() {
                                                _customStudentLevels[item.id] =
                                                    newLevel;
                                              });
                                            },
                                            onScoresChanged: (newScores) {
                                              setState(() {
                                                _customScores[item.id] =
                                                    newScores;
                                              });
                                            },
                                            onCommentChanged: (newComment) {
                                              setState(() {
                                                _customComments[item.id] =
                                                    newComment;
                                              });
                                            },
                                            onOpenCommentPicker: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                builder: (context) =>
                                                    CommentGridPicker(
                                                      templates:
                                                          _getSampleTemplates(),
                                                      onSelected: (content) {
                                                        setState(() {
                                                          _customComments[item
                                                                  .id] =
                                                              content;
                                                        });
                                                      },
                                                    ),
                                              );
                                            },
                                            onRerollComment: () {
                                              final progress = progressProvider
                                                  .getProgressForStudent(
                                                    item.id,
                                                  );
                                              final textbookNames = progress
                                                  .map((p) => p.textbookName)
                                                  .toList();
                                              final volumes = progress
                                                  .map((p) => p.volumeNumber)
                                                  .toList();

                                              setState(() {
                                                _customComments[item.id] =
                                                    ReportCommentUtils.autoGenerateComment(
                                                      studentName: item.name,
                                                      scores:
                                                          _customScores[item
                                                              .id] ??
                                                          AchievementScores(),
                                                      textbookNames:
                                                          textbookNames,
                                                      volumes: volumes,
                                                      templates:
                                                          _getSampleTemplates(),
                                                    );
                                              });
                                            },
                                            isLayoutEditing: _isLayoutEditing,
                                            layouts:
                                                _studentLayouts[item.id] ?? {},
                                            onLayoutChanged:
                                                (widgetId, layout) {
                                                  setState(() {
                                                    _studentLayouts[item.id] ??=
                                                        {};
                                                    _studentLayouts[item
                                                            .id]![widgetId] =
                                                        layout;
                                                  });
                                                },
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 구분선
          const VerticalDivider(width: 1, thickness: 1),

          // 2. 편집창 영역 (20%)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.3),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_note, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '편집 도구',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.start,
                            children: [
                              _buildActionButton(
                                context,
                                label: '학생 선택',
                                icon: Icons.person_add_outlined,
                                color: Colors.indigo,
                                isPrimary: true,
                                onPressed: _showStudentSelectionDialog,
                              ),
                              _buildActionButton(
                                context,
                                label: '템플릿 선택',
                                icon: Icons.dashboard_customize_outlined,
                              ),
                              _buildActionButton(
                                context,
                                label: '문구 선택',
                                icon: Icons.list_alt,
                              ),
                              _buildActionButton(
                                context,
                                label: '문구 편집',
                                icon: Icons.edit_outlined,
                              ),
                              _buildActionButton(
                                context,
                                label: _isLayoutEditing ? '편집 완료' : '위치/크기 편집',
                                icon: _isLayoutEditing
                                    ? Icons.check_circle_outline
                                    : Icons.open_with,
                                color: _isLayoutEditing
                                    ? Colors.green
                                    : Colors.orange,
                                isPrimary: _isLayoutEditing,
                                onPressed: () {
                                  setState(() {
                                    _isLayoutEditing = !_isLayoutEditing;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text(
                              '급수 정보 표시',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: _showLevel,
                            onChanged: (val) {
                              setState(() => _showLevel = val);
                            },
                            secondary: const Icon(Icons.military_tech_outlined),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          SwitchListTile(
                            title: const Text(
                              '역량 밸런스 차트 (그래프)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: _showRadarChart,
                            onChanged: (val) {
                              setState(() => _showRadarChart = val);
                            },
                            secondary: const Icon(Icons.pie_chart_outline),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          SwitchListTile(
                            title: const Text(
                              '교재 학습 현황',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: _showProgress,
                            onChanged: (val) {
                              setState(() => _showProgress = val);
                            },
                            secondary: const Icon(Icons.library_books_outlined),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          SwitchListTile(
                            title: const Text(
                              '역량별 성취도 상세 (점수)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: _showCompetency,
                            onChanged: (val) {
                              setState(() => _showCompetency = val);
                            },
                            secondary: const Icon(Icons.bar_chart_outlined),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      '대상 학생을 선택하고 내용을 편집하세요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusedPreview(List<dynamic> displayItems) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: Colors.indigo.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '집중 미리보기 (좌우 방향키 또는 화살표 버튼 사용)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '총 ${displayItems.length}명 중 선택됨',
                style: const TextStyle(fontSize: 12, color: Colors.indigo),
              ),
            ],
          ),
        ),
        Expanded(
          child: KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              }
            },
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    final reportKey = _reportKeys.putIfAbsent(
                      item.id,
                      () => GlobalKey(),
                    );

                    final isSample = item.id == 'sample';
                    final progressProvider = context.read<ProgressProvider>();
                    final progressList = isSample
                        ? [
                            StudentProgressModel(
                              id: 'dummy',
                              studentId: 'sample',
                              academyId: widget.academy.id,
                              ownerId: widget.academy.ownerId,
                              textbookId: 'dummy',
                              textbookName: '싱크탱크 바둑 1권',
                              volumeNumber: 1,
                              totalVolumes: 4,
                              startDate: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          ]
                        : progressProvider.getProgressForStudent(item.id);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: RepaintBoundary(
                          key: reportKey,
                          child: _EducationReportPaper(
                            student: item,
                            academy: widget.academy,
                            progressList: progressList,
                            academyName:
                                _customAcademyNames[item.id] ??
                                widget.academy.name,
                            reportTitle:
                                _customReportTitles[item.id] ?? '수강생 학습 통지표',
                            reportDate:
                                _customReportDate ??
                                DateFormat(
                                  'yyyy. MM. dd',
                                ).format(DateTime.now()),
                            studentLevel:
                                _customStudentLevels[item.id] ?? '급수 미정',
                            showLevel: _showLevel,
                            showRadarChart: _showRadarChart,
                            showProgress: _showProgress,
                            showCompetency: _showCompetency,
                            scores:
                                _customScores[item.id] ?? AchievementScores(),
                            teacherComment:
                                _customComments[item.id] ??
                                '(의견을 입력하거나 자동생성 버튼을 누르세요)',
                            onAcademyNameChanged: (val) => setState(
                              () => _customAcademyNames[item.id] = val,
                            ),
                            onReportTitleChanged: (val) => setState(
                              () => _customReportTitles[item.id] = val,
                            ),
                            onReportDateChanged: (val) =>
                                setState(() => _customReportDate = val),
                            onLevelChanged: (val) => setState(
                              () => _customStudentLevels[item.id] = val,
                            ),
                            onScoresChanged: (val) =>
                                setState(() => _customScores[item.id] = val),
                            onCommentChanged: (val) =>
                                setState(() => _customComments[item.id] = val),
                            onOpenCommentPicker: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => CommentGridPicker(
                                  templates: _getSampleTemplates(),
                                  onSelected: (content) {
                                    setState(() {
                                      _customComments[item.id] = content;
                                    });
                                  },
                                ),
                              );
                            },
                            onRerollComment: () {
                              final progress = progressProvider
                                  .getProgressForStudent(item.id);
                              final textbookNames = progress
                                  .map((p) => p.textbookName)
                                  .toList();
                              final volumes = progress
                                  .map((p) => p.volumeNumber)
                                  .toList();

                              setState(() {
                                _customComments[item.id] =
                                    ReportCommentUtils.autoGenerateComment(
                                      studentName: item.name,
                                      scores:
                                          _customScores[item.id] ??
                                          AchievementScores(),
                                      textbookNames: textbookNames,
                                      volumes: volumes,
                                      templates: _getSampleTemplates(),
                                    );
                              });
                            },
                            isLayoutEditing: _isLayoutEditing,
                            layouts: _studentLayouts[item.id] ?? {},
                            onLayoutChanged: (widgetId, layout) {
                              setState(() {
                                _studentLayouts[item.id] ??= {};
                                _studentLayouts[item.id]![widgetId] = layout;
                              });
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // 왼쪽 화살표
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // 오른쪽 화살표
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    Color? color,
    bool isPrimary = false,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : (color ?? Colors.black87),
        backgroundColor: isPrimary ? color : null,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<CommentTemplateModel> _getSampleTemplates() {
    return [
      // 1. 학습 성취
      CommentTemplateModel(
        id: 'a1',
        category: '학습 성취',
        content: '기초 규칙을 완벽히 이해하고 돌의 활로와 집의 개념을 정확히 구분하여 적용합니다.',
      ),
      CommentTemplateModel(
        id: 'a2',
        category: '학습 성취',
        content: '착점의 우선순위인 \'큰 자리\'를 스스로 찾아내며 형세를 분석하는 안목이 생겼습니다.',
      ),
      CommentTemplateModel(
        id: 'a3',
        category: '학습 성취',
        content: '복잡한 사활 문제도 침착하게 수읽기하여 정답을 찾아내는 해결 능력이 우수합니다.',
      ),
      CommentTemplateModel(
        id: 'a4',
        category: '학습 성취',
        content: '단수와 축, 장문 등 기초 전술을 실전 대국에서 적재적소에 활용하는 능력이 좋습니다.',
      ),
      CommentTemplateModel(
        id: 'a5',
        category: '학습 성취',
        content: '집 짓기의 효율성을 고려하여 돌의 모양을 입체적으로 구성하는 감각이 향상되었습니다.',
      ),
      CommentTemplateModel(
        id: 'a6',
        category: '학습 성취',
        content: '상대방의 약점을 포착하여 공격하고 자신의 약점을 보강하는 공배 연동 능력이 뛰어납니다.',
      ),
      CommentTemplateModel(
        id: 'a7',
        category: '학습 성취',
        content: '필수 정석과 포석의 기본 원리를 이해하고 판을 넓게 쓰는 능력이 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'a8',
        category: '학습 성취',
        content: '패싸움과 끝내기 등 대국 마무리 단계까지 집중력을 유지하며 계산하는 능력이 정확합니다.',
      ),

      // 2. 학습 태도/집중력
      CommentTemplateModel(
        id: 't1',
        category: '학습 태도',
        content: '수업 시간 내내 높은 몰입도를 유지하며 강사님의 설명에 귀를 기울이는 자세가 매우 좋습니다.',
      ),
      CommentTemplateModel(
        id: 't2',
        category: '학습 태도',
        content: '궁금한 원리에 대해 적극적으로 질문하고 답을 찾으려는 탐구적인 태도가 훌륭합니다.',
      ),
      CommentTemplateModel(
        id: 't3',
        category: '학습 태도',
        content: '어려운 난이도의 과제에도 포기하지 않고 끈기 있게 도전하여 성취해내는 모습이 인상적입니다.',
      ),
      CommentTemplateModel(
        id: 't4',
        category: '학습 태도',
        content: '착점 전 신중하게 수읽기하는 습관이 정착되어 불필요한 실수가 눈에 띄게 줄었습니다.',
      ),
      CommentTemplateModel(
        id: 't5',
        category: '학습 태도',
        content: '학습 활동에 즐겁게 참여하며 바둑을 구상하고 문제를 해결하는 과정 자체를 즐깁니다.',
      ),
      CommentTemplateModel(
        id: 't6',
        category: '학습 태도',
        content: '자신의 대국 결과에 대해 스스로 복기하며 개선점을 찾으려는 진지한 성찰 태도를 보입니다.',
      ),
      CommentTemplateModel(
        id: 't7',
        category: '학습 태도',
        content: '주의 깊게 판 전체를 살피는 신중함이 돋보이며 정해진 학습 분량을 항상 성실히 완수합니다.',
      ),
      CommentTemplateModel(
        id: 't8',
        category: '학습 태도',
        content: '새로운 기술을 배울 때 열린 마음으로 수용하고 자신의 것으로 만들려는 열의가 가득합니다.',
      ),

      // 3. 대국 예절/인성
      CommentTemplateModel(
        id: 'e1',
        category: '대국 매너',
        content: '대국 전후의 인사를 빠뜨리지 않으며 상대방을 존중하는 바둑인의 자세가 매우 바릅니다.',
      ),
      CommentTemplateModel(
        id: 'e2',
        category: '대국 매너',
        content: '승패 결과보다는 대국의 과정에 집중하며 패배했을 때도 의연하게 받아들이는 태도가 우수합니다.',
      ),
      CommentTemplateModel(
        id: 'e3',
        category: '대국 매너',
        content: '대국 중 바른 자세를 유지하며 주위를 산만하게 하지 않는 높은 정서적 조절력을 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'e4',
        category: '대국 매너',
        content: '친구들과의 대국에서 규칙을 정확히 준수하며 서로 돕고 배우는 협력적인 모습을 보입니다.',
      ),
      CommentTemplateModel(
        id: 'e5',
        category: '대국 매너',
        content: '시간을 잘 지키고 도구(바둑판, 돌)를 소중히 다루는 기본 생활 습관이 잘 형성되어 있습니다.',
      ),
      CommentTemplateModel(
        id: 'e6',
        category: '대국 매너',
        content: '상대방이 생각할 시간을 충분히 배려하며 매너 있게 대국에 임하는 성숙함을 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'e7',
        category: '대국 매너',
        content: '어려워하는 친구에게 친절하게 원리를 설명해 주며 함께 성장하려는 따뜻한 마음을 가졌습니다.',
      ),
      CommentTemplateModel(
        id: 'e8',
        category: '대국 매너',
        content: '대국 중의 정숙을 잘 유지하며 한 수 한 수에 정성을 다하는 명상적인 태도가 돋보입니다.',
      ),

      // 4. 성장 변화
      CommentTemplateModel(
        id: 'g1',
        category: '성장 변화',
        content: '학기 초에 비해 바둑판을 보는 시야가 넓어졌으며 착점 시의 자신감이 크게 회복되었습니다.',
      ),
      CommentTemplateModel(
        id: 'g2',
        category: '성장 변화',
        content: '산만했던 대국 습관이 사라지고 한 수 한 수 신중하게 생각한 뒤 착점하는 변화가 뚜렷합니다.',
      ),
      CommentTemplateModel(
        id: 'g3',
        category: '성장 변화',
        content: '초기에는 승패에 예민했으나 이제는 대국 자체의 즐거움을 알고 즐기는 모습으로 성장했습니다.',
      ),
      CommentTemplateModel(
        id: 'g4',
        category: '성장 변화',
        content: '부족했던 수읽기 능력이 매일 꾸준한 연습을 통해 학년 수준을 상회할 만큼 크게 늘었습니다.',
      ),
      CommentTemplateModel(
        id: 'g5',
        category: '성장 변화',
        content: '소극적이었던 질문 태도가 적극적으로 바뀌며 수업의 주인공으로 거듭난 긍정적인 변화를 보입니다.',
      ),
      CommentTemplateModel(
        id: 'g6',
        category: '성장 변화',
        content: '기초 단계에서 중급 단계로 거침없이 도약하며 실전 실력이 비약적으로 향상된 한 학기였습니다.',
      ),
      CommentTemplateModel(
        id: 'g7',
        category: '성장 변화',
        content: '바둑을 통해 집중력이 길러지면서 학습 전반에 걸쳐 신중함과 끈기가 보태지고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g8',
        category: '성장 변화',
        content: '어렵게 느끼던 사활 풀이에 흥미를 느끼기 시작하며 자기주도적인 학습 습관이 형성되었습니다.',
      ),

      // 5. 격려/비전
      CommentTemplateModel(
        id: 'v1',
        category: '격려',
        content: '지금처럼 즐기며 꾸준히 정진한다면 다음 단계에서도 큰 성취를 이룰 것이라 확신합니다.',
      ),
      CommentTemplateModel(
        id: 'v2',
        category: '격려',
        content: '무한한 잠재력을 가진 학생으로 바둑을 통한 인내심 함양이 앞으로의 성장에 큰 밑거름이 될 것입니다.',
      ),
      CommentTemplateModel(
        id: 'v3',
        category: '격려',
        content: '이미 충분히 훌륭한 실력을 갖췄으며 더 넓은 시야를 갖기 위한 꾸준한 실전 대국을 권장합니다.',
      ),
      CommentTemplateModel(
        id: 'v4',
        category: '격려',
        content: '바둑에서 배운 \'생각하는 힘\'이 다른 학교 생활에서도 긍정적인 에너지로 발휘되길 응원합니다.',
      ),
      CommentTemplateModel(
        id: 'v5',
        category: '격려',
        content: '뛰어난 감각을 잘 가다듬는다면 미래에 아주 훌륭한 기력을 갖춘 바둑 인재가 될 인재입니다.',
      ),
      CommentTemplateModel(
        id: 'v6',
        category: '격려',
        content: '한 학기 동안 보여준 성실함에 박수를 보내며 방학 동안에도 바둑의 즐거움을 잊지 않길 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'v7',
        category: '격려',
        content: '자신감을 가지고 자신의 수를 믿는다면 다음 학기에는 훨씬 더 놀라운 실력을 보여줄 것입니다.',
      ),
      CommentTemplateModel(
        id: 'v8',
        category: '격려',
        content: '바둑을 즐기는 마음이 인성 성장으로 이어지는 모습이 아름다우며 지속적인 정진을 응원합니다.',
      ),
    ];
  }
}

/// A4 용지 스타일의 통지표 미리보기 위젯
class _EducationReportPaper extends StatelessWidget {
  final StudentModel student;
  final AcademyModel academy;
  final List<StudentProgressModel> progressList;
  final String academyName;
  final String reportTitle;
  final String reportDate;
  final String studentLevel;
  final bool showLevel;
  final bool showRadarChart;
  final bool showProgress;
  final bool showCompetency;
  final AchievementScores scores;
  final String teacherComment;
  final Function(String) onAcademyNameChanged;
  final Function(String) onReportTitleChanged;
  final Function(String) onReportDateChanged;
  final Function(String) onLevelChanged;
  final Function(AchievementScores) onScoresChanged;
  final Function(String) onCommentChanged;
  final VoidCallback onOpenCommentPicker;
  final VoidCallback onRerollComment;
  final bool isLayoutEditing;
  final Map<String, WidgetLayout> layouts;
  final Function(String, WidgetLayout) onLayoutChanged;

  const _EducationReportPaper({
    required this.student,
    required this.academy,
    required this.progressList,
    required this.academyName,
    required this.reportTitle,
    required this.reportDate,
    required this.studentLevel,
    required this.showLevel,
    required this.showRadarChart,
    required this.showProgress,
    required this.showCompetency,
    required this.scores,
    required this.teacherComment,
    required this.onAcademyNameChanged,
    required this.onReportTitleChanged,
    required this.onReportDateChanged,
    required this.onLevelChanged,
    required this.onScoresChanged,
    required this.onCommentChanged,
    required this.onOpenCommentPicker,
    required this.onRerollComment,
    required this.isLayoutEditing,
    required this.layouts,
    required this.onLayoutChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600, // 화면상의 A4 가로 너비 (상대적)
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        child: AspectRatio(
          aspectRatio: 1 / 1.41, // A4 비율
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 헤더 (학원 정보 및 제호)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => _showEditDialog(
                            context,
                            title: '학원명/교실명',
                            initialValue: academyName,
                            onSaved: onAcademyNameChanged,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          hoverColor: Colors.indigo.withOpacity(0.05),
                          child: Tooltip(
                            message: '클릭하여 수정',
                            child: Text(
                              academyName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _showEditDialog(
                            context,
                            title: '리포트 날짜',
                            initialValue: reportDate,
                            onSaved: onReportDateChanged,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          hoverColor: Colors.indigo.withOpacity(0.05),
                          child: Tooltip(
                            message: '클릭하여 수정',
                            child: Text(
                              reportDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: InkWell(
                    onTap: () => _showEditDialog(
                      context,
                      title: '레포트 제목',
                      initialValue: reportTitle,
                      onSaved: onReportTitleChanged,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: Colors.indigo.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Tooltip(
                        message: '클릭하여 수정',
                        child: Text(
                          reportTitle,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. 학생 인적사항
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem('학생명', student.name),
                      _buildDivider(),
                      _buildInfoItem('학년', '${student.grade}학년'),
                      _buildDivider(),
                      _buildInfoItem('반', '${student.session}부'),
                      if (showLevel) ...[
                        _buildDivider(),
                        InkWell(
                          onTap: () => _showEditDialog(
                            context,
                            title: '급수',
                            initialValue: studentLevel,
                            onSaved: onLevelChanged,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          hoverColor: Colors.indigo.withOpacity(0.05),
                          child: Tooltip(
                            message: '클릭하여 수정',
                            child: _buildInfoItem('급수', studentLevel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. 메인 성취도 분석 (자유 배치 영역)
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 레이더 차트
                      if (showRadarChart)
                        ResizableDraggableWrapper(
                          initialTop: layouts['radar']?.top ?? 0,
                          initialLeft: layouts['radar']?.left ?? 0,
                          initialWidth: layouts['radar']?.width ?? 240,
                          initialHeight: layouts['radar']?.height ?? 240,
                          isEditing: isLayoutEditing,
                          onLayoutChanged: (t, l, w, h) => onLayoutChanged(
                            'radar',
                            WidgetLayout(top: t, left: l, width: w, height: h),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '[ 역량 밸런스 차트 ]',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(child: RadarChartWidget(scores: scores)),
                            ],
                          ),
                        ),

                      // 학습 현황
                      if (showProgress)
                        ResizableDraggableWrapper(
                          initialTop: layouts['progress']?.top ?? 0,
                          initialLeft: layouts['progress']?.left ?? 260,
                          initialWidth: layouts['progress']?.width ?? 280,
                          initialHeight: layouts['progress']?.height ?? 100,
                          isEditing: isLayoutEditing,
                          onLayoutChanged: (t, l, w, h) => onLayoutChanged(
                            'progress',
                            WidgetLayout(top: t, left: l, width: w, height: h),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '[ 교재 학습 현황 ]',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (progressList.isEmpty)
                                const Text(
                                  '학습 데이터가 없습니다.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                )
                              else
                                ...progressList
                                    .take(3)
                                    .map(
                                      (p) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${p.textbookName} ${p.volumeNumber}권',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${p.progressPercentage.toInt()}%',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.indigo,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value:
                                                    p.progressPercentage / 100,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                color: Colors.indigo.shade300,
                                                minHeight: 3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            ],
                          ),
                        ),

                      // 역량별 성취도 상세
                      if (showCompetency)
                        ResizableDraggableWrapper(
                          initialTop: layouts['competency']?.top ?? 120,
                          initialLeft: layouts['competency']?.left ?? 260,
                          initialWidth: layouts['competency']?.width ?? 280,
                          initialHeight: layouts['competency']?.height ?? 160,
                          isEditing: isLayoutEditing,
                          onLayoutChanged: (t, l, w, h) => onLayoutChanged(
                            'competency',
                            WidgetLayout(top: t, left: l, width: w, height: h),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '[ 역량별 성취도 상세 ]',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildScoreBar(
                                '집중력',
                                scores.focus,
                                Colors.blue.shade700,
                                () => _showScoreEditDialog(context),
                              ),
                              _buildScoreBar(
                                '응용력',
                                scores.application,
                                Colors.teal.shade600,
                                () => _showScoreEditDialog(context),
                              ),
                              _buildScoreBar(
                                '정확도',
                                scores.accuracy,
                                Colors.orange.shade700,
                                () => _showScoreEditDialog(context),
                              ),
                              _buildScoreBar(
                                '과제수행',
                                scores.task,
                                Colors.purple.shade600,
                                () => _showScoreEditDialog(context),
                              ),
                              _buildScoreBar(
                                '창의성',
                                scores.creativity,
                                Colors.pink.shade600,
                                () => _showScoreEditDialog(context),
                              ),
                            ],
                          ),
                        ),

                      // 종합 의견
                      ResizableDraggableWrapper(
                        initialTop: layouts['comment']?.top ?? 300,
                        initialLeft: layouts['comment']?.left ?? 0,
                        initialWidth: layouts['comment']?.width ?? 536,
                        initialHeight: layouts['comment']?.height ?? 200,
                        isEditing: isLayoutEditing,
                        onLayoutChanged: (t, l, w, h) => onLayoutChanged(
                          'comment',
                          WidgetLayout(top: t, left: l, width: w, height: h),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '[ 지도교사 종합 의견 ]',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 16),
                                      onPressed: onRerollComment,
                                      tooltip: '의견 다시 생성 (랜덤 조합)',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.grid_view,
                                        size: 16,
                                      ),
                                      onPressed: onOpenCommentPicker,
                                      tooltip: '카테고리별 문구 선택',
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showEditDialog(
                                  context,
                                  title: '종합 의견',
                                  initialValue: teacherComment,
                                  onSaved: onCommentChanged,
                                  isMultiline: true,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                hoverColor: Colors.indigo.withOpacity(0.05),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      teacherComment,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBar(
    String label,
    int score,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      hoverColor: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$score점',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: color.withOpacity(0.1),
                color: color,
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreEditDialog(BuildContext context) {
    AchievementScores currentScores = scores;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildSlider(
              String label,
              int value,
              Color color,
              Function(int) onChanged,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$value점',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: value.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: color,
                    label: value.toString(),
                    onChanged: (val) {
                      setDialogState(() {
                        onChanged(val.toInt());
                      });
                      onScoresChanged(currentScores);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }

            return AlertDialog(
              title: const Text('역량 성취도 조절'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildSlider(
                        '집중력',
                        currentScores.focus,
                        Colors.blue,
                        (val) =>
                            currentScores = currentScores.copyWith(focus: val),
                      ),
                      buildSlider(
                        '응용력',
                        currentScores.application,
                        Colors.teal,
                        (val) => currentScores = currentScores.copyWith(
                          application: val,
                        ),
                      ),
                      buildSlider(
                        '정확도',
                        currentScores.accuracy,
                        Colors.orange,
                        (val) => currentScores = currentScores.copyWith(
                          accuracy: val,
                        ),
                      ),
                      buildSlider(
                        '과제수행',
                        currentScores.task,
                        Colors.purple,
                        (val) =>
                            currentScores = currentScores.copyWith(task: val),
                      ),
                      buildSlider(
                        '창의성',
                        currentScores.creativity,
                        Colors.pink,
                        (val) => currentScores = currentScores.copyWith(
                          creativity: val,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required Function(String) onSaved,
    bool isMultiline = false,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title 수정'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: isMultiline ? 8 : 1,
            minLines: isMultiline ? 5 : 1,
            decoration: InputDecoration(
              hintText: '새로운 $title을 입력하세요',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              onSaved(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 20, color: Colors.grey.shade300);
  }
}
