import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/education_report_model.dart';

class BarVerticalChartWidget extends StatelessWidget {
  final AchievementScores scores;

  const BarVerticalChartWidget({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final data = [
      {'label': '집중', 'score': scores.focus},
      {'label': '응용', 'score': scores.application},
      {'label': '정확', 'score': scores.accuracy},
      {'label': '과제', 'score': scores.task},
      {'label': '창의', 'score': scores.creativity},
    ];

    return Padding(
      padding: const EdgeInsets.only(
        top: 16.0,
        bottom: 8.0,
        left: 8.0,
        right: 8.0,
      ),
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: const EdgeInsets.all(4),
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
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        data[value.toInt()]['label'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 30,
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
                  color: const Color(0xFF4FC3F7), // Light Blue 300
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: false,
                    toY: 100,
                    color: const Color(0xFFF5F5F5),
                  ),
                ),
              ],
              showingTooltipIndicators: [0],
            );
          }).toList(),
          maxY: 100,
        ),
      ),
    );
  }
}
