import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academy_model.dart';
import '../services/academy_service.dart';

class AdminRecoveryScreen extends StatefulWidget {
  const AdminRecoveryScreen({super.key});

  @override
  State<AdminRecoveryScreen> createState() => _AdminRecoveryScreenState();
}

class _AdminRecoveryScreenState extends State<AdminRecoveryScreen> {
  final AcademyService _academyService = AcademyService();
  final TextEditingController _searchController = TextEditingController();

  List<AcademyModel> _deletedAcademies = [];
  bool _isLoading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadDeletedAcademies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedAcademies() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = _searchController.text.trim();
      final academies = await _academyService.getDeletedAcademies(
        ownerId: ownerId.isNotEmpty ? ownerId : null,
        date: _selectedDate,
      );
      setState(() => _deletedAcademies = academies);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로드 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreAcademy(AcademyModel academy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기관 복구'),
        content: Text("'${academy.name}' 기관을 복구하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복구'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _academyService.restoreAcademy(academy.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('성공적으로 복구되었습니다.')));
        _loadDeletedAcademies(); // 목록 갱신
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('복구 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadDeletedAcademies();
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
    _loadDeletedAcademies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통 (관리자용)'),
        backgroundColor: Colors.red.shade50,
      ),
      body: Column(
        children: [
          // Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '원장님 ID 검색',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        onSubmitted: (_) => _loadDeletedAcademies(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _loadDeletedAcademies,
                      icon: const Icon(Icons.refresh),
                      tooltip: '검색',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _selectedDate == null
                            ? '날짜 선택'
                            : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                      ),
                    ),
                    if (_selectedDate != null)
                      IconButton(
                        onPressed: _clearDate,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '날짜 초기화',
                      ),
                    const Spacer(),
                    Text(
                      '총 ${_deletedAcademies.length}개',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _deletedAcademies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '삭제된 데이터가 없습니다.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _deletedAcademies.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final academy = _deletedAcademies[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade50,
                          child: const Icon(Icons.school, color: Colors.red),
                        ),
                        title: Text(
                          academy.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${academy.id}'),
                            Text('Owner: ${academy.ownerId}'),
                            if (academy.deletedAt != null)
                              Text(
                                '삭제: ${DateFormat('yyyy-MM-dd HH:mm').format(academy.deletedAt!)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: FilledButton.icon(
                          onPressed: () => _restoreAcademy(academy),
                          icon: const Icon(Icons.restore),
                          label: const Text('복구'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
