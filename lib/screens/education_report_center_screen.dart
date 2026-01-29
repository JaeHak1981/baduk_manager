import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../providers/education_report_provider.dart';
import '../providers/student_provider.dart';
import 'education_report_form_screen.dart';
import 'components/comment_template_management_dialog.dart';
import '../services/printing_service.dart';
import '../providers/attendance_provider.dart';
import '../providers/progress_provider.dart';
import '../models/attendance_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class EducationReportCenterScreen extends StatefulWidget {
  final AcademyModel academy;

  const EducationReportCenterScreen({super.key, required this.academy});

  @override
  State<EducationReportCenterScreen> createState() =>
      _EducationReportCenterScreenState();
}

class _EducationReportCenterScreenState
    extends State<EducationReportCenterScreen> {
  DateTime _startMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _endMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final Set<String> _selectedStudentIds = {};
  int? _selectedSession; // 부(session) 필터링

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentProvider>().loadStudents(
        widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
      context.read<EducationReportProvider>().loadTemplates(
        widget.academy.id,
        ownerId: widget.academy.ownerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교육 통지표 센터'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          const Divider(),
          _buildQuickSettings(),
          const Divider(),
          _buildSelectionToolbar(),
          const Divider(),
          Expanded(child: _buildStudentList()),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildPeriodSelector() {
    final monthFormat = DateFormat('yyyy년 MM월');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '통지표 대상 기간 설정',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectMonth(true),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(monthFormat.format(_startMonth)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Text('~'),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectMonth(false),
                  icon: const Icon(Icons.calendar_month),
                  label: Text(monthFormat.format(_endMonth)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSettingItem(Icons.style, '테마 설정', () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('테마 설정 기능 준비 중입니다.')));
          }),
          _buildSettingItem(Icons.library_books, '문구 관리', () {
            showDialog(
              context: context,
              builder: (context) => CommentTemplateManagementDialog(
                academyId: widget.academy.id,
                ownerId: widget.academy.ownerId,
              ),
            );
          }),
          _buildSettingItem(Icons.upload_file, '엑셀 관리', () {
            // Placeholder for Excel management functionality
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('엑셀 관리 기능 준비 중입니다.')));
            // Example of how ExcelUtils might be used (not fully implemented here)
            // ExcelUtils.exportCommentTemplates(
            //   [], // Replace with actual templates
            //   'comment_templates_${DateTime.now().millisecondsSinceEpoch}.xlsx',
            // );
          }),
        ],
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    return Consumer<StudentProvider>(
      builder: (context, studentProvider, child) {
        final students = studentProvider.students;
        final filteredStudents = _selectedSession == null
            ? students
            : students.where((s) => s.session == _selectedSession).toList();

        final bool isAllSelected =
            filteredStudents.isNotEmpty &&
            filteredStudents.every((s) => _selectedStudentIds.contains(s.id));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    onChanged: (val) {
                      setState(() {
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
                  const Text(
                    '전체 선택',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedStudentIds.length}명 선택됨',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('전체'),
                    selected: _selectedSession == null,
                    onSelected: (val) =>
                        setState(() => _selectedSession = null),
                  ),
                  const SizedBox(width: 8),
                  ...(() {
                    final sessions =
                        students
                            .map((s) => s.session)
                            .whereType<int>()
                            .toSet()
                            .toList()
                          ..sort();
                    return sessions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text('$s부'),
                          selected: _selectedSession == s,
                          onSelected: (val) =>
                              setState(() => _selectedSession = val ? s : null),
                        ),
                      ),
                    );
                  })(),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildStudentList() {
    return Consumer<StudentProvider>(
      builder: (context, studentProvider, child) {
        if (studentProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final allStudents = studentProvider.students;
        final students = _selectedSession == null
            ? allStudents
            : allStudents.where((s) => s.session == _selectedSession).toList();

        if (students.isEmpty) {
          return const Center(child: Text('해당하는 학생이 없습니다.'));
        }

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            final isSelected = _selectedStudentIds.contains(student.id);
            return ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedStudentIds.add(student.id);
                    } else {
                      _selectedStudentIds.remove(student.id);
                    }
                  });
                },
              ),
              title: Text(student.name),
              subtitle: Text(student.parentPhone ?? ''),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EducationReportFormScreen(
                        student: student,
                        academy: widget.academy,
                        startDate: _startMonth,
                        endDate: _endMonth,
                      ),
                    ),
                  );
                },
                child: const Text('작성'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: _handleBatchPrint,
        icon: const Icon(Icons.print),
        label: Text('체크된 ${_selectedStudentIds.length}명 일괄 발행 (PDF/인쇄)'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _handleBatchPrint() async {
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발행할 학생을 선택해 주세요.')));
      return;
    }

    final reportProvider = context.read<EducationReportProvider>();
    final studentProvider = context.read<StudentProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final progressProvider = context.read<ProgressProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<Map<String, dynamic>> reportDataList = [];

      // 1. 기간 전체 출석 데이터 로드
      List<AttendanceRecord> allAttendanceRecords = [];
      try {
        allAttendanceRecords = await attendanceProvider.getRecordsForPeriod(
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
          start: _startMonth,
          end: _endMonth,
        );
      } catch (e) {
        throw '출석 데이터 로드 실패: $e';
      }

      for (final id in _selectedStudentIds) {
        final student = studentProvider.students.firstWhere((s) => s.id == id);

        // 2. 학생별 진도 데이터 로드
        try {
          await progressProvider.loadStudentProgress(
            student.id,
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
          );
        } catch (e) {
          throw '${student.name}의 진도 데이터 로드 실패: $e';
        }

        // 3. 리포트 초안 생성
        try {
          final studentAttendance = allAttendanceRecords
              .where((r) => r.studentId == student.id)
              .toList();
          final presentCount = studentAttendance
              .where(
                (r) =>
                    r.type == AttendanceType.present ||
                    r.type == AttendanceType.late,
              )
              .length;

          final progressList = progressProvider.getProgressForStudent(
            student.id,
          );
          final periodProgress = progressList
              .where(
                (p) =>
                    p.startDate.isAfter(
                      _startMonth.subtract(const Duration(days: 1)),
                    ) &&
                    p.startDate.isBefore(
                      _endMonth.add(const Duration(days: 31)),
                    ),
              )
              .toList();
          final textbookNames = periodProgress
              .map((p) => p.textbookName)
              .toList();

          final report = await reportProvider.generateDraft(
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            studentId: student.id,
            studentName: student.name,
            startDate: _startMonth,
            endDate: _endMonth,
            textbookNames: textbookNames,
            textbookIds: periodProgress.map((p) => p.textbookId).toList(),
            volumes: periodProgress.map((p) => p.volumeNumber).toList(),
            attendanceCount: presentCount,
            totalClasses: studentAttendance.length,
          );

          reportDataList.add({
            'report': report,
            'studentName': student.name,
            'textbookNames': textbookNames,
          });
        } catch (e) {
          throw '${student.name}의 리포트 생성 실패: $e';
        }
      }

      if (mounted) Navigator.pop(context); // 로딩 닫기

      try {
        await PrintingService.printMultipleReports(
          reportDataList: reportDataList,
          academyName: widget.academy.name,
        );
      } catch (e) {
        throw 'PDF 생성 및 인쇄 실패: $e';
      }
    } catch (e, stack) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('발행 중 오류 발생', '$e\n\n$stack');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('아래 에러 내용을 복사하여 개발자에게 전달해 주세요.'),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('에러 내용이 클립보드에 복사되었습니다.')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('복사하기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMonth(bool isStart) async {
    // 월 선택 에뮬레이션 (간단한 버전)
    final now = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isStart ? '시작 월 선택' : '종료 월 선택'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isStart) {
                      _startMonth = DateTime(now.year, month);
                    } else {
                      _endMonth = DateTime(now.year, month);
                    }
                  });
                  Navigator.pop(context);
                },
                child: Center(child: Text('$month월')),
              );
            },
          ),
        ),
      ),
    );
  }
}
