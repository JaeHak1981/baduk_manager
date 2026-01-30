import 'package:flutter/material.dart';
import '../../models/education_report_model.dart';

class CommentGridPicker extends StatefulWidget {
  final List<CommentTemplateModel> templates;
  final Function(String) onSelected;
  final bool multiSelect; // 다중 선택 모드

  const CommentGridPicker({
    super.key,
    required this.templates,
    required this.onSelected,
    this.multiSelect = false,
  });

  @override
  State<CommentGridPicker> createState() => _CommentGridPickerState();
}

class _CommentGridPickerState extends State<CommentGridPicker> {
  String? _selectedCategory;
  late List<String> _categories;
  final Set<String> _selectedTemplateIds = {}; // 다중 선택된 템플릿 ID들

  @override
  void initState() {
    super.initState();
    _categories = widget.templates.map((t) => t.category).toSet().toList();
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }
  }

  String _combineSelectedComments() {
    final selectedTemplates = widget.templates
        .where((t) => _selectedTemplateIds.contains(t.id))
        .toList();

    if (selectedTemplates.isEmpty) return '';
    if (selectedTemplates.length == 1) return selectedTemplates.first.content;

    // 카테고리별로 그룹화
    final Map<String, List<String>> groupedByCategory = {};
    for (final template in selectedTemplates) {
      groupedByCategory.putIfAbsent(template.category, () => []);
      groupedByCategory[template.category]!.add(template.content);
    }

    // 문장 조합
    final List<String> combinedSentences = [];
    String? previousCategory;

    for (final template in selectedTemplates) {
      final sentence = template.content;

      // 카테고리가 바뀌면 전환 표현 추가
      if (previousCategory != null && previousCategory != template.category) {
        // 마지막 문장에 전환어 추가
        if (combinedSentences.isNotEmpty) {
          final transitions = ['또한', '아울러', '특히'];
          final transition =
              transitions[combinedSentences.length % transitions.length];
          combinedSentences.add('$transition $sentence');
        } else {
          combinedSentences.add(sentence);
        }
      } else {
        combinedSentences.add(sentence);
      }

      previousCategory = template.category;
    }

    return combinedSentences.join(' ');
  }

  void _showPreview() {
    final combined = _combineSelectedComments();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('미리보기'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text(
              combined,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // 미리보기 닫기
              widget.onSelected(combined);
              Navigator.pop(context); // CommentGridPicker 닫기
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTemplates = widget.templates
        .where((t) => t.category == _selectedCategory)
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.multiSelect ? '문구 다중 선택' : '추천 문구 선택',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (widget.multiSelect)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '여러 문구를 선택하면 자연스럽게 연결됩니다',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 16),
          // 카테고리 칩 리스트
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // 문구 그리드
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: filteredTemplates.length,
              itemBuilder: (context, index) {
                final template = filteredTemplates[index];
                final isSelected = _selectedTemplateIds.contains(template.id);

                return InkWell(
                  onTap: () {
                    if (widget.multiSelect) {
                      setState(() {
                        if (isSelected) {
                          _selectedTemplateIds.remove(template.id);
                        } else {
                          _selectedTemplateIds.add(template.id);
                        }
                      });
                    } else {
                      widget.onSelected(template.content);
                      Navigator.pop(context);
                    }
                  },
                  child: Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? Colors.indigo.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.indigo
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              template.content,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        if (widget.multiSelect && isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.indigo,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 다중 선택 모드일 때 하단 액션 바
          if (widget.multiSelect) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedTemplateIds.length}개 선택됨',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (_selectedTemplateIds.isNotEmpty)
                        TextButton.icon(
                          onPressed: _showPreview,
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('미리보기'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectedTemplateIds.isEmpty
                            ? null
                            : () {
                                final combined = _combineSelectedComments();
                                widget.onSelected(combined);
                                Navigator.pop(context);
                              },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('적용'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
