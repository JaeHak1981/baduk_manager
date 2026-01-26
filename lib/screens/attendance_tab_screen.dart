import 'package:flutter/material.dart';
import '../models/academy_model.dart';
import 'attendance_screen.dart';
import 'daily_attendance_screen.dart';

class AttendanceTabScreen extends StatefulWidget {
  final AcademyModel academy;
  final int initialIndex;

  const AttendanceTabScreen({
    super.key,
    required this.academy,
    this.initialIndex = 0,
  });

  @override
  State<AttendanceTabScreen> createState() => _AttendanceTabScreenState();
}

class _AttendanceTabScreenState extends State<AttendanceTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
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
        title: Text('${widget.academy.name} 출석 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '일일 출결', icon: Icon(Icons.fact_check_outlined)),
            Tab(text: '월별 출석부', icon: Icon(Icons.calendar_month_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DailyAttendanceScreen(academy: widget.academy, isEmbedded: true),
          AttendanceScreen(academy: widget.academy, isEmbedded: true),
        ],
      ),
    );
  }
}
