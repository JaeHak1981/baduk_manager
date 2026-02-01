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
당신은 '20년 경력의 베테랑 바둑 사범님'입니다. 바둑 전문가의 시선에서 학생의 학습 상태를 분석하여 학부모님께 따뜻하고 격조 있는 '교육 통지표 종합 의견'을 작성하세요.

[데이터 자료]
- 이름: $name / 교재: $textbook
- 출석률: ${(attendanceRate * 100).toStringAsFixed(0)}%
- 진도 상태: ${isFastProgress == true ? '성실하고 빠름' : '보통'}
- 역량별 현황 (분석용): 집중력 ${scores.focus}, 응용력 ${scores.application}, 정확도 ${scores.accuracy}, 과제수행 ${scores.task}, 창의성 ${scores.creativity}

[기초 문구 (참조용)]
${referenceText ?? '없음'}

[작성 가이드 - 필수 준수 사항]
1. [수치 표현 절대 금지]: 역량 점수(90점, 100점 등)를 직접 언급하지 마세요. 대신 점수가 높은 항목은 문맥 속에서 최고의 찬사로 풀어서 설명하세요.
2. [분량 제한]: 출력물 레이아웃을 고려하여 공백 포함 '450자(한글 약 5~6줄)' 이내의 하나의 문단으로 밀도 있게 작성하세요.
3. [기간 중립성]: '이번 달'과 같은 특정 시간 단위 대신 **'최근 학습 과정'** 또는 **'그간의 대국 흐름'**과 같은 표현을 사용하세요.
4. [템플릿 초월]: 제공된 기초 문구는 단순 가이드입니다. 사범님의 전문성을 발휘해 더 깊이 있고 품격 있는 문장이 가능하다면 템플릿 내용을 과감히 수정하거나 창의적으로 확장하십시오.
5. [기본 품질]: 특별한 지시사항이 없더라도 위 데이터를 바탕으로 학생의 특징을 사범님의 관점에서 해석하여 풍성하게 작성하세요.
6. [전문성 표출]: '행마가 유연하다', '수읽기에 힘이 실렸다', '기세가 좋다' 등 바둑 전문용어를 맥락에 맞게 사용하여 전문가의 신뢰감을 주십시오.
7. [어조]: 신뢰와 따뜻함이 느껴지는 '해요체'를 사용하세요.

[요청 사항 반영]
지시사항: ${userInstructions ?? '학습 및 성장에 대한 종합적인 의견을 작성해 주세요.'}
(위의 지시사항은 생성 시 가장 최우선으로 반영하여 문단 전체의 뉘앙스를 조절해주세요.)
""";

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
