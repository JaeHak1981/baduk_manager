import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/education_report_model.dart';

class DoughnutChartWidget extends StatelessWidget {
  final AchievementScores scores;

  const DoughnutChartWidget({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    // 5개 항목 데이터
    final dataMap = {
      '집중': scores.focus,
      '응용': scores.application,
      '정확': scores.accuracy,
      '과제': scores.task,
      '창의': scores.creativity,
    };

    // 종합 평균 점수
    final avgScore = (dataMap.values.reduce((a, b) => a + b) / 5).round();

    // 색상 팔레트 (Navy 기반)
    final colors = [
      const Color(0xFF1A237E), // Navy
      const Color(0xFF303F9F),
      const Color(0xFF3949AB),
      const Color(0xFF5C6BC0),
      const Color(0xFF7986CB),
    ];

    int colorIndex = 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            pieTouchData: PieTouchData(enabled: false),
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: dataMap.entries.map((entry) {
              final score = entry.value;
              final color = colors[colorIndex++ % colors.length];
              return PieChartSectionData(
                color: color,
                value: score.toDouble(),
                title: entry.key,
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '종합 점수',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              '$avgScore',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E), // Navy
              ),
            ),
          ],
        ),
      ],
    );
  }
}
