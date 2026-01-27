import 'package:flutter/material.dart';
import '../models/academy_model.dart';
import 'attendance_screen.dart';
import 'daily_attendance_screen.dart';
import '../providers/student_provider.dart';
import 'package:provider/provider.dart';

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
  final GlobalKey<DailyAttendanceScreenState> _dailyKey = GlobalKey();
  final GlobalKey<AttendanceScreenState> _monthlyKey = GlobalKey();

  // 최적화를 위한 상태 관리 Notifier
  final ValueNotifier<int> _selectedCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isSelectionMode = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isFullSelection = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    // 탭 변경 시 앱바 갱신을 위해 리스너 추가
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _selectedCount.dispose();
    _isSelectionMode.dispose();
    _isFullSelection.dispose();
    super.dispose();
  }

  void _refreshAppBar() {
    // 이제 setState 대신 Notifier 값을 업데이트합니다.
    final state = _tabController.index == 0
        ? _dailyKey.currentState
        : _monthlyKey.currentState;

    if (state != null) {
      if (state is DailyAttendanceScreenState) {
        _isSelectionMode.value = state.isSelectionMode;
        _selectedCount.value = state.selectedStudentIds.length;

        final visibleStudents = state.getFilteredStudents(
          context.read<StudentProvider>().students,
        );
        _isFullSelection.value =
            visibleStudents.isNotEmpty &&
            _selectedCount.value == visibleStudents.length;
      } else if (state is AttendanceScreenState) {
        _isSelectionMode.value = state.isSelectionMode;
        _selectedCount.value = state.selectedStudentIds.length;

        final visibleStudents = state.getVisibleStudents(
          context.read<StudentProvider>().students,
        );
        _isFullSelection.value =
            visibleStudents.isNotEmpty &&
            _selectedCount.value == visibleStudents.length;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isSelectionMode,
      builder: (context, isSelectionMode, contentChild) {
        return ValueListenableBuilder<int>(
          valueListenable: _selectedCount,
          builder: (context, selectedCount, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isFullSelection,
              builder: (context, isFullSelection, _) {
                return Scaffold(
                  appBar: AppBar(
                    title: isSelectionMode
                        ? Text(
                            '$selectedCount명 선택됨',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : Text(
                            '${widget.academy.name} 출석 관리',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                    backgroundColor: isSelectionMode
                        ? Colors.red.shade50
                        : Theme.of(context).colorScheme.inversePrimary,
                    leading: isSelectionMode
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: toggleMode,
                          )
                        : null,
                    actions: isSelectionMode
                        ? [
                            IconButton(
                              icon: const Icon(Icons.drive_file_move_outline),
                              tooltip: '부 이동',
                              onPressed: () {
                                if (_tabController.index == 0) {
                                  _dailyKey.currentState?.moveSelectedStudents(
                                    context,
                                    widget.academy.ownerId,
                                  );
                                } else {
                                  _monthlyKey.currentState
                                      ?.moveSelectedStudents(
                                        context,
                                        widget.academy.ownerId,
                                      );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: '삭제',
                              onPressed: () {
                                if (_tabController.index == 0) {
                                  _dailyKey.currentState
                                      ?.deleteSelectedStudents(
                                        context,
                                        widget.academy.ownerId,
                                      );
                                } else {
                                  _monthlyKey.currentState
                                      ?.deleteSelectedStudents(
                                        context,
                                        widget.academy.ownerId,
                                      );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                          ]
                        : [
                            IconButton(
                              icon: const Icon(Icons.check_box_outlined),
                              tooltip: '다중 선택',
                              onPressed: () {
                                if (_tabController.index == 0) {
                                  _dailyKey.currentState?.toggleSelectionMode();
                                } else {
                                  _monthlyKey.currentState
                                      ?.toggleSelectionMode();
                                }
                              },
                            ),
                          ],
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.black87,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      indicatorColor: Colors.black,
                      tabs: const [
                        Tab(
                          text: '일일 출결',
                          icon: Icon(Icons.fact_check, size: 24),
                        ),
                        Tab(
                          text: '월별 출석부',
                          icon: Icon(Icons.calendar_month, size: 24),
                        ),
                      ],
                    ),
                  ),
                  body: contentChild,
                );
              },
            );
          },
        );
      },
      child: TabBarView(
        controller: _tabController,
        children: [
          DailyAttendanceScreen(
            key: _dailyKey,
            academy: widget.academy,
            isEmbedded: true,
            onSelectionModeChanged: _refreshAppBar,
          ),
          AttendanceScreen(
            key: _monthlyKey,
            academy: widget.academy,
            isEmbedded: true,
            onSelectionModeChanged: _refreshAppBar,
          ),
        ],
      ),
    );
  }
}
