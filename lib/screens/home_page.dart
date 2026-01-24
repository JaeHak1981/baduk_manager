import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/academy_provider.dart';
import '../models/user_model.dart';
import '../models/academy_model.dart';
import 'academy_management_screen.dart';

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
    final user = authProvider.currentUser;

    if (user != null) {
      if (user.isDeveloper) {
        academyProvider.loadAllAcademies();
      } else {
        academyProvider.loadAcademiesByOwner(user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final academyProvider = context.watch<AcademyProvider>();
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

                // 내 기관 목록 헤더
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '내 기관 목록',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AcademyManagementScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('관리'),
                      ),
                    ],
                  ),
                ),

                // 기관 목록
                Expanded(
                  child: academyProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : academyProvider.academies.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: academyProvider.academies.length,
                          itemBuilder: (context, index) {
                            final academy = academyProvider.academies[index];
                            return _AcademySummaryCard(academy: academy);
                          },
                        ),
                ),
              ],
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
        title: Text(
          academy.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(academy.type.displayName),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // TODO: 기관 대시보드로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${academy.name} 대시보드로 이동합니다 (준비 중)')),
          );
        },
      ),
    );
  }
}
