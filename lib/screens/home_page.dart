import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/academy_provider.dart';
import '../models/user_model.dart';
import '../models/academy_model.dart';
import 'academy_management_screen.dart';
import 'admin_recovery_screen.dart';
import 'student_list_screen.dart';
import 'textbook_center_screen.dart';
import 'textbook_order_screen.dart';
import 'attendance_tab_screen.dart';
import 'education_report_screen.dart';
import '../providers/progress_provider.dart';
import '../models/textbook_model.dart';
import 'components/enrollment_statistics_dialog.dart';
import 'components/download_dialog.dart';
import '../providers/system_provider.dart';
import 'settings/ai_settings_screen.dart';

/// 홈 화면
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      context.read<SystemProvider>().checkUpdate(); // 업데이트 체크 추가
    });
  }

  void _loadInitialData() {
    final authProvider = context.read<AuthProvider>();
    final academyProvider = context.read<AcademyProvider>();
    final progressProvider = context.read<ProgressProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      if (user.isDeveloper) {
        academyProvider.loadAllAcademies();
      } else {
        academyProvider.loadAcademiesByOwner(user.uid);
      }
      // 교재 목록 로드
      progressProvider.loadOwnerTextbooks(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final academyProvider = context.watch<AcademyProvider>();
    final progressProvider = context.watch<ProgressProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('바둑 학원 관리 시스템'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '앱 설치 파일 다운로드',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DownloadDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI 설정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AiSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await authProvider.signOut();
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('사용자 정보를 불러올 수 없습니다.'))
          : Column(
              children: [
                // 사용자 요약 정보 (간소화)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getRoleText(user.role),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 좌측: 내 기관 목록
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '내 기관 목록',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  // 상단 관리 아이콘 제거 (하단 버튼으로 이동)
                                ],
                              ),
                            ),
                            Expanded(
                              child: academyProvider.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : academyProvider.errorMessage != null
                                  ? _buildErrorState(
                                      academyProvider.errorMessage!,
                                    )
                                  : academyProvider.academies.isEmpty
                                  ? _buildEmptyState()
                                  : RefreshIndicator(
                                      onRefresh: () async => _loadInitialData(),
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        itemCount:
                                            academyProvider.academies.length,
                                        itemBuilder: (context, index) {
                                          final academy =
                                              academyProvider.academies[index];
                                          return _AcademySummaryCard(
                                            academy: academy,
                                          );
                                        },
                                      ),
                                    ),
                            ),
                            // 하단에 기관 관리 버튼 배치 (교재 관리와 대칭)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AcademyManagementScreen(),
                                        ),
                                      ).then((_) => _loadInitialData());
                                    },
                                    icon: const Icon(Icons.settings),
                                    label: const Text('기관 등록 및 설정'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                      minimumSize: const Size.fromHeight(45),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  if (user.isDeveloper) ...[
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminRecoveryScreen(),
                                          ),
                                        ).then((_) => _loadInitialData());
                                      },
                                      icon: const Icon(
                                        Icons.restore_from_trash,
                                      ),
                                      label: const Text('데이터 복구 (관리자)'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade50,
                                        foregroundColor: Colors.red,
                                        minimumSize: const Size.fromHeight(45),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const VerticalDivider(width: 1),

                      // 우측: 내 교재 목록
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '내 교재 목록',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  // 기존 상단 아이콘 버튼 제거
                                ],
                              ),
                            ),
                            Expanded(
                              child: progressProvider.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : progressProvider.errorMessage != null
                                  ? _buildErrorState(
                                      progressProvider.errorMessage!,
                                    )
                                  : progressProvider.allOwnerTextbooks.isEmpty
                                  ? _buildTextbookEmptyState()
                                  : RefreshIndicator(
                                      onRefresh: () async => _loadInitialData(),
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        itemCount: progressProvider
                                            .allOwnerTextbooks
                                            .length,
                                        itemBuilder: (context, index) {
                                          final textbook = progressProvider
                                              .allOwnerTextbooks[index];
                                          return _TextbookSummaryCard(
                                            textbook: textbook,
                                            userUid: user.uid,
                                          );
                                        },
                                      ),
                                    ),
                            ),
                            // 하단에 교재 관리 버튼 배치
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TextbookCenterScreen(
                                            academy: AcademyModel(
                                              id: 'global',
                                              name: '내 교재 관리',
                                              type: AcademyType.academy,
                                              ownerId: user.uid,
                                              createdAt: DateTime.now(),
                                            ),
                                          ),
                                    ),
                                  ).then((_) => _loadInitialData());
                                },
                                icon: const Icon(Icons.library_books),
                                label: const Text('교재 관리 및 추가'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  minimumSize: const Size.fromHeight(45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
  }

  Widget _buildTextbookEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('등록된 교재가 없습니다.'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadInitialData,
                  child: const Text('다시 시도'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('에러 메시지가 복사되었습니다')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('등록된 기관이 없습니다.'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcademyManagementScreen(),
                ),
              );
            },
            child: const Text('기관 등록하기'),
          ),
        ],
      ),
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.developer:
        return '개발자';
      case UserRole.owner:
        return '학원 소유자';
      case UserRole.teacher:
        return '선생님';
    }
  }
}

/// 홈 화면용 교재 요약 카드
class _TextbookSummaryCard extends StatelessWidget {
  final dynamic textbook; // TextbookModel
  final String userUid;

  const _TextbookSummaryCard({required this.textbook, required this.userUid});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.menu_book,
          color: textbook.ownerId == 'common' ? Colors.orange : Colors.blue,
          size: 20,
        ),
        title: Text(
          textbook.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '총 ${textbook.totalVolumes}권',
          style: const TextStyle(fontSize: 11),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TextbookCenterScreen(
                academy: AcademyModel(
                  id: 'global',
                  name: '내 교재 관리',
                  type: AcademyType.academy,
                  ownerId: userUid,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 홈 화면용 기관 요약 카드
class _AcademySummaryCard extends StatelessWidget {
  final AcademyModel academy;

  const _AcademySummaryCard({required this.academy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Consumer<ProgressProvider>(
        builder: (context, progressProvider, child) {
          final textbooks = progressProvider.allOwnerTextbooks;
          String usingTextbooksStr = '';

          if (academy.usingTextbookIds.isNotEmpty) {
            final names = academy.usingTextbookIds.map((id) {
              final t = textbooks.firstWhere(
                (element) => element.id == id,
                orElse: () => TextbookModel(
                  id: id,
                  name: '알수없음',
                  ownerId: '',
                  totalVolumes: 0,
                  createdAt: DateTime.now(),
                ),
              );
              return t.name;
            }).toList();
            usingTextbooksStr = names.join(', ');
          }

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    academy.type.icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      academy.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (academy.lessonDays.isNotEmpty)
                      Text(
                        academy.lessonDays
                            .map((d) {
                              switch (d) {
                                case 1:
                                  return '월요일';
                                case 2:
                                  return '화요일';
                                case 3:
                                  return '수요일';
                                case 4:
                                  return '목요일';
                                case 5:
                                  return '금요일';
                                case 6:
                                  return '토요일';
                                case 7:
                                  return '일요일';
                                default:
                                  return '';
                              }
                            })
                            .join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (usingTextbooksStr.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          usingTextbooksStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(academy.type.displayName),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentListScreen(academy: academy),
                    ),
                  );
                },
              ),
              // 버튼들 하단 배치
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceTabScreen(
                              academy: academy,
                              initialIndex: 0,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 16,
                      ),
                      label: const Text('출석부'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => EnrollmentStatisticsDialog(
                            academy: academy,
                            initialYear: DateTime.now().year,
                            initialMonth: DateTime.now().month,
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart, size: 16),
                      label: const Text('인원 통계'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.green.shade300),
                        foregroundColor: Colors.green.shade700,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TextbookOrderScreen(academy: academy),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                      label: const Text('교재 주문'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.orange.shade300),
                        foregroundColor: Colors.orange.shade700,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EducationReportScreen(academy: academy),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_outlined, size: 16),
                      label: const Text('통지표'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.purple.shade300),
                        foregroundColor: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
