import 'dart:math';
import '../models/education_report_model.dart';

class ReportCommentUtils {
  /// 여러 문장 조각을 자연스럽게 하나의 문단으로 결합
  static String combineFragments(List<String> fragments) {
    if (fragments.isEmpty) return "";

    // 빈 문자열 제거 및 공백 정리
    final cleanFragments = fragments
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    if (cleanFragments.isEmpty) return "";

    StringBuffer sb = StringBuffer();

    for (int i = 0; i < cleanFragments.length; i++) {
      String sentence = cleanFragments[i];

      // 마침표가 없으면 추가
      if (!sentence.endsWith('.') &&
          !sentence.endsWith('!') &&
          !sentence.endsWith('?')) {
        sentence += '.';
      }

      // 첫 문장이 아닌 경우 연결어나 조사를 고려한 결합 (심화 로직은 추후 확장 가능)
      if (i > 0) {
        sb.write(" ");
        // 특정 상황에서 주어 생략이나 접속사 추가를 할 수 있음
        // 여기서는 간단히 공백으로 연결
      }

      sb.write(sentence);
    }

    return sb.toString();
  }

  /// 학생의 데이터(급수, 점수, 교재 등)를 기반으로 자동 총평 생성
  static String autoGenerateComment({
    required String studentName,
    required AchievementScores scores,
    required List<String> textbookNames,
    List<CommentTemplateModel> templates = const [],
  }) {
    final random = Random();
    List<String> selectedFragments = [];

    // 1. 학습 성취 (교재 기반)
    final achievementTemplates = templates
        .where((t) => t.category == '학습 성취' || t.category == '실력')
        .toList();
    if (achievementTemplates.isNotEmpty) {
      selectedFragments.add(
        _processTemplate(
          achievementTemplates[random.nextInt(achievementTemplates.length)]
              .content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      // 기본 문구 (데이터가 없을 때)
      if (textbookNames.isNotEmpty) {
        selectedFragments.add(
          "${textbookNames.first} 과정을 통해 바둑의 핵심 원리를 체계적으로 학습하고 있습니다.",
        );
      }
    }

    // 2. 학습 태도 (점수 기반 - 집중력이나 과제수행도 참고)
    final attitudeTemplates = templates
        .where((t) => t.category == '학습 태도' || t.category == '태도')
        .toList();
    if (attitudeTemplates.isNotEmpty) {
      // 점수가 높은 경우 긍정 문구 우선 등 로직 추가 가능
      selectedFragments.add(
        _processTemplate(
          attitudeTemplates[random.nextInt(attitudeTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      if (scores.focus >= 85) {
        selectedFragments.add(
          "수업 시간 내내 높은 집중력을 유지하며 어려운 문제도 끝까지 스스로 해결하려는 자세가 돋보입니다.",
        );
      } else {
        selectedFragments.add("매 수업 시간 성실한 태도로 임하며 차근차근 실력을 쌓아가고 있습니다.");
      }
    }

    // 3. 인성/예절
    final etiquetteTemplates = templates
        .where((t) => t.category == '대국 매너' || t.category == '인성')
        .toList();
    if (etiquetteTemplates.isNotEmpty) {
      selectedFragments.add(
        _processTemplate(
          etiquetteTemplates[random.nextInt(etiquetteTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      selectedFragments.add("상대방을 존중하는 바른 대국 예절을 갖추고 있어 주변 친구들에게 좋은 본보기가 됩니다.");
    }

    // 4. 격려/비전
    final visionTemplates = templates
        .where((t) => t.category == '격려' || t.category == '비전')
        .toList();
    if (visionTemplates.isNotEmpty) {
      selectedFragments.add(
        _processTemplate(
          visionTemplates[random.nextInt(visionTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      selectedFragments.add("지금과 같이 즐겁게 정진한다면 앞으로 더욱 큰 성장이 기대됩니다.");
    }

    return combineFragments(selectedFragments);
  }

  static String _processTemplate(
    String content,
    String name,
    List<String> textbooks,
  ) {
    String result = content.replaceAll('{{name}}', name);
    if (textbooks.isNotEmpty) {
      result = result.replaceAll('{{textbook}}', textbooks.first);
    } else {
      result = result.replaceAll('{{textbook}}', '배우고 있는 교재');
    }
    return result;
  }
}
