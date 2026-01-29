import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/student_progress_model.dart';
import '../models/education_report_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import 'components/radar_chart_widget.dart';

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
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('인쇄 기능은 추후 구현될 예정입니다.')),
              );
            },
            tooltip: '전체 인쇄',
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
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: 40,
                            horizontal: 20,
                          ),
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final item = displayItems[index];

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
                              padding: const EdgeInsets.only(bottom: 40),
                              child: Center(
                                child: _EducationReportPaper(
                                  student: item,
                                  academy: widget.academy,
                                  progressList: progressList,
                                  academyName:
                                      _customAcademyName ?? widget.academy.name,
                                  reportTitle:
                                      _customReportTitle ?? '바둑 성장 레포트',
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
                                      () => _customAcademyName = newName,
                                    );
                                  },
                                  onReportTitleChanged: (newTitle) {
                                    setState(
                                      () => _customReportTitle = newTitle,
                                    );
                                  },
                                  onReportDateChanged: (newDate) {
                                    setState(() => _customReportDate = newDate);
                                  },
                                  onLevelChanged: (newLevel) {
                                    setState(() {
                                      _customStudentLevels[item.id] = newLevel;
                                    });
                                  },
                                  onScoresChanged: (newScores) {
                                    setState(() {
                                      _customScores[item.id] = newScores;
                                    });
                                  },
                                  onCommentChanged: (newComment) {
                                    setState(() {
                                      _customComments[item.id] = newComment;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
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
                                label: '점수 편집',
                                icon: Icons.grade_outlined,
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

                // 3. 메인 성취도 분석
                Expanded(
                  child: Row(
                    children: [
                      // 좌측: 레이더 차트
                      if (showRadarChart)
                        Expanded(
                          flex: 4,
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
                      if (showRadarChart && (showProgress || showCompetency))
                        const SizedBox(width: 24),
                      // 우측: 학습 현황 및 역량 분석
                      if (showProgress || showCompetency)
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showProgress) ...[
                                const Text(
                                  '[ 교재 학습 현황 ]',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (progressList.isEmpty)
                                  const Expanded(
                                    child: Center(
                                      child: Text(
                                        '학습 데이터가 없습니다.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ListView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: progressList.length > 3
                                          ? 3
                                          : progressList.length,
                                      itemBuilder: (context, index) {
                                        final p = progressList[index];
                                        return Padding(
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${p.progressPercentage.toInt()}%',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.indigo,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                      p.progressPercentage /
                                                      100,
                                                  backgroundColor:
                                                      Colors.grey.shade200,
                                                  color: Colors.indigo.shade300,
                                                  minHeight: 3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                              if (showProgress && showCompetency)
                                const Divider(height: 16),
                              if (showCompetency) ...[
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
                                if (!showProgress) const SizedBox(height: 8),
                              ],
                              if (showProgress || showCompetency)
                                Text(
                                  '* 위 지표는 최근 1개월간의 학습 성취도를 기반으로 합니다.',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. 지도 의견
                const Text(
                  '[ 지도교사 종합 의견 ]',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                InkWell(
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
                    constraints: const BoxConstraints(
                      minHeight: 120, // 최소 약 5줄 높이 확보
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
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
