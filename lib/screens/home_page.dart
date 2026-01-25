import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/academy_provider.dart';
import '../models/user_model.dart';
import '../models/academy_model.dart';
import 'academy_management_screen.dart';
import 'student_list_screen.dart';
import 'textbook_center_screen.dart';
import 'attendance_screen.dart';
import '../providers/progress_provider.dart';

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
            icon: const Icon(Icons.settings),
            tooltip: '기관 관리',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AcademyManagementScreen(),
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
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AcademyManagementScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.settings),
                                label: const Text('기관 관리 및 등록'),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          children: [
            Text(
              academy.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          ],
        ),
        subtitle: Text(academy.type.displayName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.assignment_turned_in_outlined,
                color: Colors.blue,
              ),
              tooltip: '출석부 바로가기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(academy: academy),
                  ),
                );
              },
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentListScreen(academy: academy),
            ),
          );
        },
      ),
    );
  }
}
