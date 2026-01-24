import 'package:flutter/material.dart';
import '../models/academy_model.dart';
import 'student_list_screen.dart';
import 'textbook_center_screen.dart';

/// 기관 대시보드 화면
class AcademyDashboardScreen extends StatelessWidget {
  final AcademyModel academy;

  const AcademyDashboardScreen({super.key, required this.academy});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(academy.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기관 정보 헤더
            _buildHeader(context),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    title: '학생 관리',
                    icon: Icons.people,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StudentListScreen(academy: academy),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: '교재 관리',
                    icon: Icons.menu_book,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TextbookCenterScreen(academy: academy),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: '출결 관리 (준비중)',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    onTap: () {},
                  ),
                  _buildMenuCard(
                    context,
                    title: '공지 사항 (준비중)',
                    icon: Icons.campaign,
                    color: Colors.purple,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(academy.type.icon, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            academy.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            academy.type.displayName,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
