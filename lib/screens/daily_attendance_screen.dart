import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/auth_provider.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final AcademyModel academy;
  final bool isEmbedded;

  const DailyAttendanceScreen({
    super.key,
    required this.academy,
    this.isEmbedded = false,
  });

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final DateTime _today = DateTime.now();
  int? _selectedSession;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ownerId = context.read<AuthProvider>().currentUser?.uid ?? '';
      context.read<AttendanceProvider>().loadMonthlyAttendance(
        academyId: widget.academy.id,
        ownerId: ownerId,
        year: _today.year,
        month: _today.month,
      );
      context.read<StudentProvider>().loadStudents(
        widget.academy.id,
        ownerId: ownerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keep alive를 위해 호출
    final studentProvider = context.watch<StudentProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    // 데이터가 아예 없을 때만 전면 로딩 표시
    if (studentProvider.isLoading && studentProvider.students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final authProvider = context.read<AuthProvider>();
    final ownerId = authProvider.currentUser?.uid ?? '';

    // 오늘 요일에 수업이 있는 학생들만 필터링
    final allStudents = studentProvider.students;

    // 1. 오늘 요일 필터링 (StudentModel에 lessonDays 정보가 있는지 확인 필요,
    // 여기서는 간단히 학원의 전체 수업 요일에 포함되는 모든 학생을 보여주고
    // 나중에 학생별 요일 정보가 있다면 추가 필터링 가능)
    var filteredStudents = allStudents.where((s) {
      // 만약 학생별 요일 정보가 없다면 학원 정보 활용
      // 실제로는 학생별로 수강 요일이 다를 수 있으므로 StudentModel을 참고해야 함
      // 임시로 모든 학생 표시 (또는 학원 수업일인 경우 전체 표시)
      return true;
    }).toList();

    // 2. 부(Session) 필터링
    if (_selectedSession != null) {
      filteredStudents = filteredStudents.where((s) {
        if (_selectedSession == 0) return s.session == null || s.session == 0;
        return s.session == _selectedSession;
      }).toList();
    }

    // 출석 데이터 맵
    final attendanceMap = <String, AttendanceRecord>{};
    for (var r in attendanceProvider.monthlyRecords) {
      if (r.timestamp.year == _today.year &&
          r.timestamp.month == _today.month &&
          r.timestamp.day == _today.day) {
        attendanceMap[r.studentId] = r;
      }
    }

    Widget body = Column(
      children: [
        _buildSessionFilter(allStudents),
        Expanded(
          child: filteredStudents.isEmpty
              ? const Center(child: Text('표시할 학생이 없습니다.'))
              : SingleChildScrollView(
                  key: const PageStorageKey('daily_attendance_scroll_vertical'),
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    key: const PageStorageKey(
                      'daily_attendance_scroll_horizontal',
                    ),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      horizontalMargin: 12,
                      headingRowHeight: 45,
                      dataRowMinHeight: 45,
                      dataRowMaxHeight: 45,
                      columns: const [
                        DataColumn(
                          label: Text(
                            '번호',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '이름',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 60,
                            child: Text(
                              '출결',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            '비고',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: filteredStudents.asMap().entries.map((entry) {
                        final index = entry.key;
                        final student = entry.value;
                        final record = attendanceMap[student.id];

                        return DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              SizedBox(
                                width: 60,
                                child: Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: _buildCircularToggleCell(
                                  context,
                                  attendanceProvider,
                                  student.id,
                                  ownerId,
                                  _today,
                                  record,
                                ),
                              ),
                            ),
                            DataCell(
                              _buildRemarkCell(
                                context,
                                attendanceProvider,
                                student.id,
                                ownerId,
                                _today,
                                attendanceMap,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );

    if (widget.isEmbedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_today.month}월 ${_today.day}일 출결 체크'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: body,
    );
  }

  Widget _buildSessionFilter(List<StudentModel> allStudents) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: Text('전체 (${allStudents.length})'),
            selected: _selectedSession == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSession = null);
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('미배정'),
            selected: _selectedSession == 0,
            onSelected: (selected) {
              if (selected) setState(() => _selectedSession = 0);
            },
          ),
          ...List.generate(widget.academy.totalSessions, (i) => i + 1).map((s) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text('$s부'),
                selected: _selectedSession == s,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedSession = s);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // [추가] 비고란 셀 빌더
  Widget _buildRemarkCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    Map<String, AttendanceRecord> attendanceMap,
  ) {
    final record = attendanceMap[studentId];
    final controller = TextEditingController(text: record?.note ?? "");

    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          border: InputBorder.none,
          hintText: '비고 입력...',
          hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        onSubmitted: (text) {
          provider.updateNote(
            studentId: studentId,
            academyId: widget.academy.id,
            ownerId: ownerId,
            date: date,
            note: text,
          );
        },
      ),
    );
  }

  // [추가] 순환 토글 방식의 셀 빌더
  Widget _buildCircularToggleCell(
    BuildContext context,
    AttendanceProvider provider,
    String studentId,
    String ownerId,
    DateTime date,
    AttendanceRecord? record,
  ) {
    bool isPresent = record?.type == AttendanceType.present;
    bool isAbsent = record?.type == AttendanceType.absent;

    Widget child;
    if (isPresent) {
      child = const Icon(Icons.panorama_fish_eye, color: Colors.blue, size: 20);
    } else if (isAbsent) {
      child = const Text(
        '/',
        style: TextStyle(
          color: Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      child = const SizedBox();
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        provider.toggleStatus(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: ownerId,
          date: date,
        );
      },
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: child),
      ),
    );
  }
}
