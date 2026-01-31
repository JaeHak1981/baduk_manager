import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/education_report_model.dart';

class BarHorizontalChartWidget extends StatelessWidget {
  final AchievementScores scores;

  const BarHorizontalChartWidget({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final data = [
      {'label': '집중력', 'score': scores.focus},
      {'label': '응용력', 'score': scores.application},
      {'label': '정확도', 'score': scores.accuracy},
      {'label': '과제수행', 'score': scores.task},
      {'label': '창의성', 'score': scores.creativity},
    ];

    // fl_chart의 BarChart를 회전시키거나 RotatedBox를 사용해야 함.
    // 여기서는 RotatedBox를 사용하여 구현.

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RotatedBox(
        quarterTurns: 1, // 90도 회전
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              enabled: false,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent, // 툴팁 숨김 혹은 투명하게 처리
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 0,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    rod.toY.round().toString(),
                    const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              // 바닥(원래 왼쪽)에 레이블 표시 -> 회전되면 왼쪽이 됨
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: RotatedBox(
                          quarterTurns: -1, // 글자는 다시 역회전해서 똑바로 보이게
                          child: Text(
                            data[index]['label'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: false),
            barGroups: data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final score = item['score'] as int;

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: score.toDouble(),
                    color: const Color(0xFFFFD54F), // Amber 300
                    width: 14,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(4),
                    ), // 회전했으므로 top이 오른쪽
                    backDrawRodData: BackgroundBarChartRodData(
                      show: false,
                      toY: 100,
                      color: const Color(0xFFF5F5F5),
                    ),
                  ),
                ],
              );
            }).toList(),
            maxY: 100,
            alignment: BarChartAlignment.spaceEvenly,
          ),
        ),
      ),
    );
  }
}
