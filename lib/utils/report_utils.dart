import 'dart:math';
import '../models/education_report_model.dart';

class ReportUtils {
  /// 교재 권수 및 난이도에 따른 베이스라인 점수 산출
  static AchievementScores calculateBaselineScores({
    required int maxVolume, // 해당 기간 학습한 교재 중 최고 권수
    required double attendanceRate, // 출석률 (0.0 ~ 1.0)
    required bool isFastProgress, // 진도 속도가 빠른지 여부
  }) {
    // 기본 베이스라인 (교재 권수가 높을수록 기본 역량이 높다고 가정)
    int base = 75;
    if (maxVolume >= 8)
      base = 85;
    else if (maxVolume >= 4)
      base = 80;

    // 항목별 특화 가중치 (권수에 따른 변화)
    int focusBase = base + (maxVolume > 5 ? 5 : 0);
    int accuracyBase = base + (maxVolume < 3 ? 5 : 0); // 초급은 정확도 강조
    int creativityBase = base - (maxVolume < 5 ? 5 : 0); // 고급으로 갈수록 창의성 점수 증가

    // 출석률 및 진도에 따른 보정
    int bonus = (attendanceRate >= 0.9 ? 3 : 0) + (isFastProgress ? 2 : 0);

    final random = Random();

    // 최종 점수 산출 (베이스라인 + 보정 + 소량의 무작위성 ±2점)
    return AchievementScores(
      focus: _clamp(focusBase + bonus + random.nextInt(5) - 2),
      application: _clamp(base + bonus + random.nextInt(5) - 2),
      accuracy: _clamp(accuracyBase + bonus + random.nextInt(5) - 2),
      task: _clamp(
        base + bonus + (isFastProgress ? 5 : 0) + random.nextInt(5) - 2,
      ),
      creativity: _clamp(creativityBase + bonus + random.nextInt(5) - 2),
    );
  }

  static int _clamp(int score) {
    return score.clamp(0, 100);
  }

  /// 출석률 계산
  static double calculateAttendanceRate(int attendanceCount, int totalClasses) {
    if (totalClasses == 0) return 0.0;
    return (attendanceCount / totalClasses).clamp(0.0, 1.0);
  }
}
