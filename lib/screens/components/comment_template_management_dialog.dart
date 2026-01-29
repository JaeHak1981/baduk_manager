import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baduk_textbook_manager/utils/excel_utils.dart';
import '../../providers/education_report_provider.dart';
import '../../models/education_report_model.dart';
import 'package:universal_html/html.dart' as html;

class CommentTemplateManagementDialog extends StatelessWidget {
  final String academyId;
  final String ownerId;

  const CommentTemplateManagementDialog({
    super.key,
    required this.academyId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EducationReportProvider>();
    final templates = provider.templates;

    return AlertDialog(
      title: const Text('총평 문구 라이브러리 관리'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            _buildActionButtons(context, provider, templates),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final t = templates[index];
                  return ListTile(
                    title: Text(
                      '[${t.category}]',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(t.content),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    EducationReportProvider provider,
    List<CommentTemplateModel> templates,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => ExcelUtils.exportCommentTemplates(templates),
            icon: const Icon(Icons.download),
            label: const Text('엑셀 내보내기'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _importFromExcel(context, provider),
            icon: const Icon(Icons.upload),
            label: const Text('엑셀 가져오기'),
          ),
        ),
      ],
    );
  }

  void _importFromExcel(
    BuildContext context,
    EducationReportProvider provider,
  ) {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.csv';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final reader = html.FileReader();
      reader.readAsText(files[0]);
      reader.onLoadEnd.listen((e) async {
        final content = reader.result as String;
        final newTemplates = ExcelUtils.parseCommentTemplates(
          content,
          academyId,
          ownerId: ownerId,
        );

        int successCount = 0;
        for (final template in newTemplates) {
          final success = await provider.saveTemplate(template);
          if (success) successCount++;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount개의 문구가 성공적으로 저장되었습니다.')),
          );
        }
      });
    });
  }
}
