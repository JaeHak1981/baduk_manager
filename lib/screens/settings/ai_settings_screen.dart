import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/local_storage_service.dart';
import '../../services/ai_service.dart';
import '../../models/education_report_model.dart';
import 'package:url_launcher/url_launcher.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _storageService = LocalStorageService();
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  String? _savedKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  // 공통 에러 다이얼로그
  void _showErrorDialog(String title, dynamic error) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '다음 에러가 발생했습니다:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: error.toString()));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('에러 메시지가 복사되었습니다.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('에러 복사'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  static const String _maskText = '●●●●●●●●●●●●●●●●';

  Future<void> _loadApiKey() async {
    try {
      final key = await _storageService.getAiApiKey();
      if (mounted) {
        setState(() {
          _savedKey = key;
          if (key != null) {
            // 보안강화: 실제 키 대신 마스킹 텍스트를 보여줌
            _apiKeyController.text = _maskText;
          }
        });
      }
    } catch (e) {
      debugPrint('API Key Load Error: $e');
      _showErrorDialog('설정 로드 실패', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();

    // 만약 입력값이 마스킹 텍스트와 같다면 변경사항 없는 것으로 간주
    if (key == _maskText) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('변경된 내용이 없습니다.')));
      return;
    }

    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('API 키를 입력해주세요.')));
      }
      return;
    }

    try {
      await _storageService.saveAiApiKey(key);

      if (mounted) {
        setState(() {
          _savedKey = key;
          _apiKeyController.text = _maskText; // 다시 마스킹
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('API 키가 안전하게 저장되었습니다.')));
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      debugPrint('Save Error: $e');
      _showErrorDialog('저장 실패', e);
    }
  }

  Future<void> _deleteApiKey() async {
    try {
      await _storageService.removeAiApiKey();
      setState(() {
        _savedKey = null;
        _apiKeyController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('API 키가 삭제되었습니다.')));
      }
    } catch (e) {
      _showErrorDialog('삭제 실패', e);
    }
  }

  Future<void> _launchApiKeyUrl() async {
    try {
      final url = Uri.parse('https://aistudio.google.com/app/apikey');
      if (!await launchUrl(url)) {
        throw '브라우저를 열 수 없습니다 ($url)';
      }
    } catch (e) {
      _showErrorDialog('링크 열기 실패', e);
    }
  }

  Future<void> _testConnection() async {
    if (_savedKey == null) return;

    setState(() => _isTesting = true);

    try {
      // 저장된 모델명 가져오기 (없으면 기본값)
      final modelName = await _storageService.getAiModelName();

      // 간단한 테스트용 점수
      final mockScores = AchievementScores(
        focus: 90,
        application: 80,
        accuracy: 85,
        task: 95,
        creativity: 70,
      );

      final aiService = AiService();
      final result = await aiService.generateReportComment(
        apiKey: _savedKey!,
        studentName: '테스트학생',
        textbookName: '바둑입문',
        scores: mockScores,
        attendanceRate: 0.9,
        modelName: modelName,
      );

      if (mounted) {
        if (result != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('연결 성공'),
              content: SingleChildScrollView(child: Text(result)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        } else {
          throw '연결은 성공했으나, AI 응답이 비어있습니다.';
        }
      }
    } catch (e) {
      _showErrorDialog('연결 테스트 실패', e);
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  // 모델명 변경 다이얼로그
  Future<void> _showModelNameDialog() async {
    final currentModel = await _storageService.getAiModelName();
    final controller = TextEditingController(text: currentModel);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 모델명 변경'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사용할 Gemini 모델 이름을 입력하세요.\n(예: gemini-pro, gemini-1.5-flash 등)',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: '모델명',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // 모델 목록 조회 버튼
                if (_savedKey != null) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      // 키보드 내리기
                      FocusScope.of(context).unfocus();

                      final aiService = AiService();
                      // 로딩 표시 (간단히 스낵바나 다이얼로그 타이틀 변경 등으로 처리 가능하나 여기서는 버튼 비활성화는 복잡하므로 즉시 호출)
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('사용 가능한 모델을 조회 중입니다...'),
                          ),
                        );

                        final models = await aiService.listAvailableModels(
                          _savedKey!,
                        );

                        if (!context.mounted) return;

                        if (models.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '조회된 Gemini 모델이 없습니다. API 키 권한을 확인하세요.',
                              ),
                            ),
                          );
                        } else {
                          // 모델 선택 다이얼로그 띄우기 (또는 칩으로 표시)
                          // 여기서는 발견된 첫 번째 모델을 자동 추천하거나 리스트를 보여줌
                          await showDialog(
                            context: context,
                            builder: (c) => SimpleDialog(
                              title: const Text('사용 가능한 모델 선택'),
                              children: models
                                  .map(
                                    (m) => SimpleDialogOption(
                                      onPressed: () {
                                        controller.text = m;
                                        Navigator.pop(c);
                                      },
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('조회 오류: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('내 API 키로 가능한 모델 찾기'),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storageService.saveAiModelName(controller.text.trim());
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '모델명이 "${controller.text.trim()}"(으)로 변경되었습니다.',
                    ),
                  ),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 설정 (Gemini)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest),
            tooltip: '모델명 변경',
            onPressed: _showModelNameDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini API 키 연결',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Google Gemini의 뛰어난 지능을 빌려 학생별 맞춤형 종합 의견을 작성해보세요.',
                        ),
                        SizedBox(height: 16),
                        Text(
                          '• 키는 기기 내부에만 저장됩니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          '• API 사용량에 따라 개인 구글 계정에 비용이 청구될 수 있습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _showModelNameDialog,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('모델명 변경'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _launchApiKeyUrl,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('API 키 발급받기 (Google AI Studio)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key',
                    border: OutlineInputBorder(),
                    helperText: '위 버튼을 눌러 발급받은 키를 복사해서 붙여넣으세요',
                  ),
                  obscureText: true,
                  enableInteractiveSelection: false, // 복사/붙여넣기 메뉴 차단 (보안 강화)
                  onTap: () {
                    // 키가 이미 저장된 상태에서 탭하면 전체 삭제하여 새로 입력하기 편하게 함
                    if (_savedKey != null &&
                        _apiKeyController.text == _maskText) {
                      _apiKeyController.clear();
                    }
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveApiKey,
                        child: const Text('저장하기'),
                      ),
                    ),
                    if (_savedKey != null) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _deleteApiKey,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('삭제'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonal(
                        onPressed: _isTesting ? null : _testConnection,
                        child: _isTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('연결 테스트'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}
