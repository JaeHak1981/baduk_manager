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
    required List<int> volumes,
    List<CommentTemplateModel> templates = const [],
  }) {
    final random = Random();
    List<String> introFragments = [];
    List<String> bodyFragments = [];
    List<String> conclusionFragments = [];

    // 수준 판별 (가장 높은 교재 기준)
    int studentLevel = 1;
    if (textbookNames.isNotEmpty && volumes.isNotEmpty) {
      studentLevel = _determineLevel(textbookNames.first, volumes.first);
    }

    // 0. 인트로 (Intro)
    final introTemplates = templates.where((t) => t.category == '인트로').toList();
    if (introTemplates.isNotEmpty) {
      introFragments.add(
        processTemplate(
          introTemplates[random.nextInt(introTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    }

    // 1. 학습 성취 (수준 및 카테고리 기반)
    final achievementTemplates = templates
        .where(
          (t) =>
              (t.category == '학습 성취' || t.category == '실력') &&
              (t.level == null || t.level == studentLevel),
        )
        .toList();

    if (achievementTemplates.isNotEmpty) {
      bodyFragments.add(
        processTemplate(
          achievementTemplates[random.nextInt(achievementTemplates.length)]
              .content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      // 기본 문구
      if (textbookNames.isNotEmpty) {
        if (studentLevel == 1) {
          bodyFragments.add(
            "${textbookNames.first} 과정을 통해 바둑의 기초 규칙과 착수 금지, 따먹기 등 기본 원리를 차근차근 익히고 있습니다.",
          );
        } else if (studentLevel == 2) {
          bodyFragments.add(
            "${textbookNames.first} 학습을 통해 초급 전술과 수읽기의 기초를 다지며 실전 능력을 키워가고 있습니다.",
          );
        } else {
          bodyFragments.add(
            "${textbookNames.first} 과정을 통해 고급 행마와 사활, 복합적인 수읽기 전략을 깊이 있게 연구하고 있습니다.",
          );
        }
      }
    }

    // 2. 학습 태도 (점수 기반)
    final attitudeTemplates = templates
        .where((t) => t.category == '학습 태도' || t.category == '태도')
        .toList();
    if (attitudeTemplates.isNotEmpty) {
      bodyFragments.add(
        processTemplate(
          attitudeTemplates[random.nextInt(attitudeTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      if (scores.focus >= 85) {
        bodyFragments.add(
          "수업 시간 내내 높은 집중력을 유지하며 어려운 문제도 끝까지 스스로 해결하려는 자세가 돋보입니다.",
        );
      } else {
        bodyFragments.add("매 수업 시간 성실한 태도로 임하며 차근차근 실력을 쌓아가고 있습니다.");
      }
    }

    // 3. 인성/예절
    final etiquetteTemplates = templates
        .where((t) => t.category == '대국 매너' || t.category == '인성')
        .toList();
    if (etiquetteTemplates.isNotEmpty) {
      bodyFragments.add(
        processTemplate(
          etiquetteTemplates[random.nextInt(etiquetteTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      bodyFragments.add("상대방을 존중하는 바른 대국 예절을 갖추고 있어 주변 친구들에게 좋은 본보기가 됩니다.");
    }

    // 4. 격려/비전/성장
    final visionTemplates = templates
        .where(
          (t) =>
              t.category == '격려' || t.category == '비전' || t.category == '성장 변화',
        )
        .toList();
    if (visionTemplates.isNotEmpty) {
      bodyFragments.add(
        processTemplate(
          visionTemplates[random.nextInt(visionTemplates.length)].content,
          studentName,
          textbookNames,
        ),
      );
    } else {
      bodyFragments.add("지금과 같이 즐겁게 정진한다면 앞으로 더욱 큰 성장이 기대됩니다.");
    }

    // 5. 마무리 (Conclusion)
    final conclusionTemplates = templates
        .where((t) => t.category == '마무리')
        .toList();
    if (conclusionTemplates.isNotEmpty) {
      conclusionFragments.add(
        processTemplate(
          conclusionTemplates[random.nextInt(conclusionTemplates.length)]
              .content,
          studentName,
          textbookNames,
        ),
      );
    }

    // 바디 섹션 무작위 셔플링 (순서 변화를 통한 다양성 확보)
    bodyFragments.shuffle(random);

    // 최종 결합: 인트로 + (셔플된) 바디 + 마무리
    List<String> finalFragments = [
      ...introFragments,
      ...bodyFragments,
      ...conclusionFragments,
    ];

    return combineFragments(finalFragments);
  }

  static String processTemplate(
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

  /// 교재 명칭과 권수를 바탕으로 학생의 기술 수준 판별
  static int _determineLevel(String textbookName, int volume) {
    // 수상전, 사활은 1권이라도 중고급(Level 3)으로 간주
    if (textbookName.contains('수상전') || textbookName.contains('사활')) {
      return 3;
    }

    // 일반 교재 기준
    if (volume == 1) {
      return 1; // 입문/기초
    } else if (volume >= 2 && volume <= 5) {
      return 2; // 초급/실전
    } else {
      return 3; // 중고급 (6권 이상)
    }
  }

  /// 학생의 수준 및 권수에 따라 초기 성취도 점수를 동적으로 생성
  static AchievementScores generateInitialScores({
    required String textbookName,
    required int volumeNumber,
  }) {
    final random = Random();
    final level = _determineLevel(textbookName, volumeNumber);

    int baseMin;
    int baseMax;

    if (level == 1) {
      baseMin = 70;
      baseMax = 79;
    } else if (level == 2) {
      baseMin = 80;
      baseMax = 89;
    } else {
      baseMin = 90;
      baseMax = 98;
    }

    // 각 항목별로 베이스 범위 내에서 랜덤하게 생성 (자연스러움을 위해 항목별 개별 랜덤 부여)
    int nextScore() => baseMin + random.nextInt(baseMax - baseMin + 1);

    return AchievementScores(
      focus: nextScore(),
      application: nextScore(),
      accuracy: nextScore(),
      task: nextScore(),
      creativity: nextScore(),
    );
  }
}
