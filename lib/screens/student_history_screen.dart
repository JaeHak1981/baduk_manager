import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/student_progress_model.dart';
import '../providers/progress_provider.dart';

class StudentHistoryScreen extends StatefulWidget {
  final StudentModel student;
  final String ownerId;

  const StudentHistoryScreen({
    super.key,
    required this.student,
    required this.ownerId,
  });

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 진도 데이터 로드 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressProvider>().loadStudentProgress(
        widget.student.id,
        ownerId: widget.ownerId,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student.name} 학생 정보'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '현재 진도'),
            Tab(text: '월별 히스토리'),
            Tab(text: '통지표'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentProgressTab(),
          _buildMonthlyHistoryTab(),
          _buildReportTab(),
        ],
      ),
    );
  }

  Widget _buildCurrentProgressTab() {
    return Consumer<ProgressProvider>(
      builder: (context, provider, child) {
        final progressList = provider.getProgressForStudent(widget.student.id);
        // 완료되지 않은(진행 중인) 교재만 필터링하거나, 전체를 보여주되 진행 중인 것을 상단에?
        // 기획상 '현재 진도'이므로 완료되지 않은 것 위주로 보여주는 게 좋지만,
        // 일단 전체 리스트를 보여주되 정렬을 최신순으로 함.
        if (progressList.isEmpty) {
          return const Center(child: Text('진도 기록이 없습니다.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: progressList.length,
          itemBuilder: (context, index) {
            final progress = progressList[index];
            return Card(
              child: ListTile(
                title: Text(
                  '${progress.textbookName} ${progress.volumeNumber}권',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress.progressPercentage / 100,
                      backgroundColor: Colors.grey[200],
                      color: progress.isCompleted ? Colors.green : Colors.blue,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.currentPage} / ${progress.totalPages}p (${progress.progressPercentage.toStringAsFixed(0)}%)',
                    ),
                    Text(
                      '시작일: ${DateFormat('yyyy-MM-dd').format(progress.startDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: progress.isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyHistoryTab() {
    return Consumer<ProgressProvider>(
      builder: (context, provider, child) {
        final progressList = provider.getProgressForStudent(widget.student.id);
        if (progressList.isEmpty) {
          return const Center(child: Text('히스토리 기록이 없습니다.'));
        }

        // 월별 그룹화 로직
        // "2024년 1월": [Textbook1, Textbook2...]
        final Map<String, List<StudentProgressModel>> grouped = {};

        // 단순하게 startDate 기준으로 그룹화할 수도 있고,
        // startDate ~ endDate 기간 내에 모든 월에 포함시킬 수도 있음.
        // 여기서는 '시작일' 기준으로 해당 월에 어떤 책을 시작했는지,
        // 혹은 '업데이트' 기준으로 어떤 책을 했는지 보여줄 수 있음.
        // 기획상 "1월부터 12월까지 무슨 달에 무슨 교재를 할당 받았는지" 이므로
        // 'startDate' 기준 월별 그룹화가 적절해 보임.

        for (var p in progressList) {
          final monthKey = DateFormat('yyyy년 M월').format(p.startDate);
          if (grouped[monthKey] == null) {
            grouped[monthKey] = [];
          }
          grouped[monthKey]!.add(p);
        }

        final sortedKeys = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // 최신 월 순서

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final key = sortedKeys[index];
            final monthlyList = grouped[key]!;

            return ExpansionTile(
              initiallyExpanded: index == 0, // 첫 번째(최신) 달은 펼쳐둠
              title: Text(
                key,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              children: monthlyList.map((p) {
                return ListTile(
                  title: Text('${p.textbookName} ${p.volumeNumber}권'),
                  subtitle: Text(
                    '${DateFormat('yyyy-MM-dd').format(p.startDate)} ~ ${p.endDate != null ? DateFormat('yyyy-MM-dd').format(p.endDate!) : '진행 중'}',
                  ),
                  trailing: p.isCompleted
                      ? const Chip(
                          label: Text('완료', style: TextStyle(fontSize: 10)),
                          backgroundColor: Colors.greenAccent,
                        )
                      : const Chip(
                          label: Text('진행', style: TextStyle(fontSize: 10)),
                        ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildReportTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '통지표 기능 준비 중입니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
