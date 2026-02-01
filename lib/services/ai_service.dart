import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/education_report_model.dart';

class AiService {
  /// Gemini 모델을 사용하여 종합 의견 생성
  Future<String?> generateReportComment({
    required String apiKey,
    required String studentName,
    required String textbookName,
    required AchievementScores scores,
    required double attendanceRate,
    String? recentTopic,
    String? userInstructions,
    String? referenceText, // TAG: 참고용 템플릿 문구
    bool? isFastProgress, // 데이터 상세화: 빠른 진도 여부
    String modelName = 'gemini-1.5-flash',
  }) async {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );

      final prompt = _buildPrompt(
        studentName,
        textbookName,
        scores,
        attendanceRate,
        recentTopic,
        userInstructions,
        referenceText,
        isFastProgress,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text;
      } else {
        if (response.promptFeedback?.blockReason != null) {
          throw 'AI 응답이 차단되었습니다. 사유: ${response.promptFeedback?.blockReason}';
        }
        throw 'AI가 빈 응답을 보냈습니다.';
      }
    } catch (e) {
      debugPrint('Gemini API Error: $e');
      rethrow;
    }
  }

  String _buildPrompt(
    String name,
    String textbook,
    AchievementScores scores,
    double attendanceRate,
    String? recentTopic,
    String? userInstructions,
    String? referenceText,
    bool? isFastProgress,
  ) {
    String basePrompt =
        """
당신은 '20년 경력의 베테랑 바둑 사범님'입니다. 바둑 교육 전문가의 관점에서 학생의 학습 상태를 분석하고, 학부모님께 따뜻하면서도 전문적인 '교육 통지표 종합 의견'을 작성해야 합니다.

[학생 정보]
- 이름: $name
- 현재 교재: $textbook
- 출석률: ${(attendanceRate * 100).toStringAsFixed(0)}%
- 진도 상태: ${isFastProgress == true ? '매우 빠름 (성실함)' : '보통'}

[성취도 점수 (100점 만점)]
- 집중력: ${scores.focus}, 응용력: ${scores.application}, 정확도: ${scores.accuracy}, 과제수행: ${scores.task}, 창의성: ${scores.creativity}

[참고용 기초 문구 (TAG)]
${referenceText ?? '없음'}

[작성 가이드 - 필수 준수]
1. [페르소나]: '해요체'를 사용하되, 가볍지 않고 전문가의 신뢰감이 느껴지는 격조 있는 어조를 유지하세요.
2. [TAG 전략]: 위의 '참고용 기초 문구'를 단순히 나열하지 말고, 이를 배경 지식으로 삼아 학생의 구체적인 점수와 진도 상태를 결합하여 훨씬 더 풍성하고 전문적인 문단으로 확장(Expand)해주세요. 
3. [구성]: 
   - 도입: 이번 달 전반적인 학습 태도와 정서적 성장 언급
   - 본론: 성취도 점수가 높은 항목(장점)을 바둑 전문 용어를 섞어 구체적으로 칭찬 (예: 행마가 조밀해짐, 수읽기가 깊어짐, 끝내기 능력이 향상됨 등)
   - 결론: 앞으로의 학습 비전 제시 및 따뜻한 격려
4. [분량]: 학부모님이 정성을 느낄 수 있도록 최소 5~6문장 내외의 하나의 완성된 문단으로 작성하세요.
""";

    if (userInstructions != null && userInstructions.trim().isNotEmpty) {
      basePrompt +=
          """

[★학부모/선생님 특별 요청 사항★]
지시사항: $userInstructions
(위의 지시사항은 생성 시 가장 최우선으로 반영하여 문단 전체의 뉘앙스를 조절해주세요.)
""";
    }

    return basePrompt;
  }

  Future<List<String>> listAvailableModels(String apiKey) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('models')) {
          final models = data['models'] as List;
          return models
              .map((m) => m['name'].toString().replaceFirst('models/', ''))
              .where((name) => name.contains('gemini'))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Model List Error: $e');
      return [];
    }
  }
}
