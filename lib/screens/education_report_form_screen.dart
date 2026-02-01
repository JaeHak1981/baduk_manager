import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../models/academy_model.dart';
import '../models/education_report_model.dart';
import '../providers/education_report_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/progress_provider.dart';
import '../models/attendance_model.dart';
import '../services/printing_service.dart';
import 'components/radar_chart_widget.dart';

class EducationReportFormScreen extends StatefulWidget {
  final StudentModel student;
  final AcademyModel academy;
  final DateTime startDate;
  final DateTime endDate;

  const EducationReportFormScreen({
    super.key,
    required this.student,
    required this.academy,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<EducationReportFormScreen> createState() =>
      _EducationReportFormScreenState();
}

class _EducationReportFormScreenState extends State<EducationReportFormScreen> {
  EducationReportModel? _report;
  bool _isInitialized = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeReport();
  }

  Future<void> _initializeReport() async {
    final reportProvider = context.read<EducationReportProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final progressProvider = context.read<ProgressProvider>();

    // 0. 학생 진도 데이터 명시적 로드 (보안 필터 포함)
    await progressProvider.loadStudentProgress(
      widget.student.id,
      ownerId: widget.academy.ownerId,
    );

    // 1. 해당 기간 출석 데이터 조회
    final allAttendanceRecords = await attendanceProvider.getRecordsForPeriod(
      academyId: widget.academy.id,
      ownerId: widget.academy.ownerId,
      start: widget.startDate,
      end: widget.endDate,
    );

    // 해당 학생의 데이터만 필터링 (필수)
    final attendanceRecords = allAttendanceRecords
        .where((r) => r.studentId == widget.student.id)
        .toList();

    // 해당 기간에 수업이 있었던 것으로 간주되는 총 일수 (간단히 계산)
    final totalClasses = attendanceRecords.length;
    final presentCount = attendanceRecords
        .where(
          (r) =>
              r.type == AttendanceType.present || r.type == AttendanceType.late,
        )
        .length;

    // 2. 해당 기간 지급 교재 데이터 조회
    final progressList = progressProvider.getProgressForStudent(
      widget.student.id,
    );
    final periodProgress = progressList.where((p) {
      return p.startDate.isAfter(
            widget.startDate.subtract(const Duration(days: 1)),
          ) &&
          p.startDate.isBefore(widget.endDate.add(const Duration(days: 1)));
    }).toList();

    final textbookIds = periodProgress.map((p) => p.textbookId).toList();
    final textbookNames = periodProgress.map((p) => p.textbookName).toList();
    final volumes = periodProgress.map((p) => p.volumeNumber).toList();

    // 3. 초안 생성 (기본 템플릿 기반 총평 생성)
    final draft = await reportProvider.generateDraft(
      academyId: widget.academy.id,
      ownerId: widget.academy.ownerId,
      studentId: widget.student.id,
      studentName: widget.student.name,
      startDate: widget.startDate,
      endDate: widget.endDate,
      textbookNames: textbookNames,
      textbookIds: textbookIds,
      volumes: volumes,
      attendanceCount: presentCount,
      totalClasses: totalClasses,
    );

    if (mounted) {
      setState(() {
        _report = draft;
        _commentController.text = draft.teacherComment;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student.name} 교육 통지표 작성'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _handlePrint,
            tooltip: '미리보기 및 인쇄',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _handleSave,
            tooltip: '저장',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildScoreSliders(),
            const SizedBox(height: 24),
            _buildRadarChart(), // 실제 차트 위젯
            const SizedBox(height: 24),
            _buildCommentSection(),
            const SizedBox(height: 100), // 여백
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('대상 기간:', style: TextStyle(color: Colors.grey)),
                Text(
                  '${widget.startDate.year}.${widget.startDate.month} ~ ${widget.endDate.year}.${widget.endDate.month}',
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('지급 교재:', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Text(
                    _report!.textbookIds.isEmpty ? '기록 없음' : '지급됨',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('출석 현황:', style: TextStyle(color: Colors.grey)),
                Text(
                  '${_report!.attendanceCount}회 / ${_report!.totalClasses}회 (${(_report!.attendanceCount / (_report!.totalClasses == 0 ? 1 : _report!.totalClasses) * 100).toStringAsFixed(0)}%)',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSliders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성취도 평가 (슬라이더로 조절)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        _buildSliderItem('집중력', _report!.scores.focus, (v) {
          setState(
            () => _report = _report!.copyWith(
              scores: _report!.scores.copyWith(focus: v.toInt()),
            ),
          );
        }),
        _buildSliderItem('응용력', _report!.scores.application, (v) {
          setState(
            () => _report = _report!.copyWith(
              scores: _report!.scores.copyWith(application: v.toInt()),
            ),
          );
        }),
        _buildSliderItem('정확도', _report!.scores.accuracy, (v) {
          setState(
            () => _report = _report!.copyWith(
              scores: _report!.scores.copyWith(accuracy: v.toInt()),
            ),
          );
        }),
        _buildSliderItem('과제수행', _report!.scores.task, (v) {
          setState(
            () => _report = _report!.copyWith(
              scores: _report!.scores.copyWith(task: v.toInt()),
            ),
          );
        }),
        _buildSliderItem('창의성', _report!.scores.creativity, (v) {
          setState(
            () => _report = _report!.copyWith(
              scores: _report!.scores.copyWith(creativity: v.toInt()),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSliderItem(String label, int value, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: value.toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(value.toString(), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildRadarChart() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: RadarChartWidget(
        scores: _report!.scores,
        previousScores: _report!.previousScores,
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '지도 교사 총평',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
                  label: const Text(
                    '다시 생성',
                    style: TextStyle(color: Colors.blue),
                  ),
                  onPressed: _regenerateComment,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.library_books, size: 16),
                  label: const Text('보관함'),
                  onPressed: _showTemplatePicker,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            filled: false,
            fillColor: null,
            hintText: '아이의 학습 태도와 성취에 대해 적어주세요.',
          ),
          onChanged: (v) {
            _report = _report!.copyWith(teacherComment: v);
          },
        ),
      ],
    );
  }

  Future<void> _regenerateComment() async {
    if (_report == null) return;

    final reportProvider = context.read<EducationReportProvider>();
    final progressProvider = context.read<ProgressProvider>();

    final progressList = progressProvider.getProgressForStudent(
      widget.student.id,
    );
    final periodProgress = progressList.where((p) {
      return p.startDate.isAfter(
            widget.startDate.subtract(const Duration(days: 1)),
          ) &&
          p.startDate.isBefore(widget.endDate.add(const Duration(days: 1)));
    }).toList();

    final textbookIds = periodProgress.map((p) => p.textbookId).toList();
    final textbookNames = periodProgress.map((p) => p.textbookName).toList();
    final volumes = periodProgress.map((p) => p.volumeNumber).toList();

    final allAttendanceRecords = await context
        .read<AttendanceProvider>()
        .getRecordsForPeriod(
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
          start: widget.startDate,
          end: widget.endDate,
        );

    // 해당 학생의 데이터만 필터링
    final attendanceRecords = allAttendanceRecords
        .where((r) => r.studentId == widget.student.id)
        .toList();

    final presentCount = attendanceRecords
        .where(
          (r) =>
              r.type == AttendanceType.present || r.type == AttendanceType.late,
        )
        .length;

    final draft = await reportProvider.generateDraft(
      academyId: widget.academy.id,
      ownerId: widget.academy.ownerId,
      studentId: widget.student.id,
      studentName: widget.student.name,
      startDate: widget.startDate,
      endDate: widget.endDate,
      textbookNames: textbookNames,
      textbookIds: textbookIds,
      volumes: volumes,
      attendanceCount: presentCount,
      totalClasses: attendanceRecords.length,
    );

    if (mounted) {
      setState(() {
        _report = _report!.copyWith(teacherComment: draft.teacherComment);
        _commentController.text = draft.teacherComment;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📝 시스템이 보관함 기반 의견을 추천했습니다.')),
      );
    }
  }

  void _showTemplatePicker() {
    final templates = context.read<EducationReportProvider>().templates;
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final t = templates[index];
          final content = t.content
              .replaceAll('{{name}}', widget.student.name)
              .replaceAll('{{textbook}}', '해당 교재');
          return ListTile(
            title: Text(
              t.category,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            subtitle: Text(content),
            onTap: () {
              setState(() {
                _commentController.text = content;
                _report = _report!.copyWith(teacherComment: content);
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    final success = await context.read<EducationReportProvider>().saveReport(
      _report!,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '교육 통지표가 저장되었습니다.' : '저장 실패')),
      );
      if (success) Navigator.pop(context);
    }
  }

  Future<void> _handlePrint() async {
    final progressProvider = context.read<ProgressProvider>();
    final progressList = progressProvider.getProgressForStudent(
      widget.student.id,
    );
    final periodProgress = progressList
        .where(
          (p) =>
              p.startDate.isAfter(widget.startDate) &&
              p.startDate.isBefore(
                widget.endDate.add(const Duration(days: 31)),
              ),
        )
        .toList();
    final textbookNames = periodProgress.map((p) => p.textbookName).toList();

    await PrintingService.printReport(
      report: _report!,
      studentName: widget.student.name,
      textbookNames: textbookNames,
      academyName: widget.academy.name,
    );
  }
}
