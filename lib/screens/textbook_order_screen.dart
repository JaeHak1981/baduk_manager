import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/student_model.dart';
import '../models/textbook_model.dart';
import '../providers/student_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/academy_provider.dart';
import '../providers/order_provider.dart';
import '../providers/temporary_order_provider.dart';
import '../models/order_model.dart';
import '../models/temporary_order_model.dart';

/// 주문 상태타입 (없음, 선택, 연장)
enum OrderType { none, select, extension }

/// 학생별 교재 주문 상태를 관리하기 위한 임시 모델
class _OrderEntry {
  OrderType type;
  TextbookModel? textbook; // select 일 때만 유효함
  int volume;

  _OrderEntry({this.type = OrderType.none, this.textbook, this.volume = 1});
}

class TextbookOrderScreen extends StatefulWidget {
  final AcademyModel academy;

  const TextbookOrderScreen({super.key, required this.academy});

  @override
  State<TextbookOrderScreen> createState() => _TextbookOrderScreenState();
}

class _TextbookOrderScreenState extends State<TextbookOrderScreen> {
  int? _selectedFilterSession;
  String _searchQuery = '';

  final Map<String, _OrderEntry> _orderEntries = {};
  bool _isInitialized = false;

  late TextEditingController _messageController;
  bool _isManualEdit = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _loadInitialData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _loadInitialData() async {
    final studentProvider = context.read<StudentProvider>();
    final progressProvider = context.read<ProgressProvider>();

    await studentProvider.loadStudents(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );
    await progressProvider.loadOwnerTextbooks(widget.academy.ownerId);
    await progressProvider.loadAcademyProgress(
      widget.academy.id,
      ownerId: widget.academy.ownerId,
    );

    // 데이터 로드가 확실히 끝난 후 초기화 호출
    if (mounted) {
      await _initializeEntries();
    }
  }

  Future<void> _initializeEntries() async {
    if (_isInitialized) return;

    final studentProvider = context.read<StudentProvider>();
    final progressProvider = context.read<ProgressProvider>();
    final tempProvider = context.read<TemporaryOrderProvider>();

    // 로딩 중이면 초기화를 미룸
    if (studentProvider.isLoading || progressProvider.isLoading) return;

    final students = studentProvider.students;
    if (students.isEmpty) return;

    // 1. 임시 저장 데이터 로드 시도
    await tempProvider.loadTemporaryOrder(widget.academy.id);
    final tempOrder = tempProvider.tempOrder;

    if (tempOrder != null) {
      debugPrint('ℹ️ [TextbookOrderScreen] 임시 저장 데이터 발견. 복원 중...');
      for (var item in tempOrder.items) {
        _orderEntries[item.studentId] = _OrderEntry(
          type: OrderType.values.firstWhere(
            (e) => e.name == item.type,
            orElse: () => OrderType.none,
          ),
          textbook: item.textbookId != null
              ? progressProvider.allOwnerTextbooks
                    .cast<TextbookModel?>()
                    .firstWhere(
                      (t) => t?.id == item.textbookId,
                      orElse: () => null,
                    )
              : null,
          volume: item.volume,
        );
      }

      // 혹시 임시 저장 데이터에 없는 학생이 있다면 기본값 설정
      for (var student in students) {
        if (!_orderEntries.containsKey(student.id)) {
          final currentP = progressProvider.getProgressForStudent(student.id);
          final hasActiveProgress = currentP.any((p) => !p.isCompleted);
          _orderEntries[student.id] = _OrderEntry(
            type: hasActiveProgress ? OrderType.extension : OrderType.none,
          );
        }
      }

      if (tempOrder.message.isNotEmpty) {
        _messageController.text = tempOrder.message;
        _isManualEdit = true;
      } else {
        _isManualEdit = false;
      }
    } else {
      // 2. 임시 저장 데이터가 없으면 기존 로직대로 초기화
      _isManualEdit = false;
      for (var student in students) {
        final currentP = progressProvider.getProgressForStudent(student.id);
        final hasActiveProgress = currentP.any((p) => !p.isCompleted);

        _orderEntries[student.id] = _OrderEntry(
          type: hasActiveProgress ? OrderType.extension : OrderType.none,
          textbook: null,
          volume: 1,
        );
      }
    }

    setState(() {
      _isInitialized = true;
    });
  }

  List<StudentModel> _getFilteredStudents(
    List<StudentModel> allStudents,
    AcademyModel latestAcademy,
  ) {
    List<StudentModel> filtered = allStudents;
    if (_selectedFilterSession != null) {
      if (_selectedFilterSession == 0) {
        filtered = filtered
            .where((s) => s.session == null || s.session == 0)
            .toList();
      } else {
        filtered = filtered
            .where((s) => s.session == _selectedFilterSession)
            .toList();
      }
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) => s.name.contains(_searchQuery)).toList();
    }
    return filtered;
  }

  /// 진도 반영 (기존 저장 기능)
  Future<void> _handleOrderComplete() async {
    final progressProvider = context.read<ProgressProvider>();
    final orderProvider = context.read<OrderProvider>();

    final entriesToAssign = _orderEntries.entries
        .where(
          (e) => e.value.type == OrderType.select && e.value.textbook != null,
        )
        .toList();

    if (entriesToAssign.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('할당할 교재를 선택한 학생이 없습니다.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var entry in entriesToAssign) {
        final studentId = entry.key;
        final orderEntry = entry.value;

        final currentP = progressProvider.getProgressForStudent(studentId);
        for (var p in currentP) {
          if (!p.isCompleted) {
            await progressProvider.updateVolumeStatus(p.id, studentId, true);
          }
        }
        await progressProvider.assignVolume(
          studentId: studentId,
          academyId: widget.academy.id,
          ownerId: widget.academy.ownerId,
          textbook: orderEntry.textbook!,
          volumeNumber: orderEntry.volume,
        );
      }

      // 주문 이력 저장 (추가된 부분)
      try {
        final Map<String, Map<int, int>> summary = {};
        _orderEntries.forEach((studentId, entry) {
          if (entry.type == OrderType.select && entry.textbook != null) {
            final tName = entry.textbook!.name;
            summary[tName] ??= {};
            summary[tName]![entry.volume] =
                (summary[tName]![entry.volume] ?? 0) + 1;
          }
        });

        int totalAll = 0;
        List<OrderItem> orderItems = [];
        summary.forEach((tName, volumes) {
          orderItems.add(OrderItem(textbookName: tName, volumeCounts: volumes));
          totalAll += volumes.values.fold(0, (sum, c) => sum + c);
        });

        if (totalAll > 0) {
          final order = OrderModel(
            id: '',
            academyId: widget.academy.id,
            ownerId: widget.academy.ownerId,
            orderDate: DateTime.now(),
            items: orderItems,
            totalCount: totalAll,
            message: _messageController.text,
          );
          await orderProvider.saveOrder(order);
        }
      } catch (e) {
        debugPrint('주문 이력 저장 중 오류 (진도 반영은 완료됨): $e');
      }

      if (mounted) {
        // [NEW] 최종 주문 성공 시 임시 저장 데이터 삭제
        await context.read<TemporaryOrderProvider>().deleteTemporaryOrder(
          widget.academy.id,
        );

        Navigator.pop(context); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entriesToAssign.length}명의 진도 반영 및 주문 기록이 완료되었습니다. (임시 저장 초기화됨)',
            ),
          ),
        );
        // 화면을 닫지 않고 유지 (메시지 복사 등을 위해)
        setState(() {
          _isInitialized = false; // 진도 정보를 다시 불러오기 위해 초기화 플래그 리셋
          _orderEntries.clear(); // 현재 선택 목록 초기화
          _isManualEdit = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('할당 중 오류: $e')));
      }
    }
  }

  /// [NEW] 임시 저장 실행
  Future<void> _handleSaveTemporary() async {
    final tempProvider = context.read<TemporaryOrderProvider>();

    final items = _orderEntries.entries.map((e) {
      return TemporaryOrderItem(
        studentId: e.key,
        type: e.value.type.name,
        textbookId: e.value.textbook?.id,
        textbookName: e.value.textbook?.name,
        volume: e.value.volume,
      );
    }).toList();

    final tempOrder = TemporaryOrderModel(
      academyId: widget.academy.id,
      ownerId: widget.academy.ownerId,
      items: items,
      message: _isManualEdit ? _messageController.text : '',
      updatedAt: DateTime.now(),
    );

    final success = await tempProvider.saveTemporaryOrder(tempOrder);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('현재 입력 상태가 임시 저장되었습니다.')));
      } else {
        final errorMsg = tempProvider.errorMessage ?? '알 수 없는 오류가 발생했습니다.';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('임시 저장 실패'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('임시 저장 중 오류가 발생했습니다. 아래 내용을 복사하여 보내주세요.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    errorMsg,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: errorMsg));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('에러 내용이 복사되었습니다.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('에러 복사'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// 저장 전 현재 교재 목록, 월, 학원명을 템플릿 태그로 치환
  String _convertToTemplate(String message, String currentItemsText) {
    String template = message;

    // 1. {items} 치환 (교재 목록)
    if (!template.contains('{items}')) {
      final normalizedItems = currentItemsText.trim();
      final header = '[현재 주문 내역]';
      final itemsWithHeader = '$header\n$normalizedItems';

      if (normalizedItems.isNotEmpty) {
        if (template.contains(itemsWithHeader)) {
          template = template.replaceFirst(itemsWithHeader, '{items}');
        } else if (template.contains(normalizedItems)) {
          template = template.replaceFirst(normalizedItems, '{items}');
        }
      }
    }

    // 2. {month} 치환 (현재 월 자동 태깅)
    // 예: "1월" -> "{month}월"
    // 단순 replaceAll 사용 (11월 등과의 충돌 주의 필요하나, 사용성 편의를 위해 적용)
    final now = DateTime.now();
    final monthStr = '${now.month}월';
    if (template.contains(monthStr)) {
      template = template.replaceAll(monthStr, '{month}월');
    }

    // 3. {academyName} 치환 (학원명 자동 태깅)
    if (template.contains(widget.academy.name)) {
      template = template.replaceAll(widget.academy.name, '{academyName}');
    }

    return template;
  }

  /// 교재 주문 내역 (목록 팝업)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '교재 주문 명계표',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        toolbarHeight: 56,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              final academyProvider = context.read<AcademyProvider>();
              final latestAcademy = academyProvider.academies.firstWhere(
                (a) => a.id == widget.academy.id,
                orElse: () => widget.academy,
              );
              showDialog(
                context: context,
                builder: (context) => _OrderHistoryDialog(
                  academyId: latestAcademy.id,
                  ownerId: latestAcademy.ownerId,
                ),
              );
            },
            child: const Text(
              '교재 주문 내역',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: Consumer3<StudentProvider, ProgressProvider, AcademyProvider>(
        builder:
            (
              context,
              studentProvider,
              progressProvider,
              academyProvider,
              child,
            ) {
              // 최신 기관 정보 가져오기
              final latestAcademy = academyProvider.academies.firstWhere(
                (a) => a.id == widget.academy.id,
                orElse: () => widget.academy,
              );

              // 데이터 로드가 완료되었는데 아직 초기화 전이라면 자동 초기화 시도
              if (!_isInitialized &&
                  !studentProvider.isLoading &&
                  !progressProvider.isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _initializeEntries();
                });
              }

              if (!_isInitialized &&
                  (studentProvider.isLoading || progressProvider.isLoading)) {
                return const Center(child: CircularProgressIndicator());
              }
              final filteredStudents = _getFilteredStudents(
                studentProvider.students,
                latestAcademy,
              );
              List<TextbookModel> textbooks =
                  progressProvider.allOwnerTextbooks;

              // 기관에 설정된 사용 교재가 있으면 필터링
              if (latestAcademy.usingTextbookIds.isNotEmpty) {
                textbooks = textbooks
                    .where((t) => latestAcademy.usingTextbookIds.contains(t.id))
                    .toList();
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  // 현재 상태가 수동 편집이 아닐 경우 메시지 자동 업데이트
                  if (!_isManualEdit) {
                    _messageController.text = _generateDefaultMessage(
                      textbooks,
                      latestAcademy,
                      progressProvider,
                    );
                  }

                  final isWide = constraints.maxWidth > 900;

                  if (isWide) {
                    // 가로 분할 레이아웃 (PC/태블릿)
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 좌측: 학생 리스트 및 필터
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              _buildFilterArea(latestAcademy),
                              _buildTableHeader(),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    100,
                                  ),
                                  itemCount: filteredStudents.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                        height: 1,
                                        color: Colors.black12,
                                      ),
                                  itemBuilder: (context, index) {
                                    return _buildOrderRow(
                                      filteredStudents[index],
                                      textbooks,
                                      progressProvider,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 우측: 대시보드 및 메시지 미리보기 (상황판)
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.grey.shade200),
                              ),
                              color: Colors.grey.shade50,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildAggregationDashboard(
                                    textbooks,
                                    progressProvider,
                                    isWide: true,
                                  ),
                                  const Divider(height: 1),
                                  _buildBottomSummary(
                                    textbooks,
                                    latestAcademy,
                                    isWide: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 세로형 레이아웃 (모바일)
                    return Column(
                      children: [
                        _buildAggregationDashboard(textbooks, progressProvider),
                        _buildFilterArea(latestAcademy),
                        _buildTableHeader(),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filteredStudents.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, color: Colors.black12),
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              return _buildOrderRow(
                                student,
                                textbooks,
                                progressProvider,
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          child: _buildBottomSummary(textbooks, latestAcademy),
                        ),
                      ],
                    );
                  }
                },
              );
            },
      ),
    );
  }

  Widget _buildFilterArea(AcademyModel latestAcademy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '이름 검색',
                prefixIcon: Icon(Icons.search, size: 16),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                isDense: true,
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 8),
          _buildSessionFilterDropdown(latestAcademy),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Expanded(
            flex: 18,
            child: Text(
              '이름/부',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 48,
            child: Text(
              '교재 선택 상태',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              '권',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 26,
            child: Text(
              '기존/현재 교재',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 실시간 집계 대시보드 (Matrix View)
  Widget _buildAggregationDashboard(
    List<TextbookModel> textbooks,
    ProgressProvider progressProvider, {
    bool isWide = false,
  }) {
    if (textbooks.isEmpty) return const SizedBox();

    // 데이터 집계
    Map<String, Map<int, int>> matrix = {};
    int totalCount = 0;

    _orderEntries.forEach((studentId, entry) {
      if (entry.type == OrderType.select && entry.textbook != null) {
        final tName = entry.textbook!.name;
        matrix[tName] ??= {};
        matrix[tName]![entry.volume] = (matrix[tName]![entry.volume] ?? 0) + 1;
        totalCount++;
      } else if (entry.type == OrderType.extension) {
        final currentProgress = progressProvider.getProgressForStudent(
          studentId,
        );
        if (currentProgress.isNotEmpty) {
          final lastP = currentProgress.first;
          final textbook = progressProvider.allOwnerTextbooks.firstWhere(
            (t) => t.id == lastP.textbookId,
            orElse: () => TextbookModel(
              id: '',
              name: '알수없음',
              ownerId: '',
              totalVolumes: 0,
              createdAt: DateTime.now(),
            ),
          );
          if (textbook.id.isNotEmpty) {
            final tName = textbook.name;
            matrix[tName] ??= {};
            matrix[tName]![lastP.volumeNumber] =
                (matrix[tName]![lastP.volumeNumber] ?? 0) + 1;
            totalCount++;
          }
        }
      }
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(bottom: BorderSide(color: Colors.orange.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '■ 실시간 주문 집계 (자동)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(90),
              border: TableBorder.all(color: Colors.orange.shade200),
              children: [
                // 헤더 Row (교재명)
                TableRow(
                  children: [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          '권수/교재',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    ...textbooks.map(
                      (t) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 상세 데이터 Row (권수별)
                for (
                  int v = 1;
                  v <=
                      textbooks.fold(
                        1,
                        (max, t) => t.totalVolumes > max ? t.totalVolumes : max,
                      );
                  v++
                )
                  if (matrix.values.any((m) => m.containsKey(v)))
                    TableRow(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${v}권',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        ...textbooks.map((t) {
                          final count = matrix[t.name]?[v] ?? 0;
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                count > 0 ? '$count' : '-',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: count > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: count > 0 ? Colors.red : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '총 주문 건수: $totalCount권',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateDefaultMessage(
    List<TextbookModel> textbooks,
    AcademyModel latestAcademy,
    ProgressProvider progressProvider,
  ) {
    Map<String, Map<int, int>> summary = {};
    int totalAll = 0;

    _orderEntries.forEach((studentId, entry) {
      if (entry.type == OrderType.select && entry.textbook != null) {
        final tName = entry.textbook!.name;
        summary[tName] ??= {};
        summary[tName]![entry.volume] =
            (summary[tName]![entry.volume] ?? 0) + 1;
        totalAll++;
      } else if (entry.type == OrderType.extension) {
        final currentProgress = progressProvider.getProgressForStudent(
          studentId,
        );
        if (currentProgress.isNotEmpty) {
          final lastP = currentProgress.first;
          final textbook = progressProvider.allOwnerTextbooks.firstWhere(
            (t) => t.id == lastP.textbookId,
            orElse: () => TextbookModel(
              id: '',
              name: '알수없음',
              ownerId: '',
              totalVolumes: 0,
              createdAt: DateTime.now(),
            ),
          );
          if (textbook.id.isNotEmpty) {
            final tName = textbook.name;
            summary[tName] ??= {};
            summary[tName]![lastP.volumeNumber] =
                (summary[tName]![lastP.volumeNumber] ?? 0) + 1;
            totalAll++;
          }
        }
      }
    });

    final itemsText = _getItemsText(summary, totalAll);

    // 2. 템플릿 적용 로직
    String finalMessage = '';
    final now = DateTime.now();

    if (latestAcademy.customMessageTemplate != null &&
        latestAcademy.customMessageTemplate!.isNotEmpty) {
      finalMessage = latestAcademy.customMessageTemplate!;

      // {items} 태그 치환
      if (finalMessage.contains('{items}')) {
        finalMessage = finalMessage.replaceAll('{items}', itemsText);
      } else {
        // 태그가 없으면 현재 메시지 끝에 교재 목록을 강제로 덧붙임
        finalMessage = '$finalMessage\n\n[현재 주문 내역]\n$itemsText';
      }

      // {month} 태그 치환 (자동 월 표기)
      if (finalMessage.contains('{month}')) {
        finalMessage = finalMessage.replaceAll('{month}', now.month.toString());
      }

      // {academyName} 태그 치환
      if (finalMessage.contains('{academyName}')) {
        finalMessage = finalMessage.replaceAll(
          '{academyName}',
          latestAcademy.name,
        );
      }
    } else {
      // 템플릿이 없는 경우 기본 생성
      finalMessage =
          '안녕하세요. [${latestAcademy.name}] ${now.month}월 교재 주문 내역입니다.\n\n[현재 주문 내역]\n$itemsText';
    }

    return finalMessage;
  }

  String _getItemsText(Map<String, Map<int, int>> summary, int totalAll) {
    StringBuffer buffer = StringBuffer();
    summary.forEach((tName, volumes) {
      List<int> sortedV = volumes.keys.toList()..sort();
      String detailed = sortedV.map((v) => '${v}권:${volumes[v]}개').join(', ');
      buffer.writeln('$tName -> $detailed');
    });
    if (totalAll > 0) {
      buffer.write('\n총 $totalAll권 입니다.');
    } else {
      buffer.write('(주문 교재 없음)');
    }
    return buffer.toString();
  }

  Widget _buildOrderRow(
    StudentModel student,
    List<TextbookModel> textbooks,
    ProgressProvider progressProvider,
  ) {
    final entry = _orderEntries[student.id];
    if (entry == null) return const SizedBox();

    final currentProgress = progressProvider.getProgressForStudent(student.id);
    String currentStatus = '없음';
    if (currentProgress.isNotEmpty) {
      final lastP = currentProgress.first;
      final textbook = progressProvider.allOwnerTextbooks.firstWhere(
        (t) => t.id == lastP.textbookId,
        orElse: () => TextbookModel(
          id: '',
          name: '알수',
          ownerId: '',
          totalVolumes: 0,
          createdAt: DateTime.now(),
        ),
      );
      currentStatus = '${textbook.name} ${lastP.volumeNumber}권';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 1. 이름 및 부
          Expanded(
            flex: 18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  student.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  student.session != null && student.session != 0
                      ? '${student.session}부'
                      : '미정',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 2. 3단계 상태 선택 및 교재 선택
          Expanded(
            flex: 48,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStateButton(
                      label: '없음',
                      isSelected: entry.type == OrderType.none,
                      onTap: () => setState(() {
                        entry.type = OrderType.none;
                      }),
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    // 교재가 3개 이하인 경우 '선택' 버튼 대신 교재명을 직접 노출
                    if (textbooks.length <= 3) ...[
                      for (var t in textbooks) ...[
                        _buildStateButton(
                          label: t.name,
                          isSelected:
                              entry.type == OrderType.select &&
                              entry.textbook?.id == t.id,
                          onTap: () => setState(() {
                            entry.type = OrderType.select;
                            entry.textbook = t;
                          }),
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ] else ...[
                      _buildStateButton(
                        label: '선택',
                        isSelected: entry.type == OrderType.select,
                        onTap: () => setState(() {
                          entry.type = OrderType.select;
                        }),
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                    ],
                    _buildStateButton(
                      label: '연장',
                      isSelected: entry.type == OrderType.extension,
                      onTap: () => setState(() {
                        entry.type = OrderType.extension;
                      }),
                      color: Colors.green,
                    ),
                  ],
                ),
                // 교재가 4개 이상일 때만 추가 선택 칩 표시
                if (textbooks.length > 3 && entry.type == OrderType.select) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var t in textbooks)
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: ChoiceChip(
                              label: Text(
                                t.name,
                                style: const TextStyle(fontSize: 10),
                              ),
                              selected: entry.textbook?.id == t.id,
                              onSelected: (sel) {
                                if (sel) {
                                  setState(() {
                                    entry.textbook = t;
                                  });
                                }
                              },
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 3. 권호 선택
          Expanded(
            flex: 8,
            child: (entry.type == OrderType.select && entry.textbook != null)
                ? DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: entry.volume,
                      alignment: Alignment.center,
                      items:
                          List.generate(
                                entry.textbook!.totalVolumes,
                                (i) => i + 1,
                              )
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Center(child: Text('$v')),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => entry.volume = val!),
                    ),
                  )
                : const Center(
                    child: Text('-', style: TextStyle(color: Colors.grey)),
                  ),
          ),
          // 4. 기존 상태
          Expanded(
            flex: 26,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                currentStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionFilterDropdown(AcademyModel latestAcademy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedFilterSession,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('전체')),
            const DropdownMenuItem(value: 0, child: Text('미지정')),
            ...List.generate(
              latestAcademy.totalSessions,
              (i) => i + 1,
            ).map((s) => DropdownMenuItem(value: s, child: Text('$s부'))),
          ],
          onChanged: (val) => setState(() => _selectedFilterSession = val),
        ),
      ),
    );
  }

  /// 메시지 미리보기 영역 UI (편집 가능)
  Widget _buildBottomSummary(
    List<TextbookModel> textbooks,
    AcademyModel latestAcademy, {
    bool isWide = false,
  }) {
    /* // 주문이 없어도 항상 표시하도록 주석 처리
    bool hasOrder = _orderEntries.values.any(
      (e) => e.type == OrderType.select && e.textbook != null,
    );
    if (!hasOrder) return const SizedBox();
    */

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: isWide
            ? null
            : Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '메시지 미리보기 (편집 가능)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              if (_isManualEdit)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isManualEdit = false;
                      _messageController.text = _generateDefaultMessage(
                        textbooks,
                        latestAcademy,
                        context.read<ProgressProvider>(),
                      );
                    });
                  },

                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text(
                    '자동완성으로 복구',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _messageController,
            maxLines: null,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: OutlineInputBorder(),
              fillColor: Colors.white,
              filled: true,
            ),
            onChanged: (val) {
              if (!_isManualEdit) {
                setState(() {
                  _isManualEdit = true;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _messageController.text),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('메시지가 복사되었습니다.')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('복사'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final academyProvider = context.read<AcademyProvider>();

                    // 현재 주문 상태 집계
                    Map<String, Map<int, int>> summary = {};
                    int totalAll = 0;
                    _orderEntries.forEach((studentId, entry) {
                      if (entry.type == OrderType.select &&
                          entry.textbook != null) {
                        final tName = entry.textbook!.name;
                        summary[tName] ??= {};
                        summary[tName]![entry.volume] =
                            (summary[tName]![entry.volume] ?? 0) + 1;
                        totalAll++;
                      }
                    });

                    final itemsText = _getItemsText(summary, totalAll);
                    final templateToSave = _convertToTemplate(
                      _messageController.text,
                      itemsText,
                    );

                    final academyToSave = academyProvider.academies.firstWhere(
                      (a) => a.id == widget.academy.id,
                      orElse: () => widget.academy,
                    );

                    final updatedAcademy = academyToSave.copyWith(
                      customMessageTemplate: templateToSave,
                    );

                    final success = await academyProvider.updateAcademy(
                      updatedAcademy,
                    );

                    if (success) {
                      // 문구 저장 성공 시 자동 업데이트 모드로 전환
                      setState(() {
                        _isManualEdit = false;
                      });
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '기본 메시지로 저장되었습니다.' : '저장 실패'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save, size: 14),
                  label: const Text('문구 저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final academyProvider = context.read<AcademyProvider>();
                    final academyToReset = academyProvider.academies.firstWhere(
                      (a) => a.id == widget.academy.id,
                      orElse: () => widget.academy,
                    );

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('메시지 초기화'),
                        content: const Text(
                          '저장된 맞춤 메시지를 삭제하고\n기본 메시지로 되돌리시겠습니까?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('초기화'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final updatedAcademy = academyToReset.copyWith(
                        customMessageTemplate: '',
                      );
                      await academyProvider.updateAcademy(updatedAcademy);
                      if (mounted) {
                        setState(() {
                          _isManualEdit = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('기본 메시지로 초기화되었습니다.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('초기화'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleSaveTemporary,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('임시 저장'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _handleOrderComplete,
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    '진도 반영 및 주문',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderHistoryDialog extends StatefulWidget {
  final String academyId;
  final String ownerId;

  const _OrderHistoryDialog({required this.academyId, required this.ownerId});

  @override
  State<_OrderHistoryDialog> createState() => _OrderHistoryDialogState();
}

class _OrderHistoryDialogState extends State<_OrderHistoryDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders(
        widget.academyId,
        ownerId: widget.ownerId,
      );
    });
  }

  // 월별 통계 데이터 생성 로직
  Map<String, Map<String, int>> _getMonthlyStats(List<OrderModel> orders) {
    // Key: YYYY-MM, Value: { TextbookName: Count }
    Map<String, Map<String, int>> stats = {};

    for (var order in orders) {
      final monthKey =
          '${order.orderDate.year}-${order.orderDate.month.toString().padLeft(2, '0')}';
      stats[monthKey] ??= {};

      for (var item in order.items) {
        for (var volEntry in item.volumeCounts.entries) {
          stats[monthKey]![item.textbookName] =
              (stats[monthKey]![item.textbookName] ?? 0) + volEntry.value;
        }
      }
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text('교재 주문 내역', style: TextStyle(fontSize: 18)),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: '일별 기록'),
                    Tab(text: '월별 통계'),
                  ],
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.orange,
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 600,
              child: orderProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : orderProvider.errorMessage != null
                  ? _buildErrorView(orderProvider)
                  : TabBarView(
                      children: [
                        // 1. 일별 기록 탭
                        _buildDailyList(orderProvider),
                        // 2. 월별 통계 탭
                        _buildMonthlyStats(
                          _getMonthlyStats(orderProvider.orders),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (orderProvider.orders.isNotEmpty ||
                  orderProvider.errorMessage != null)
                TextButton.icon(
                  onPressed: () => orderProvider.loadOrders(
                    widget.academyId,
                    ownerId: widget.ownerId,
                    force: true,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('새로고침'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView(OrderProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          Text(
            '내역을 불러오지 못했습니다:\n${provider.errorMessage}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadOrders(
              widget.academyId,
              ownerId: widget.ownerId,
              force: true,
            ),
            child: const Text('다시 시도'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: provider.errorMessage ?? ''),
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('에러 메시지가 복사되었습니다.')));
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('에러 내용 복사'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyList(OrderProvider provider) {
    if (provider.orders.isEmpty) {
      return const Center(child: Text('기록된 주문 내역이 없습니다.'));
    }
    return ListView.builder(
      itemCount: provider.orders.length,
      itemBuilder: (context, index) {
        final order = provider.orders[index];
        return ExpansionTile(
          title: Text(
            '${order.orderDate.year}년 ${order.orderDate.month}월 ${order.orderDate.day}일 주문',
          ),
          subtitle: Text('총 ${order.totalCount}권'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _showDeleteConfirm(context, provider, order.id),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var item in order.items)
                    Text(
                      '${item.textbookName}: ${item.volumeCounts.entries.map((e) => "${e.key}권(${e.value})").join(", ")}',
                    ),
                  const Divider(),
                  const Text(
                    '작성된 메시지:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade100,
                    child: SelectableText(
                      order.message,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('메시지가 복사되었습니다.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('이 메시지 복사'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyStats(Map<String, Map<String, int>> stats) {
    if (stats.isEmpty) {
      return const Center(child: Text('통계 데이터가 없습니다.'));
    }

    final sortedMonths = stats.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final monthKey = sortedMonths[index];
        final monthData = stats[monthKey]!;
        final totalInMonth = monthData.values.fold(0, (sum, val) => sum + val);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            title: Text(
              '${monthKey.split('-')[0]}년 ${monthKey.split('-')[1]}월 합계',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('총 $totalInMonth 권 주문됨'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    for (var entry in monthData.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text(
                              '${entry.value}권',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    OrderProvider provider,
    String orderId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 이력 삭제'),
        content: const Text('이 주문 기록을 삭제하시겠습니까?\n(진도 할당은 취소되지 않으며 이력만 삭제됩니다.)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteOrder(
                orderId,
                widget.academyId,
                ownerId: widget.ownerId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '삭제되었습니다.' : '삭제 실패')),
                );
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
