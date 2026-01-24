import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../providers/academy_provider.dart';
import '../providers/auth_provider.dart';
import 'create_academy_screen.dart';

/// 기관 관리 화면 (등록 및 삭제)
class AcademyManagementScreen extends StatefulWidget {
  const AcademyManagementScreen({super.key});

  @override
  State<AcademyManagementScreen> createState() =>
      _AcademyManagementScreenState();
}

class _AcademyManagementScreenState extends State<AcademyManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAcademies();
    });
  }

  Future<void> _loadAcademies() async {
    final authProvider = context.read<AuthProvider>();
    final academyProvider = context.read<AcademyProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    // 개발자는 모든 기관 조회, 일반 사용자는 자신의 기관만 조회
    if (currentUser.isDeveloper) {
      await academyProvider.loadAllAcademies();
    } else {
      await academyProvider.loadAcademiesByOwner(currentUser.uid);
    }
  }

  Future<void> _navigateToCreateAcademy() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateAcademyScreen()),
    );

    if (result == true) {
      _loadAcademies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기관 관리 및 등록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: '홈으로 이동',
          ),
        ],
      ),
      body: Consumer<AcademyProvider>(
        builder: (context, academyProvider, child) {
          if (academyProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (academyProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    academyProvider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAcademies,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (academyProvider.academies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 기관이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _navigateToCreateAcademy,
                    icon: const Icon(Icons.add),
                    label: const Text('기관 등록하기'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAcademies,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: academyProvider.academies.length,
              itemBuilder: (context, index) {
                final academy = academyProvider.academies[index];
                return Dismissible(
                  key: Key(academy.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('기관 삭제'),
                        content: Text('${academy.name}을(를) 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    final success = await academyProvider.deleteAcademy(
                      academy.id,
                    );
                    if (context.mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${academy.name}이(가) 삭제되었습니다'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              academyProvider.errorMessage ?? '삭제 실패',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        _loadAcademies(); // 실패 시 목록 새로고침
                      }
                    }
                  },
                  child: _AcademyCard(academy: academy),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateAcademy,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// 기관 카드 위젯
class _AcademyCard extends StatelessWidget {
  final AcademyModel academy;

  const _AcademyCard({required this.academy});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: 기관 상세 화면으로 이동
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  academy.type.icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      academy.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      academy.type.displayName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
