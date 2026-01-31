import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/education_report_model.dart';

class AiService {
  /// Gemini 모델을 사용하여 종합 의견 생성
  /// [apiKey]: 사용자 API 키
  /// [studentName]: 학생 이름
  /// [textbookName]: 현재 진행 중인 교재 이름
  /// [scores]: 성취도 점수 객체
  /// [attendanceRate]: 출석률 (0.0 ~ 1.0)
  /// [modelName]: 사용할 모델 이름 (기본값: gemini-1.5-flash)
  Future<String?> generateReportComment({
    required String apiKey,
    required String studentName,
    required String textbookName,
    required AchievementScores scores,
    required double attendanceRate,
    String? recentTopic,
    String? userInstructions, // 추가 지시사항 파라미터 추가
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
        userInstructions, // 지시사항 전달
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text;
      } else {
        // 텍스트가 없으면 차단 여부 등 확인
        if (response.promptFeedback?.blockReason != null) {
          throw 'AI 응답이 차단되었습니다. 사유: ${response.promptFeedback?.blockReason}';
        }
        throw 'AI가 빈 응답을 보냈습니다.';
      }
    } catch (e) {
      debugPrint('Gemini API Error: $e');
      rethrow; // 에러를 상위로 전파하여 UI에서 확인 가능하게 함
    }
  }

  String _buildPrompt(
    String name,
    String textbook,
    AchievementScores scores,
    double attendanceRate,
    String? recentTopic,
    String? userInstructions, // 파라미터 추가
  ) {
    String basePrompt =
        """
다음 정보를 바탕으로 바둑 학원 학생의 '교육 통지표 종합 의견'을 3~4문장으로 작성해줘.
학부모님에게 보내는 정중하고 격려가 담긴 어조로(해요체) 작성해줘.

학생 이름: $name
학습 교재: $textbook
출석률: ${(attendanceRate * 100).toStringAsFixed(0)}%

[성취도 평가 (100점 만점 기준)]
- 집중력: ${scores.focus}
- 응용력: ${scores.application}
- 정확도: ${scores.accuracy}
- 과제수행: ${scores.task}
- 창의성: ${scores.creativity}

[작성 가이드]
1. 먼저 학생의 강력한 장점(점수가 높은 항목)을 구체적으로 칭찬해줘.
2. 부족한 부분이나 더 발전이 필요한 부분이 있다면 격려와 함께 언급해줘.
3. 가정에서 도와주면 좋을 점이 있다면 간단히 덧붙여줘.
4. $textbook 과정을 통해 바둑 실력이 어떻게 성장하고 있는지 설명해줘.
""";

    // 지시사항이 있을 경우 최하단에 배치하여 강조 (Recent Bias 활용)
    if (userInstructions != null && userInstructions.trim().isNotEmpty) {
      basePrompt +=
          """

[★선생님의 특별 요청 사항★]
지시사항: $userInstructions
(위 지시사항은 생성 시 가장 최우선으로 반영되어야 할 명령입니다.)
""";
    }

    return basePrompt;
  }

  /// 사용 가능한 모델 목록 조회 (디버깅용)
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
              .where((name) => name.contains('gemini')) // gemini 모델만 필터링
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
