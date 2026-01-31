import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:intl/intl.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/student_progress_model.dart';
import '../models/education_report_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import '../services/printing_service.dart';
import 'components/radar_chart_widget.dart';
import 'components/line_chart_widget.dart';
import 'components/doughnut_chart_widget.dart';
import 'components/bar_vertical_chart_widget.dart';
import 'components/bar_horizontal_chart_widget.dart';
import 'components/resizable_draggable_wrapper.dart';
import 'components/comment_grid_picker.dart';
import '../providers/education_report_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_model.dart';
import '../utils/report_comment_utils.dart';
import '../services/local_storage_service.dart';
import 'dart:async';

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
  bool _showAttendance = true; // 출석률 표시 여부
  Map<String, AchievementScores> _customScores = {}; // 학생 ID -> 커스텀 점수
  Map<String, BalanceChartType> _studentChartTypes = {}; // 학생 ID -> 밸런스 차트 타입
  Map<String, DetailViewType> _studentDetailTypes = {}; // 학생 ID -> 상세 보기 타입
  bool _showRadarChart = true; // 레이더 차트 표시 여부
  bool _showProgress = true; // 교재 현황 표시 여부
  bool _showCompetency = true; // 역량 점수바 표시 여부
  Map<String, String> _customComments = {}; // 학생 ID -> 커스텀 의견
  bool _isLayoutEditing = false; // 레이아웃 편집 모드 여부
  Map<String, Map<String, WidgetLayout>> _studentLayouts =
      {}; // 학생 ID -> (위젯 ID -> 레이아웃)
  final Map<String, GlobalKey> _reportKeys = {}; // 학생 ID -> GlobalKey (이미지 캡처용)
  final ScrollController _previewScrollController = ScrollController();

  int _layoutVersion = 0; // 레이아웃 초기화 시 UI 강제 새로고침을 위한 버전
  dynamic _capturingItem; // 현재 순차적으로 캡처 중인 학생 아이템
  final GlobalKey _captureSlotKey = GlobalKey(); // 캡처 전용 단일 슬롯의 키

  final LocalStorageService _storageService = LocalStorageService();
  Timer? _saveDebounceTimer; // 레이아웃 저장 디바운싱 타이머
  String? _pendingSaveStudentId; // 저장이 예약된 학생 ID
  bool _isExiting = false; // 뒤로 가기 중복 방지 플래그

  bool _hasApiKey = false; // API 키 존재 여부 (UI 제어용)
  bool _isAiMode = true; // AI 모드 On/Off 스위치
  bool _isAiGenerating = false; // AI 생성 중 여부

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

      // 저장된 레이아웃 로드 (약간의 딜레이 후 실행하여 학생 데이터 로드 완료 대기)
      // 실제로는 학생 ID만 있으면 되므로 바로 호출해도 무방하지만 안전하게 처리
      _loadAllStudentLayouts();
      _checkAiKey();
    });
  }

  Future<void> _checkAiKey() async {
    final key = await _storageService.getAiApiKey();
    if (mounted) {
      setState(() {
        _hasApiKey = key != null && key.isNotEmpty;
        if (!_hasApiKey) _isAiMode = false;
      });
    }
  }

  @override
  void dispose() {
    // 화면을 나갈 때 아직 저장되지 않은 레이아웃이 있다면 즉시 구동
    if (_saveDebounceTimer?.isActive ?? false) {
      _saveDebounceTimer!.cancel();
      if (_pendingSaveStudentId != null) {
        final layout = _studentLayouts[_pendingSaveStudentId!];
        if (layout != null) {
          _storageService.saveStudentLayout(_pendingSaveStudentId!, layout);
        }
      }
    }
    _previewScrollController.dispose();
    super.dispose();
  }

  Widget _buildReportPaper(
    dynamic item, {
    bool isBackground = false,
    bool useGlobalKey = true,
  }) {
    // 순차 캡처 중인 아이템이고 백그라운드 슬롯인 경우에만 특정 키(_captureSlotKey) 사용
    final reportKey = (isBackground && _capturingItem?.id == item.id)
        ? _captureSlotKey
        : (useGlobalKey
              ? _reportKeys.putIfAbsent(item.id, () => GlobalKey())
              : null);

    final progressProvider = context.read<ProgressProvider>();
    final isSample = item.id == 'sample';
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

    return RepaintBoundary(
      key: reportKey,
      child: _EducationReportPaper(
        key: ValueKey(
          '${isBackground ? 'bg' : 'list'}_${item.id}_${_layoutVersion}_${_studentChartTypes[item.id]?.name ?? 'radar'}',
        ),
        templateType: ReportTemplateType.classic, // 항상 classic으로 고정
        isPrinting: isBackground,
        student: item,
        academy: widget.academy,
        progressList: progressList,
        academyName: _customAcademyName ?? widget.academy.name,
        reportTitle: _customReportTitle ?? '바둑 성장 레포트',
        templates: _getSampleTemplates(),
        reportDate:
            _customReportDate ??
            DateFormat('yyyy. MM. dd').format(DateTime.now()),
        studentLevel: _customStudentLevels[item.id] ?? item.levelDisplayName,
        showLevel: _showLevel,
        showAttendance: _showAttendance,
        showRadarChart: _showRadarChart,
        showProgress: _showProgress,
        showCompetency: _showCompetency,
        scores: _customScores[item.id] ?? AchievementScores(),
        balanceChartType: _studentChartTypes[item.id] ?? BalanceChartType.radar,
        detailViewType:
            _studentDetailTypes[item.id] ?? DetailViewType.progressBar,
        onChartTypeChanged: (newType) {
          setState(() {
            _studentChartTypes[item.id] = newType;
          });
          // 차트 타입 변경 시에도 로컬에 저장
          _storageService.saveStudentChartType(item.id, newType);
        },

        teacherComment:
            _customComments[item.id] ??
            '수읽기 교재를 중점적으로 학습하며 집중력이 많이 향상되었습니다. 특히 사활 문제 풀이 속도가 빨라진 점이 고무적입니다.',
        onAcademyNameChanged: (newName) {
          setState(() => _customAcademyName = newName);
        },
        onReportTitleChanged: (newTitle) {
          setState(() => _customReportTitle = newTitle);
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
        onOpenCommentPicker: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => CommentGridPicker(
              templates: _getSampleTemplates(),
              multiSelect: true, // 다중 선택 모드 활성화
              studentName: item.name,
              textbookNames: progressProvider
                  .getProgressForStudent(item.id)
                  .map((p) => p.textbookName)
                  .toList(),
              onSelected: (content) {
                setState(() {
                  _customComments[item.id] = content;
                });
              },
            ),
          );
        },
        onRerollComment: () {
          final progress = progressProvider.getProgressForStudent(item.id);
          final textbookNames = progress.map((p) => p.textbookName).toList();
          final volumes = progress.map((p) => p.volumeNumber).toList();

          setState(() {
            _customComments[item.id] = ReportCommentUtils.autoGenerateComment(
              studentName: item.name,
              scores: _customScores[item.id] ?? AchievementScores(),
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
          // 변경 시 자동 저장 호출
          _saveLayoutToLocal(item.id);
        },
        layoutVersion: _layoutVersion,
      ),
    );
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
                        // 선택된 학생들에 대해 레이아웃 로드 시도
                        _loadAllStudentLayouts();
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
                              // 개별 선택 시에도 레이아웃 로드 시도
                              _loadAllStudentLayouts();
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
                    // 메모리에 이미 최신 데이터가 있으므로 재로드 불필요
                    if (mounted) {
                      setState(() {}); // UI만 갱신
                      Navigator.pop(context);
                    }
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

  // --- AI 생성 로직 ---

  void _handleAiGenerationRequest() {
    if (_isAiMode) {
      // 이제 스위치를 켤 때 키 체크를 하므로, 여기에 왔다는 것은 키가 있다는 뜻
      _showAiInstructionsDialog();
    } else {
      _batchRegenerateComments(null);
    }
  }

  void _showApiKeyRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.orange),
            SizedBox(width: 8),
            Text('AI 설정 필요'),
          ],
        ),
        content: const Text(
          'AI 기능을 사용하려면 Gemini API 키를 먼저 등록해야 합니다.\n설정 화면으로 이동할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에 하기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('[설정 > AI 설정] 메뉴에서 키를 등록해 주세요.'),
                  duration: Duration(seconds: 5),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('설정하러 가기'),
          ),
        ],
      ),
    );
  }

  void _showAiInstructionsDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('AI 맞춤 일괄 요청'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '선택된 ${_selectedStudentIds.length}명의 학생에게 공통으로 적용할 요청 사항이 있나요?',
            ),
            const SizedBox(height: 4),
            const Text(
              '(예: 칭찬 위주로, 단점 부드럽게 등)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '비워두면 데이터를 분석해 자동으로 작성합니다.',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                Navigator.pop(context);
                _batchRegenerateComments(val);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _batchRegenerateComments(null);
            },
            child: const Text('바로 생성'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _batchRegenerateComments(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('반영하여 생성'),
          ),
        ],
      ),
    );
  }

  Future<void> _batchRegenerateComments(String? instructions) async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('생성할 학생을 먼저 선택해 주세요.')));
      return;
    }

    setState(() => _isAiGenerating = true);

    final reportProvider = context.read<EducationReportProvider>();
    final progressProvider = context.read<ProgressProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentProvider>();

    int successCount = 0;
    int failCount = 0;

    try {
      for (final studentId in _selectedStudentIds) {
        if (studentId == 'sample') continue;

        final student = studentProvider.students.firstWhere(
          (s) => s.id == studentId,
        );

        // 1. 해당 기간 출석 데이터 (임시 기간 설정 - 현재 통지표 날짜 기준이 좋지만 여기선 간단히)
        // 실제로는 EducationReportFormScreen처럼 기간을 인자로 받아야 함.
        // 여기서는 EducationReportScreen의 state에 기간 정보가 없으므로 현재 달 기준으로 처리하거나
        // draft 생성 로직을 최소화함.

        final now = DateTime.now();
        final startDate = DateTime(now.year, now.month, 1);
        final endDate = DateTime(now.year, now.month + 1, 0);

        final attendanceRecords = await attendanceProvider.getRecordsForPeriod(
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
          start: startDate,
          end: endDate,
        );

        final totalClasses = attendanceRecords.length;
        final presentCount = attendanceRecords
            .where(
              (r) =>
                  r.type == AttendanceType.present ||
                  r.type == AttendanceType.late,
            )
            .length;

        // 2. 교재 현황
        final progressList = progressProvider.getProgressForStudent(studentId);
        final textbookIds = progressList.map((p) => p.textbookId).toList();
        final textbookNames = progressList.map((p) => p.textbookName).toList();
        final volumes = progressList.map((p) => p.volumeNumber).toList();

        // 3. 초안 생성 요청
        try {
          final draft = await reportProvider.generateDraft(
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            studentId: studentId,
            studentName: student.name,
            startDate: startDate,
            endDate: endDate,
            textbookNames: textbookNames,
            textbookIds: textbookIds,
            volumes: volumes,
            attendanceCount: presentCount,
            totalClasses: totalClasses,
            userInstructions: _isAiMode ? instructions : null,
          );

          if (mounted) {
            setState(() {
              _customComments[studentId] = draft.teacherComment;
              // 점수도 함께 업데이트 (종합 의견 생성 시 점수 데이터가 활용되므로 같이 가져오는 게 자연스러움)
              _customScores[studentId] = draft.scores;
            });
            successCount++;
          }
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) {
        final source = reportProvider.lastGenerationSource;
        String message;
        if (failCount == 0) {
          message = source == 'ai'
              ? '🤖 AI가 $successCount명의 의견을 작성했습니다.'
              : '📝 시스템 문구로 $successCount명의 의견을 추천했습니다.';
        } else {
          message = '✅ 완료: $successCount명 성공, ❌ 실패: $failCount명';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: source == 'ai'
                ? Colors.indigo
                : (failCount > 0 ? Colors.red : Colors.grey[700]),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAiGenerating = false);
      }
    }
  }

  // --- 레이아웃 저장/로드 로직 ---

  Future<void> _loadAllStudentLayouts() async {
    try {
      // 로드 전 보류된 저장 작업이 있다면 먼저 스토리지에 반영 (레이스 컨디션 방지)
      await _flushPendingSave();

      final targetIds = _selectedStudentIds.toList();
      if (!targetIds.contains('sample')) targetIds.add('sample');

      bool hasChanged = false;

      // 실질적인 데이터 로드 (병렬 처리로 속도 개선)
      await Future.wait(
        targetIds.map((id) async {
          // 레이아웃 로드 - 메모리 우선 전략 (isEmpty 체크 제거)
          if (!_studentLayouts.containsKey(id)) {
            final savedLayout = await _storageService.getStudentLayout(id);
            if (savedLayout.isNotEmpty) {
              _studentLayouts[id] = savedLayout;
              hasChanged = true;
            }
          }

          // 차트 타입 로드
          if (!_studentChartTypes.containsKey(id)) {
            final savedChartType = await _storageService.getStudentChartType(
              id,
            );
            if (savedChartType != null) {
              _studentChartTypes[id] = savedChartType;
              hasChanged = true;
            }
          }

          // 상세 보기 타입 로드
          if (!_studentDetailTypes.containsKey(id)) {
            final savedDetailType = await _storageService.getStudentDetailType(
              id,
            );
            if (savedDetailType != null) {
              _studentDetailTypes[id] = savedDetailType;
              hasChanged = true;
            }
          }
        }),
      );

      if (hasChanged && mounted) {
        setState(() {
          _layoutVersion++; // 데이터 로드 후 레이아웃 엔진 강제 새로고침
        });
        print('✅ All layouts and settings loaded and UI refreshed.');
      }
    } catch (e) {
      print('❌ Error in _loadAllStudentLayouts: $e');
    }
  }

  void _saveLayoutToLocal(String studentId) {
    _pendingSaveStudentId = studentId;
    if (_saveDebounceTimer?.isActive ?? false) _saveDebounceTimer!.cancel();

    _saveDebounceTimer = Timer(const Duration(milliseconds: 100), () async {
      final layout = _studentLayouts[studentId];
      if (layout != null) {
        await _storageService.saveStudentLayout(studentId, layout);
        print('💾 Layout saved for $studentId');
      }
      _pendingSaveStudentId = null;
    });
  }

  /// 모든 저장 작업을 즉시 동기적으로(비동기 대기 포함) 완료
  Future<void> _flushPendingSave() async {
    // 진행 중인 디바운스 타이머가 있다면 취소
    if (_saveDebounceTimer?.isActive ?? false) {
      _saveDebounceTimer!.cancel();
      print('⏱️ Save timer cancelled for flushing.');
    }

    if (_pendingSaveStudentId != null) {
      final id = _pendingSaveStudentId!;
      final layout = _studentLayouts[id];
      if (layout != null) {
        try {
          await _storageService.saveStudentLayout(id, layout);
          print('💾 Flushed pending save for $id');
        } catch (e) {
          print('❌ Error flushing save for $id: $e');
        }
      }
      _pendingSaveStudentId = null;
    }
  }

  Future<void> _saveIndividualReport(dynamic student) async {
    print('🚀 Individual save started for ${student.name}');
    setState(() {
      _capturingItem = student;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${student.name} 통지표 이미지를 생성 중입니다...')),
    );

    // 렌더링 대기
    await Future.delayed(Duration(milliseconds: kIsWeb ? 1500 : 800));

    try {
      final bytes = await PrintingService.captureWidgetToImage(
        _captureSlotKey,
        pixelRatio: kIsWeb ? 2.0 : 3.0,
      );

      if (bytes == null) {
        print('❌ Individual capture failed for ${student.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 생성에 실패했습니다. 다시 시도해 주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final success = await PrintingService.saveImageToFile(
        bytes: bytes,
        fileName:
            '교육통지표_${student.name}_${DateFormat('yyyyMM').format(DateTime.now())}.png',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${student.name} 통지표 저장 완료!')));
      }
    } catch (e) {
      print('❌ Error in individual save: $e');
    } finally {
      if (mounted) {
        setState(() {
          _capturingItem = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 수동 제어하여 저장 완료 보장
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isExiting) return;
        _isExiting = true; // 플래그 설정하여 중복 실행 방지
        print('🚪 Back button pressed. Flushing and exiting...');

        try {
          await _flushPendingSave();
        } catch (e) {
          print('❌ Error during exit flush: $e');
        }

        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
                    final volumes = progress
                        .map((p) => p.volumeNumber)
                        .toList();

                    final initialScores =
                        ReportCommentUtils.generateInitialScores(
                          textbookName: textbookNames.isNotEmpty
                              ? textbookNames.first
                              : '배우고 있는 교재',
                          volumeNumber: volumes.isNotEmpty ? volumes.first : 1,
                        );

                    _customScores[student.id] = initialScores;
                    _customComments[student.id] =
                        ReportCommentUtils.autoGenerateComment(
                          studentName: student.name,
                          scores: initialScores,
                          textbookNames: textbookNames,
                          volumes: volumes,
                          templates: _getSampleTemplates(),
                        );
                  }
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${selectedStudents.length}명의 종합 의견이 자동 생성되어 리스트에 반영되었습니다.',
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
                print('🚀 Batch save started');
                try {
                  print('🔍 Reading providers...');
                  final studentProvider = context.read<StudentProvider>();
                  print('✅ StudentProvider OK');
                  final reportProvider = context
                      .read<EducationReportProvider>();
                  print('✅ EducationReportProvider OK');
                  final progressProvider = context.read<ProgressProvider>();
                  print('✅ ProgressProvider OK');

                  print(
                    '🔍 Filtering students... _selectedStudentIds: $_selectedStudentIds',
                  );
                  final selectedStudents = studentProvider.students
                      .where((s) => _selectedStudentIds.contains(s.id))
                      .toList();

                  print('👥 Found ${selectedStudents.length} student objects');

                  if (selectedStudents.isEmpty) {
                    print('⚠️ No students selected. Aborting.');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('저장할 학생을 먼저 선택해주세요.')),
                      );
                    }
                    return;
                  }

                  print('💬 Showing confirmation dialog...');
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

                  print('💬 Confirmation result: $confirm');

                  if (confirm != true) {
                    print('⏹️ Save cancelled by user');
                    return;
                  }

                  // 3. 진행률 다이얼로그 표시
                  if (!mounted) return;

                  int currentCount = 0;
                  String currentName = '';
                  StateSetter? setProgressState;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) {
                      return StatefulBuilder(
                        builder: (context, setDialogState) {
                          setProgressState = setDialogState;
                          return AlertDialog(
                            title: const Text('통지표 저장 중...'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 20),
                                Text(
                                  '진행: $currentCount / ${selectedStudents.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (currentName.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '현재: $currentName',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: selectedStudents.isEmpty
                                      ? 0
                                      : currentCount / selectedStudents.length,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );

                  // 4. 순차적으로 저장 처리
                  int batchSuccessCount = 0;
                  print(
                    '📦 Total students to save: ${selectedStudents.length}',
                  );

                  for (var student in selectedStudents) {
                    currentCount++;
                    currentName = student.name;

                    // 1. 캡처 슬롯에 학생 할당 (오프스크린 렌더링 시작)
                    setState(() {
                      _capturingItem = student;
                    });

                    // 다이얼로그 상태 업데이트
                    if (setProgressState != null) {
                      setProgressState!(() {});
                    }

                    // 2. 렌더링 엔진에 그릴 시간 제공
                    await Future.delayed(
                      Duration(milliseconds: kIsWeb ? 1500 : 800),
                    );

                    try {
                      print('📸 Capturing image for ${student.name}');
                      final bytes = await PrintingService.captureWidgetToImage(
                        _captureSlotKey,
                        pixelRatio: kIsWeb ? 2.0 : 3.0,
                      );

                      if (bytes == null) {
                        print('❌ Capture failed for ${student.name}');
                        continue;
                      }

                      final success = await PrintingService.saveImageToFile(
                        bytes: bytes,
                        fileName:
                            '교육통지표_${student.name}_${DateFormat('yyyyMM').format(DateTime.now())}.png',
                      );

                      if (success) {
                        print('💾 Save success for ${student.name}');
                        batchSuccessCount++;

                        // DB에 리포트 데이터 저장
                        final progressList = progressProvider
                            .getProgressForStudent(student.id);
                        final report = EducationReportModel(
                          id: '${student.id}_${DateFormat('yyyyMM').format(DateTime.now())}',
                          academyId: widget.academy.id,
                          ownerId: widget.academy.ownerId,
                          studentId: student.id,
                          startDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          endDate: DateTime.now(),
                          textbookIds: progressList
                              .map((p) => p.textbookId)
                              .toList(),
                          scores:
                              _customScores[student.id] ?? AchievementScores(),
                          attendanceCount: 0,
                          totalClasses: 0,
                          teacherComment: _customComments[student.id] ?? '',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          layouts: _studentLayouts[student.id],
                        );
                        await reportProvider.saveReport(report);

                        // 웹에서는 브라우저 처리를 위해 약간 대기
                        if (kIsWeb) {
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        }
                      } else {
                        print(
                          '❌ Save failed (cancelled or error) for ${student.name}',
                        );
                      }
                    } catch (e) {
                      print(
                        '❌ Error during batch process for ${student.name}: $e',
                      );
                    } finally {
                      // 캡처 슬롯 비우기 (메모리 해제 유도)
                      setState(() {
                        _capturingItem = null;
                      });
                    }
                  }

                  // 5. 진행률 다이얼로그 닫기
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '통지표 저장 완료: $batchSuccessCount / ${selectedStudents.length}',
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e, stack) {
                  print('❌ Fatal error in batch save: $e');
                  print('❌ Stack trace: $stack');
                }
              },
            ),
          ],
        ),
        body: Row(
          children: [
            // 1. 통지표 미리 보기 영역 (80%)
            Expanded(
              flex: 3,
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
                            updatedAt: DateTime.now(),
                          ),
                        ]
                      : selectedStudents;

                  return Container(
                    color: Colors.grey.shade200,
                    child: Stack(
                      children: [
                        // 2. 캡처 전용 단일 슬롯
                        // 실제 페인팅이 일어나야 하므로 화면 안에 배치하되 리스트 뒤에 숨김
                        if (_capturingItem != null)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Opacity(
                              opacity: 0.01, // 완전히 0이면 렌더링에서 제외될 수 있음
                              child: _buildReportPaper(
                                _capturingItem!,
                                isBackground: true,
                              ),
                            ),
                          ),

                        // 1. 실제 보여지는 영역 (항상 리스트 모드)
                        SingleChildScrollView(
                          controller: _previewScrollController,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: displayItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 60),
                                child: Column(
                                  children: [
                                    // 개별 저장 버튼
                                    if (item.id != 'sample')
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _saveIndividualReport(item),
                                          icon: const Icon(
                                            Icons.download,
                                            size: 16,
                                          ),
                                          label: Text(
                                            '${item.name} 통지표만 저장',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.indigo,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            side: const BorderSide(
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Center(
                                      child: _buildReportPaper(
                                        item,
                                        useGlobalKey: true,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // 안내 메시지 (학생이 선택되지 않았을 때)
                        if (selectedStudents.isEmpty)
                          Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
              flex: 1,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  label: _isLayoutEditing
                                      ? '편집 완료'
                                      : '위치/크기 편집',
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
                                if (_isLayoutEditing)
                                  _buildActionButton(
                                    context,
                                    label: '레이아웃 초기화',
                                    icon: Icons.restart_alt,
                                    color: Colors.red,
                                    onPressed: _resetCurrentStudentLayout,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // AI 스마트 도구 섹션
                            const Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: Colors.purple,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'AI 스마트 도구',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _isAiMode ? '✨ AI 모드' : '📝 일반 모드',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _isAiMode
                                              ? Colors.purple
                                              : Colors.grey,
                                        ),
                                      ),
                                      Transform.scale(
                                        scale: 0.8,
                                        child: Switch(
                                          value: _isAiMode,
                                          activeColor: Colors.purple,
                                          onChanged: (val) {
                                            if (val == true && !_hasApiKey) {
                                              // 키 가 없는데 켜려고 하면 경고창 띄우고 상태 유지
                                              _showApiKeyRequiredDialog();
                                              return;
                                            }
                                            setState(() => _isAiMode = val);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: _isAiGenerating
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              _isAiMode
                                                  ? Icons.auto_awesome
                                                  : Icons.refresh,
                                              size: 16,
                                            ),
                                      label: Text(
                                        _isAiGenerating
                                            ? '작성 중...'
                                            : '${_selectedStudentIds.isNotEmpty ? _selectedStudentIds.length : ""}명 AI 자동 완성',
                                      ),
                                      onPressed: _isAiGenerating
                                          ? null
                                          : _handleAiGenerationRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isAiMode)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        '* 지시사항이 있으면 대화창이 뜹니다.',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 보기 스타일 설정 섹션 (상단 배치)
                            const Row(
                              children: [
                                Icon(
                                  Icons.style,
                                  size: 16,
                                  color: Colors.indigo,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '보기 스타일 설정',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 1. 차트 모양 선택
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '차트 모양',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: BalanceChartType.values.map((type) {
                                  final checkId = _selectedStudentIds.isNotEmpty
                                      ? _selectedStudentIds.first
                                      : 'sample';
                                  final currentType =
                                      _studentChartTypes[checkId] ??
                                      BalanceChartType.radar;
                                  final isSelected = type == currentType;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: InkWell(
                                      onTap: () {
                                        final bool wasSelectedStudentsEmpty =
                                            _selectedStudentIds.isEmpty;
                                        setState(() {
                                          if (wasSelectedStudentsEmpty) {
                                            final allStudents = context
                                                .read<StudentProvider>()
                                                .students;
                                            for (var s in allStudents) {
                                              _studentChartTypes[s.id] = type;
                                              _storageService
                                                  .saveStudentChartType(
                                                    s.id,
                                                    type,
                                                  );
                                            }
                                            _studentChartTypes['sample'] = type;
                                            _storageService
                                                .saveStudentChartType(
                                                  'sample',
                                                  type,
                                                );
                                          } else {
                                            for (var id
                                                in _selectedStudentIds) {
                                              _studentChartTypes[id] = type;
                                              _storageService
                                                  .saveStudentChartType(
                                                    id,
                                                    type,
                                                  );
                                            }
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF1A237E)
                                              : Colors.white,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFFFD700)
                                                : Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          type.icon,
                                          size: 20,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),

                            // 데이터 표시 설정
                            const Row(
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '표시 항목 설정',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),

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
                              secondary: const Icon(
                                Icons.military_tech_outlined,
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                            SwitchListTile(
                              title: const Text(
                                '출석률 표시',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              value: _showAttendance,
                              onChanged: (val) {
                                setState(() => _showAttendance = val);
                              },
                              secondary: const Icon(
                                Icons.event_available_outlined,
                              ),
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
                            // 기존의 하위 차트 선택 UI 제거됨 (위로 이동)
                            // 기존의 하위 상세 보기 방식 선택 UI 제거됨 (위로 이동)
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
                              secondary: const Icon(
                                Icons.library_books_outlined,
                              ),
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
      ),
    );
  }

  void _resetCurrentStudentLayout() {
    final studentProvider = context.read<StudentProvider>();
    final selectedStudents = studentProvider.students
        .where((s) => _selectedStudentIds.contains(s.id))
        .toList();

    List<String> idsToReset = selectedStudents.map((s) => s.id).toList();
    // 샘플 모드이거나 선택된 학생들 목록에 샘플이 없더라도 현재 샘플이 보이고 있다면 초기화 대상에 포함
    if (selectedStudents.isEmpty || _selectedStudentIds.contains('sample')) {
      if (!idsToReset.contains('sample')) idsToReset.add('sample');
    }

    if (idsToReset.isEmpty) return;

    String confirmMessage =
        '선택된 ${idsToReset.length}명 학생의 통지표 성분 위치와 크기를 모두 처음 기본값으로 되돌리시겠습니까?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('레이아웃 초기화'),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (var id in idsToReset) {
                  _studentLayouts.remove(id);
                  // 로컬 저장소에서도 삭제
                  _storageService.clearStudentLayout(id);
                }
                _layoutVersion++;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${idsToReset.length}명의 레이아웃이 초기화되었습니다.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
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

  List<CommentTemplateModel> _getSampleTemplates() {
    return [
      // 0. 인트로 (Intro) - 문단의 시작을 다양하게
      CommentTemplateModel(
        id: 'i1',
        category: '인트로',
        content: '{{name}} 학생은 바둑 실력이 향상되며 한층 더 성장한 모습을 보여주었습니다.',
      ),
      CommentTemplateModel(
        id: 'i2',
        category: '인트로',
        content: '꾸준한 노력과 열정으로 실력을 쌓아가고 있는 {{name}} 학생의 학습 현황을 전해드립니다.',
      ),
      CommentTemplateModel(
        id: 'i3',
        category: '인트로',
        content: '선생님과 함께 호흡하며 바둑판 위에서 자신만의 길을 찾아가는 {{name}} 학생이 대견합니다.',
      ),
      CommentTemplateModel(
        id: 'i4',
        category: '인트로',
        content: '집중력 있는 모습으로 매 수업에 임하는 {{name}} 학생의 바둑 공부는 매우 순조롭게 진행 중입니다.',
      ),
      CommentTemplateModel(
        id: 'i5',
        category: '인트로',
        content: '최근 {{name}} 학생은 기술적인 발전뿐만 아니라 바둑을 대하는 마음가짐도 더욱 성숙해졌습니다.',
      ),
      CommentTemplateModel(
        id: 'i6',
        category: '인트로',
        content: '{{name}} 학생은 꾸준히 학습하며 바둑의 기본기를 탄탄하게 다져가고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'i7',
        category: '인트로',
        content: '정석과 수읽기를 익히며 실전 대국 능력이 크게 향상된 {{name}} 학생의 성장이 기쁩니다.',
      ),
      CommentTemplateModel(
        id: 'i8',
        category: '인트로',
        content: '{{name}} 학생은 바둑 학습에 집중하며 매 수업마다 눈에 띄는 발전을 이루고 있습니다.',
      ),

      // 1. 학습 성취 (Achievement) - 수준별로 구분
      // [입문/기초 - Level 1]
      CommentTemplateModel(
        id: 'a1',
        category: '학습 성취',
        level: 1,
        content: '기초 규칙을 완벽히 이해하고 돌의 활로와 집의 개념을 정확히 구분하여 적용합니다.',
      ),
      CommentTemplateModel(
        id: 'a10',
        category: '학습 성취',
        level: 1,
        content: '단수와 따내기 등 바둑의 가장 기본이 되는 원리를 실전 대국에서 실수 없이 수행해냅니다.',
      ),
      CommentTemplateModel(
        id: 'a11',
        category: '학습 성취',
        level: 1,
        content: '착수 금지와 패의 규칙 등 자칫 헷갈리기 쉬운 부분들도 이제는 정확히 숙지하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a100',
        category: '학습 성취',
        level: 1,
        content: '두 집을 만들어야 산다는 삶과 죽음의 기본 개념을 이해하고 실전에서 적용하려 노력합니다.',
      ),
      CommentTemplateModel(
        id: 'a101',
        category: '학습 성취',
        level: 1,
        content: '상대방 돌을 잡는 것에만 몰두하지 않고 내 돌을 연결하여 튼튼하게 만드는 법을 익히고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a102',
        category: '학습 성취',
        level: 1,
        content: '서로 단수에 걸린 상황에서 침착하게 먼저 따내는 수를 찾아내는 감각이 좋아졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a103',
        category: '학습 성취',
        level: 1,
        content: '바둑판의 귀와 변, 중앙의 명칭을 명확히 알고 있으며 첫 수를 어디에 두어야 할지 이해하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a104',
        category: '학습 성취',
        level: 1,
        content: '내 돌이 위험할 때 달아나는 방법과 상대 돌을 포위하는 방법을 구별하여 사용할 줄 압니다.',
      ),
      CommentTemplateModel(
        id: 'a105',
        category: '학습 성취',
        level: 1,
        content: '옥집과 진짜 집을 구별하는 눈을 가지게 되었으며, 집을 짓는 기초 원리를 잘 따르고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a106',
        category: '학습 성취',
        level: 1,
        content: '끝내기의 개념을 조금씩 배워가며, 대국이 끝난 후 스스로 집을 세어보는 연습을 하고 있습니다.',
      ),

      // [초급/실전 - Level 2]
      CommentTemplateModel(
        id: 'a2',
        category: '학습 성취',
        level: 2,
        content: '착점의 우선순위인 \'큰 자리\'를 스스로 찾아내며 형세를 분석하는 안목이 생겼습니다.',
      ),
      CommentTemplateModel(
        id: 'a12',
        category: '학습 성취',
        level: 2,
        content: '축과 장문, 환격 등 기본적인 맥점을 발견하고 이를 이용해 이득을 보는 감각이 매우 좋습니다.',
      ),
      CommentTemplateModel(
        id: 'a13',
        category: '학습 성취',
        level: 2,
        content: '집 짓기의 효율성을 이해하기 시작했으며, 돌이 끊기지 않도록 연결하는 능력이 향상되었습니다.',
      ),
      CommentTemplateModel(
        id: 'a200',
        category: '학습 성취',
        level: 2,
        content: '수상전 상황에서 상대의 수를 줄이고 나의 수를 늘리는 요령을 터득하여 승률이 높아졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a201',
        category: '학습 성취',
        level: 2,
        content: '빈삼각과 같은 나쁜 모양을 피하고 호구와 같은 탄력 있는 좋은 모양을 갖추려 노력합니다.',
      ),
      CommentTemplateModel(
        id: 'a202',
        category: '학습 성취',
        level: 2,
        content: '상대의 세력을 삭감하거나 내 영역을 넓히는 행마법을 실전에서 자연스럽게 구사합니다.',
      ),
      CommentTemplateModel(
        id: 'a203',
        category: '학습 성취',
        level: 2,
        content: '포석 단계에서 귀-변-중앙의 순서로 집을 넓혀가는 기본 원리를 잘 지키고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a204',
        category: '학습 성취',
        level: 2,
        content: '침입해온 상대 돌을 무조건 잡으러 가기보다 공격을 통해 이득을 취하는 유연한 사고가 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'a205',
        category: '학습 성취',
        level: 2,
        content: '간단한 사활 문제는 한 눈에 정답을 찾아낼 정도로 기본적인 수읽기 속도가 빨라졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a206',
        category: '학습 성취',
        level: 2,
        content: '패를 활용하여 불리한 상황을 반전시키거나 상대를 굴복시키는 전술적 활용 능력이 생겼습니다.',
      ),

      // [중고급/심화 - Level 3]
      CommentTemplateModel(
        id: 'a3',
        category: '학습 성취',
        level: 3,
        content: '복잡한 사활 문제도 침착하게 수읽기하여 정답을 찾아내는 해결 능력이 우수합니다.',
      ),
      CommentTemplateModel(
        id: 'a14',
        category: '학습 성취',
        level: 3,
        content: '중반 전투 시 상대의 약점을 예리하게 파고드는 공격적인 수읽기가 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'a15',
        category: '학습 성취',
        level: 3,
        content: '형세 판단을 통해 현재의 유불리를 파악하고, 그에 맞는 전략을 세우는 능력이 탁월합니다.',
      ),
      CommentTemplateModel(
        id: 'a300',
        category: '학습 성취',
        level: 3,
        content: '부분적인 전투 승리보다 전체적인 판의 균형을 중시하는 대세관이 형성되고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a301',
        category: '학습 성취',
        level: 3,
        content: '상대의 의도를 미리 파악하고 그에 대응하는 반격 수단을 준비하는 등 수읽기의 깊이가 깊어졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a302',
        category: '학습 성취',
        level: 3,
        content: '두터움을 활용하여 장기적인 이득을 도모하거나 상대를 압박하는 운영 능력이 수준급입니다.',
      ),
      CommentTemplateModel(
        id: 'a303',
        category: '학습 성취',
        level: 3,
        content: '사석 작전을 통해 불필요한 돌을 버리고 더 큰 이익을 취하는 고도의 전술을 구사하기도 합니다.',
      ),
      CommentTemplateModel(
        id: 'a304',
        category: '학습 성취',
        level: 3,
        content: '정교한 끝내기 수순을 통해 미세한 승부에서도 역전승을 이끌어내는 뒷심이 강해졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a305',
        category: '학습 성취',
        level: 3,
        content: '고정관념에 얽매이지 않는 창의적인 수를 시도하며 자신만의 기풍을 만들어가고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a306',
        category: '학습 성취',
        level: 3,
        content: '약한 돌을 수습하는 타개 능력이 뛰어나 위기 상황에서도 쉽게 무너지지 않는 끈기를 보여줍니다.',
      ),

      // 2. 학습 태도 (Attitude)
      CommentTemplateModel(
        id: 't1',
        category: '학습 태도',
        content: '수업 시간 내내 높은 몰입도를 유지하며 선생님의 설명에 귀를 기울이는 자세가 매우 좋습니다.',
      ),
      CommentTemplateModel(
        id: 't2',
        category: '학습 태도',
        content: '궁금한 원리에 대해 적극적으로 질문하고 답을 찾으려는 탐구적인 태도가 훌륭합니다.',
      ),
      CommentTemplateModel(
        id: 't10',
        category: '학습 태도',
        content: '패배에 실망하기보다 복기를 통해 자신의 실수를 돌아보는 진지한 자세를 갖고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't11',
        category: '학습 태도',
        content: '한 수 한 수 신중하게 생각하고 두려는 노력이 보이며, 경솔한 착점이 눈에 띄게 줄었습니다.',
      ),
      CommentTemplateModel(
        id: 't12',
        category: '학습 태도',
        content: '모르는 문제가 나와도 포기하지 않고 스스로 끝까지 해결해 보려는 의지가 강합니다.',
      ),
      CommentTemplateModel(
        id: 't100',
        category: '학습 태도',
        content: '바른 자세로 앉아 흐트러짐 없이 대국에 임하며, 상대를 배려하는 마음가짐이 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 't101',
        category: '학습 태도',
        content: '자신의 차례가 아닐 때도 상대의 수를 주의 깊게 관찰하며 생각하는 습관이 잘 잡혀 있습니다.',
      ),
      CommentTemplateModel(
        id: 't102',
        category: '학습 태도',
        content: '어려운 상황에서도 쉽게 포기하거나 짜증 내지 않고 차분함을 유지하는 마인드 컨트롤 능력이 좋습니다.',
      ),
      CommentTemplateModel(
        id: 't103',
        category: '학습 태도',
        content: '과제를 성실하게 수행해 오며, 배운 내용을 복습하려는 자기 주도적인 학습 태도를 갖추고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't104',
        category: '학습 태도',
        content: '친구들과의 대국이나 교류 활동에도 적극적으로 참여하며 즐겁게 바둑을 배우고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't105',
        category: '학습 태도',
        content: '선생님의 조언을 열린 마음으로 받아들이고 즉시 자신의 플레이에 적용하려는 유연함이 장점입니다.',
      ),

      // 3. 대국 예절 (Etiquette)
      CommentTemplateModel(
        id: 'e1',
        category: '대국 매너',
        content: '대국 전후의 인사를 빠뜨리지 않으며 상대방을 존중하는 바둑인의 자세가 매우 바릅니다.',
      ),
      CommentTemplateModel(
        id: 'e2',
        category: '대국 매너',
        content: '승패 결과보다는 대국의 과정에 집중하며 승부의 세계를 건전하게 즐기는 모습이 보기 좋습니다.',
      ),
      CommentTemplateModel(
        id: 'e10',
        category: '대국 매너',
        content: '대국 중 정숙을 유지하고 상대방의 생각 시간을 배려하는 매너 있는 태도가 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'e11',
        category: '대국 매너',
        content: '바둑판과 바둑알을 소중히 다루며, 대국 후 정리 정돈까지 완벽하게 해냅니다.',
      ),
      CommentTemplateModel(
        id: 'e100',
        category: '대국 매너',
        content: '상대가 장고할 때 재촉하지 않고 기다려주는 인내심과 배려심을 갖추고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'e101',
        category: '대국 매너',
        content: '승리했을 때 자만하지 않고 패배한 상대를 위로할 줄 아는 성숙한 태도를 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'e102',
        category: '대국 매너',
        content: '패배했을 때도 상대방의 좋은 수를 칭찬하며 깨끗하게 결과에 승복하는 스포츠맨십이 훌륭합니다.',
      ),
      CommentTemplateModel(
        id: 'e103',
        category: '대국 매너',
        content: '대국 중 불필요한 말이나 행동을 삼가고 오직 반상 승부에만 집중하는 진지함을 갖추었습니다.',
      ),
      CommentTemplateModel(
        id: 'e104',
        category: '대국 매너',
        content: '돌을 놓을 때 바른 손모양과 자세를 유지하며 품격 있는 대국 태도를 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'e105',
        category: '대국 매너',
        content: '계가 과정에서 상대방과 협력하여 정확하게 집을 세고 결과를 확인하는 절차를 잘 따릅니다.',
      ),

      // 4. 성장 변화 (Growth)
      CommentTemplateModel(
        id: 'g1',
        category: '성장 변화',
        content: '초기 대비 바둑판을 보는 시야가 넓어졌으며 착점 시의 자신감이 크게 향상되었습니다.',
      ),
      CommentTemplateModel(
        id: 'g10',
        category: '성장 변화',
        content: '단순히 돌을 따내기보다 판 전체를 보며 집을 지으려는 거시적인 안목이 생기기 시작했습니다.',
      ),
      CommentTemplateModel(
        id: 'g11',
        category: '성장 변화',
        content: '수읽기 능력이 정교해지면서 실전 대국에서의 승률 또한 눈에 띄게 상승하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g100',
        category: '성장 변화',
        content: '자신보다 상위 급수의 친구에게도 위축되지 않고 대등한 경기를 펼칠 만큼 담력이 커졌습니다.',
      ),
      CommentTemplateModel(
        id: 'g101',
        category: '성장 변화',
        content: '예전에는 실수하면 당황했으나, 이제는 침착하게 수습하고 다음 기회를 노리는 위기관리 능력이 생겼습니다.',
      ),
      CommentTemplateModel(
        id: 'g102',
        category: '성장 변화',
        content: '단수만 보던 시야에서 벗어나 돌의 연결과 끊음을 동시에 고려하는 입체적인 사고가 가능해졌습니다.',
      ),
      CommentTemplateModel(
        id: 'g103',
        category: '성장 변화',
        content: '기보를 보거나 문제를 풀 때 정답을 맞히는 속도가 빨라졌으며 직관적인 감각이 발달하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g104',
        category: '성장 변화',
        content: '바둑을 통해 키워진 집중력과 인내심이 평소 생활 태도에서도 긍정적인 변화로 나타나고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g105',
        category: '성장 변화',
        content: '자신만의得意戰法(특기 전법)이 생기기 시작하여 바둑 두는 재미를 한층 더 느끼고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g106',
        category: '성장 변화',
        content: '어려운 사활 문제에 도전하는 것을 즐기며, 끈기 있게 생각하는 힘이 몰라보게 길러졌습니다.',
      ),

      // 5. 마무리 (Conclusion)
      CommentTemplateModel(
        id: 'c1',
        category: '마무리',
        content: '지금처럼 바둑을 즐기며 성실하게 노력한다면 머지않아 훌륭한 기량을 갖추게 될 것입니다.',
      ),
      CommentTemplateModel(
        id: 'c2',
        category: '마무리',
        content: '앞으로도 {{name}} 학생의 멋진 성장을 기대하며 적극적으로 지원하고 지도하겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c5',
        category: '마무리',
        content: '꾸준함이 가장 큰 무기입니다. {{name}} 학생의 밝은 미래를 응원합니다.',
      ),
      CommentTemplateModel(
        id: 'c100',
        category: '마무리',
        content: '가정에서도 {{name}} 학생이 바둑을 통해 얻는 성취감을 함께 나누고 격려해 주시기 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'c101',
        category: '마무리',
        content: '다음 단계로 도약하기 위한 중요한 시기인 만큼, 더욱 세심한 지도로 이끌어 나가겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c102',
        category: '마무리',
        content: '바둑을 통해 배운 지혜가 {{name}} 학생의 삶에 든든한 밑거름이 되기를 소망합니다.',
      ),
      CommentTemplateModel(
        id: 'c103',
        category: '마무리',
        content: '{{name}} 학생의 무한한 잠재력을 믿으며, 앞으로도 즐거운 바둑 수업이 되도록 노력하겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c104',
        category: '마무리',
        content: '한 판의 바둑을 완성하듯, {{name}} 학생이 자신의 꿈을 멋지게 그려나갈 수 있도록 돕겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c105',
        category: '마무리',
        content: '함께 바둑을 공부하는 시간이 {{name}} 학생에게 행복한 추억이자 성장의 기회가 되길 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'c106',
        category: '마무리',
        content: '승급을 목표로 더욱 정진할 {{name}} 학생에게 아낌없는 칭찬과 응원을 부탁드립니다.',
      ),
      CommentTemplateModel(
        id: 'c3',
        category: '마무리',
        content: '바둑을 통해 키운 수읽기 능력과 인내심이 다른 학습에도 긍정적인 영향을 미치길 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'c4',
        category: '마무리',
        content: '다음 달에는 더욱 발전된 모습으로 깊이 있는 바둑을 함께 연구해 나가기를 희망합니다.',
      ),
      CommentTemplateModel(
        id: 'c5',
        category: '마무리',
        content: '꾸준함이 가장 큰 무기입니다. {{name}} 학생의 밝은 미래를 응원합니다.',
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
  final bool showAttendance;
  final bool showRadarChart;
  final bool showProgress;
  final bool showCompetency;
  final AchievementScores scores;
  final BalanceChartType balanceChartType;
  final DetailViewType detailViewType;
  final String teacherComment;
  final Function(String) onAcademyNameChanged;
  final Function(String) onReportTitleChanged;
  final Function(String) onReportDateChanged;
  final Function(String) onLevelChanged;
  final Function(AchievementScores) onScoresChanged;
  final Function(BalanceChartType) onChartTypeChanged;

  final Function(String) onCommentChanged;
  final VoidCallback onOpenCommentPicker;
  final VoidCallback onRerollComment;
  final bool isLayoutEditing;
  final Map<String, WidgetLayout> layouts;
  final Function(String, WidgetLayout) onLayoutChanged;
  final int layoutVersion; // 추가: 강제 리빌드를 위한 버전
  final List<CommentTemplateModel> templates; // 추가: 문구 추천 데이터

  final ReportTemplateType templateType;
  final bool isPrinting; // 인쇄/저장 모드 플래그

  _EducationReportPaper({
    super.key,
    required this.student,
    required this.academy,
    required this.progressList,
    required this.academyName,
    required this.reportTitle,
    required this.reportDate,
    required this.studentLevel,
    required this.showLevel,
    required this.showAttendance,
    required this.showRadarChart,
    required this.showProgress,
    required this.showCompetency,
    required this.scores,
    required this.balanceChartType,
    required this.detailViewType,
    required this.teacherComment,
    required this.onAcademyNameChanged,
    required this.onReportTitleChanged,
    required this.onReportDateChanged,
    required this.onLevelChanged,
    required this.onScoresChanged,
    required this.onChartTypeChanged,

    required this.onCommentChanged,
    required this.onOpenCommentPicker,
    required this.onRerollComment,
    required this.isLayoutEditing,
    required this.layouts,
    required this.onLayoutChanged,
    required this.layoutVersion,
    this.templates = const [],
    this.templateType = ReportTemplateType.classic,
    this.isPrinting = false,
  });

  @override
  Widget build(BuildContext context) {
    return _buildClassicLayout(context);
  }

  Widget _buildClassicLayout(BuildContext context) {
    return Container(
      width: 600,
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
          aspectRatio: 1 / 1.41,
          child: Container(
            color: const Color(0xFFF5F7FA),
            padding: const EdgeInsets.all(32.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAcademyInfo(context),
                _buildReportTitle(context),
                _buildStudentInfoBar(context),
                if (showRadarChart) _buildRadarChartSection(context),
                if (showProgress) _buildProgressSection(),
                if (showCompetency) _buildCompetencySection(context),
                _buildCommentSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcademyInfo(BuildContext context) {
    return ResizableDraggableWrapper(
      key: ValueKey('academyInfo_$layoutVersion'),
      initialTop: layouts['academyInfo']?.top ?? 20,
      initialLeft: layouts['academyInfo']?.left ?? 0,
      initialWidth: layouts['academyInfo']?.width ?? 200,
      initialHeight: layouts['academyInfo']?.height ?? 45,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'academyInfo',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _showEditDialog(
              context,
              title: '학원명/교실명',
              initialValue: academyName,
              studentName: student.name,
              onSaved: onAcademyNameChanged,
            ),
            child: Text(
              academyName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          InkWell(
            onTap: () => _showDatePicker(context),
            child: Text(
              reportDate,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTitle(BuildContext context) {
    if (templateType != ReportTemplateType.classic) {
      return const SizedBox.shrink();
    }

    return ResizableDraggableWrapper(
      key: ValueKey('reportTitle_$layoutVersion'),
      initialTop: layouts['reportTitle']?.top ?? 110,
      initialLeft: layouts['reportTitle']?.left ?? 0,
      initialWidth: layouts['reportTitle']?.width ?? 530,
      initialHeight: layouts['reportTitle']?.height ?? 30,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'reportTitle',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: InkWell(
        onTap: () => _showEditDialog(
          context,
          title: '레포트 제목',
          initialValue: reportTitle,
          studentName: student.name,
          onSaved: onReportTitleChanged,
        ),
        child: Center(
          child: Text(
            reportTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoBar(BuildContext context) {
    return ResizableDraggableWrapper(
      key: ValueKey('studentInfo_$layoutVersion'),
      initialTop: layouts['studentInfo']?.top ?? 160,
      initialLeft: layouts['studentInfo']?.left ?? 0,
      initialWidth: layouts['studentInfo']?.width ?? 530,
      initialHeight: layouts['studentInfo']?.height ?? 62,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'studentInfo',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
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
              _buildInfoItem('급수', studentLevel),
            ],
            if (showAttendance) ...[
              _buildDivider(),
              FutureBuilder<double>(
                future: _fetchAttendanceRate(context),
                builder: (context, snapshot) {
                  String text = '-';
                  if (snapshot.hasData) {
                    text = '${snapshot.data!.toStringAsFixed(0)}%';
                  }
                  return _buildInfoItem('출석률', text);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<double> _fetchAttendanceRate(BuildContext context) async {
    try {
      // reportDate 문자열 ("2023. 05. 01")을 DateTime으로 파싱
      final parts = reportDate.split('.');
      if (parts.length < 3) return 0.0;

      final year = int.parse(parts[0].trim());
      final month = int.parse(parts[1].trim());
      // 해당 월의 1일
      final startDate = DateTime(year, month, 1);
      // 해당 월의 마지막 날 (다음달 1일의 하루 전)
      final endDate = DateTime(year, month + 1, 0);

      final provider = context.read<AttendanceProvider>();
      final records = await provider.getRecordsForPeriod(
        academyId: academy.id,
        ownerId: academy.ownerId,
        start: startDate,
        end: endDate,
      );

      // 해당 학생의 기록만 필터링
      final studentRecords = records
          .where((r) => r.studentId == student.id)
          .toList();

      if (studentRecords.isEmpty) return 0.0;

      // 출석률 계산: (출석+지각) / 전체 기록 수
      // 전체 기록 수는 '출석체크를 한 날의 수'로 가정 (결석 포함)
      return provider.getAttendanceRate(studentRecords, studentRecords.length);
    } catch (e) {
      debugPrint('Error fetching attendance rate: $e');
      return 0.0;
    }
  }

  Widget _buildRadarChartSection(BuildContext context) {
    return ResizableDraggableWrapper(
      key: ValueKey('radar_$layoutVersion'),
      initialTop: layouts['radar']?.top ?? 222,
      initialLeft: layouts['radar']?.left ?? 0,
      initialWidth: layouts['radar']?.width ?? 230,
      initialHeight: layouts['radar']?.height ?? 250,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'radar',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [Expanded(child: _buildChart())]),
        ),
      ),
    );
  }

  Widget _buildChart() {
    switch (balanceChartType) {
      case BalanceChartType.radar:
        return RadarChartWidget(scores: scores);
      case BalanceChartType.line:
        return LineChartWidget(scores: scores);
      case BalanceChartType.doughnut:
        return DoughnutChartWidget(scores: scores);
      case BalanceChartType.barVertical:
        return BarVerticalChartWidget(scores: scores);
      case BalanceChartType.barHorizontal:
        return BarHorizontalChartWidget(scores: scores);
    }
  }

  Widget _buildProgressSection() {
    return ResizableDraggableWrapper(
      key: ValueKey('progress_$layoutVersion'),
      initialTop: layouts['progress']?.top ?? 222,
      initialLeft: layouts['progress']?.left ?? 250,
      initialWidth: layouts['progress']?.width ?? 280,
      initialHeight: layouts['progress']?.height ?? 118,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'progress',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '[ 교재 학습 현황 ]',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(child: _buildProgressList()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressList() {
    if (progressList.isEmpty)
      return const Text(
        '학습 데이터가 없습니다.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    return Column(
      children: progressList
          .take(3)
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  LinearProgressIndicator(
                    value: p.progressPercentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.indigo.shade300,
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCompetencySection(BuildContext context) {
    return ResizableDraggableWrapper(
      key: ValueKey('competency_$layoutVersion'),
      initialTop: layouts['competency']?.top ?? 345,
      initialLeft: layouts['competency']?.left ?? 250,
      initialWidth: layouts['competency']?.width ?? 280,
      initialHeight: layouts['competency']?.height ?? 145,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'competency',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: _buildDetailContent(context))],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context) {
    switch (detailViewType) {
      case DetailViewType.table:
        return _buildDetailTable(context);
      case DetailViewType.gridCards:
        return _buildDetailGrid(context);
      case DetailViewType.progressBar:
        return _buildDetailProgress(context);
    }
  }

  Widget _buildDetailProgress(BuildContext context) {
    return Column(
      children: [
        _buildScoreBarCompact(
          '집중력',
          scores.focus,
          Colors.blue.shade700,
          () => _showScoreEditDialog(context),
        ),
        _buildScoreBarCompact(
          '응용력',
          scores.application,
          Colors.teal.shade600,
          () => _showScoreEditDialog(context),
        ),
        _buildScoreBarCompact(
          '정확도',
          scores.accuracy,
          Colors.orange.shade700,
          () => _showScoreEditDialog(context),
        ),
        _buildScoreBarCompact(
          '과제수행',
          scores.task,
          Colors.purple.shade600,
          () => _showScoreEditDialog(context),
        ),
        _buildScoreBarCompact(
          '창의성',
          scores.creativity,
          Colors.pink.shade600,
          () => _showScoreEditDialog(context),
        ),
      ],
    );
  }

  Widget _buildDetailTable(BuildContext context) {
    final data = [
      {'label': '집중력', 'score': scores.focus},
      {'label': '응용력', 'score': scores.application},
      {'label': '정확도', 'score': scores.accuracy},
      {'label': '과제수행', 'score': scores.task},
      {'label': '창의성', 'score': scores.creativity},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade100),
            children: const [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  '평가 항목',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  '점수',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  '등급',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          // Body
          ...data.map((item) {
            final score = item['score'] as int;
            return TableRow(
              children: [
                InkWell(
                  onTap: () => _showScoreEditDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      item['label'] as String,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showScoreEditDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '$score점',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showScoreEditDialog(context),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _getGrade(score),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getGradeColor(score),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailGrid(BuildContext context) {
    final data = [
      {'label': '집중력', 'score': scores.focus},
      {'label': '응용력', 'score': scores.application},
      {'label': '정확도', 'score': scores.accuracy},
      {'label': '과제수행', 'score': scores.task},
      {'label': '창의성', 'score': scores.creativity},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: data.map((item) {
        final score = item['score'] as int;
        // 등급 색상을 테두리나 배경에 활용
        final gradeColor = _getGradeColor(score);

        return InkWell(
          onTap: () => _showScoreEditDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: gradeColor.withOpacity(0.5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: gradeColor.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: gradeColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGrade(score),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: gradeColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getGrade(int score) {
    if (score >= 90) return '최우수';
    if (score >= 80) return '우수';
    if (score >= 70) return '보통';
    if (score >= 60) return '노력';
    return '미흡';
  }

  Color _getGradeColor(int score) {
    if (score >= 90) return const Color(0xFF1A237E); // Navy
    if (score >= 80) return Colors.blue.shade700;
    if (score >= 70) return Colors.green.shade700;
    if (score >= 60) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Widget _buildStrengthsSection(BuildContext context) {
    // 자동으로 강점 생성
    final strengths = _autoGenerateStrengths();

    return ResizableDraggableWrapper(
      key: ValueKey('strengths_$layoutVersion'),
      initialTop: layouts['strengths']?.top ?? 345,
      initialLeft: layouts['strengths']?.left ?? 250,
      initialWidth: layouts['strengths']?.width ?? 280,
      initialHeight: layouts['strengths']?.height ?? 120,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'strengths',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '[ 주목할 만한 성장 ]',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (strengths.isEmpty)
                const Text(
                  '90점 이상인 역량이 없습니다',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                )
              else
                Expanded(
                  child: ListView(
                    children: strengths
                        .map(
                          (strength) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strength['icon']!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        strength['title']!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        strength['description']!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _autoGenerateStrengths() {
    final scoreMap = {
      'focus': {
        'score': scores.focus,
        'icon': '🎯',
        'title': '집중력',
        'description': '50분 수업 내내 흐트러짐 없이 학습!',
      },
      'application': {
        'score': scores.application,
        'icon': '💡',
        'title': '응용력',
        'description': '배운 내용을 실전에 잘 적용합니다',
      },
      'accuracy': {
        'score': scores.accuracy,
        'icon': '✓',
        'title': '정확도',
        'description': '문제 풀이 정확도가 매우 우수합니다',
      },
      'task': {
        'score': scores.task,
        'icon': '📝',
        'title': '과제수행',
        'description': '매주 과제를 성실히 완수했습니다',
      },
      'creativity': {
        'score': scores.creativity,
        'icon': '🌟',
        'title': '창의성',
        'description': '독창적인 수 선택으로 깊은 사고력을 보여줍니다',
      },
    };

    // 90점 이상인 역량만 필터링하고 점수순으로 정렬
    final filteredScores =
        scoreMap.entries
            .where((entry) => entry.value['score'] as int >= 90)
            .toList()
          ..sort(
            (a, b) =>
                (b.value['score'] as int).compareTo(a.value['score'] as int),
          );

    // 상위 2개만 선택
    return filteredScores
        .take(2)
        .map(
          (entry) => {
            'icon': entry.value['icon'] as String,
            'title': entry.value['title'] as String,
            'description': entry.value['description'] as String,
          },
        )
        .toList();
  }

  Widget _buildCommentSection(BuildContext context) {
    return ResizableDraggableWrapper(
      key: ValueKey('comment_$layoutVersion'),
      initialTop: layouts['comment']?.top ?? 500,
      initialLeft: layouts['comment']?.left ?? 0,
      initialWidth: layouts['comment']?.width ?? 530,
      initialHeight: layouts['comment']?.height ?? 250,
      isEditing: isLayoutEditing,
      onLayoutChanged: (t, l, w, h) => onLayoutChanged(
        'comment',
        WidgetLayout(top: t, left: l, width: w, height: h),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '[ 지도교사 종합 의견 ]',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (!isPrinting)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: onRerollComment,
                        ),
                        IconButton(
                          icon: const Icon(Icons.grid_view, size: 16),
                          onPressed: onOpenCommentPicker,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _showEditDialog(
                    context,
                    title: '종합 의견',
                    initialValue: teacherComment,
                    onSaved: onCommentChanged,
                    isMultiline: true,
                    templates: templates,
                    studentName: student.name,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AutoSizeText(
                      teacherComment,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                      minFontSize: 10,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildScoreBarCompact(
    String label,
    int score,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      hoverColor: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$score점',
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: color.withOpacity(0.1),
                color: color,
                minHeight: 3,
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
    List<CommentTemplateModel> templates = const [],
    String? studentName,
    List<String>? textbookNames,
  }) {
    print(
      '🔍 _showEditDialog called: title=$title, isMultiline=$isMultiline, templates.length=${templates.length}',
    );
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title 수정'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
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
              if (templates.isNotEmpty && isMultiline) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context, // 부모 컨텍스트 사용
                        isScrollControlled: true,
                        builder: (sheetContext) => CommentGridPicker(
                          templates: templates,
                          multiSelect: true, // 다중 선택 모드 활성화
                          studentName: studentName,
                          textbookNames: textbookNames,
                          onSelected: (content) {
                            // 커서 위치에 삽입하거나 끝에 추가
                            final text = controller.text;
                            final selection = controller.selection;
                            String newText;

                            if (selection.start >= 0 && selection.end >= 0) {
                              final beforeText = text.substring(
                                0,
                                selection.start,
                              );
                              final afterText = text.substring(selection.end);

                              // 기존 텍스트가 있으면 자연스럽게 연결
                              if (beforeText.isNotEmpty &&
                                  !beforeText.endsWith(' ') &&
                                  !beforeText.endsWith('\n')) {
                                newText = '$beforeText $content$afterText';
                              } else {
                                newText = '$beforeText$content$afterText';
                              }
                            } else {
                              // 기존 내용 뒤에 추가
                              if (text.isNotEmpty &&
                                  !text.endsWith(' ') &&
                                  !text.endsWith('\n')) {
                                newText = '$text $content';
                              } else {
                                newText = '$text$content';
                              }
                            }

                            // 최종 결합 로직 재적용 (마침표 등 보정)
                            controller.text =
                                ReportCommentUtils.combineFragments([newText]);
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.grid_view, size: 16),
                    label: const Text('문구 선택'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: Colors.indigo.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              onSaved(controller.text.trim());
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy. MM. dd').format(picked);
      onReportDateChanged(formattedDate);
    }
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
