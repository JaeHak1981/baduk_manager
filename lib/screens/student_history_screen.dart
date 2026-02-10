import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/progress_provider.dart';
import '../widgets/student_history_table.dart';

class StudentHistoryScreen extends StatefulWidget {
  final StudentModel student;
  final String academyId;
  final String? ownerId;

  const StudentHistoryScreen({
    super.key,
    required this.student,
    required this.academyId,
    this.ownerId,
  });

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().loadStudentProgress(
        widget.student.id,
        ownerId: widget.ownerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.student.name} 학습 정보'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.history), text: '학습 로그 (표)'),
              Tab(icon: Icon(Icons.event_note), text: '수강 및 부 이동 이력'),
              Tab(icon: Icon(Icons.calendar_month), text: '월별 히스토리'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. 학습 로그 (엑셀 스타일 표)
            _buildHistoryTableTab(),
            // 2. 수강 및 부 이동 이력
            _buildEnrollmentHistoryTab(),
            // 3. 기존 월별 히스토리 (유지)
            const Center(child: Text('월별 히스토리 기능 준비 중')),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentHistoryTab() {
    final s = widget.student;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistorySection(
            title: '수강 신청 및 퇴원 예약',
            icon: Icons.school_outlined,
            items: s.enrollmentHistory
                .map(
                  (e) =>
                      '${e.startDate.year}-${e.startDate.month}-${e.startDate.day} ~ '
                      '${e.endDate != null ? "${e.endDate!.year}-${e.endDate!.month}-${e.endDate!.day} (퇴원예정)" : "현재 수강 중"}',
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          _buildHistorySection(
            title: '부 이동 및 예약',
            icon: Icons.schedule_outlined,
            items: s.sessionHistory.reversed
                .map(
                  (h) =>
                      '${h.effectiveDate.year}-${h.effectiveDate.month}-${h.effectiveDate.day}: ${h.sessionId}부',
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text('내역이 없습니다.', style: TextStyle(color: Colors.grey))
        else
          ...items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(item, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTableTab() {
    return Consumer<ProgressProvider>(
      builder: (context, provider, child) {
        final progressList = provider.getProgressForStudent(widget.student.id);

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '전체 학습 로그',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '총 ${progressList.length}건',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StudentHistoryTable(
                  studentId: widget.student.id,
                  ownerId: widget.ownerId ?? '',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
