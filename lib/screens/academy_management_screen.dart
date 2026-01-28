import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/academy_model.dart';
import '../models/textbook_model.dart';
import '../providers/academy_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/progress_provider.dart';
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

    if (mounted) {
      await context.read<ProgressProvider>().loadOwnerTextbooks(
        currentUser.uid,
      );
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
        title: const Text('기관 등록 및 설정'),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      academyProvider.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _loadAcademies,
                          child: const Text('다시 시도'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: academyProvider.errorMessage!,
                              ),
                            );
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
                return _AcademyCard(academy: academy);
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

          return InkWell(
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              academy.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              academy.type.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateAcademyScreen(academy: academy),
                        ),
                      );
                    },
                    tooltip: '기관 정보 수정',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _handleDelete(context),
                    tooltip: '기관 삭제',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    final academyProvider = context.read<AcademyProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기관 삭제'),
        content: Text(
          '${academy.name}을(를) 삭제하시겠습니까?\n삭제된 정보는 휴지통으로 이동하며, 관리자가 복구할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await academyProvider.deleteAcademy(academy.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${academy.name}이(가) 삭제되었습니다')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(academyProvider.errorMessage ?? '삭제 실패'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
