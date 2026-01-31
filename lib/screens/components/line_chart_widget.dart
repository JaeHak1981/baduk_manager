import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/education_report_model.dart';

class LineChartWidget extends StatelessWidget {
  final AchievementScores scores;

  const LineChartWidget({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    // 현재 평균 점수 계산
    final currentAvg =
        (scores.focus +
            scores.application +
            scores.accuracy +
            scores.task +
            scores.creativity) /
        5.0;

    // 가상 데이터 (최근 3개월 추이)
    // 2달 전: 현재보다 10~15점 낮게
    // 1달 전: 현재보다 5~8점 낮게
    // 이번 달: 현재 점수
    final points = [
      FlSpot(0, (currentAvg - 12).clamp(0, 100).toDouble()),
      FlSpot(1, (currentAvg - 6).clamp(0, 100).toDouble()),
      FlSpot(2, currentAvg),
    ];

    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 8, top: 16, bottom: 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          '2달 전',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      );
                    case 1:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          '지난달',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      );
                    case 2:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          '이번 달',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      );
                  }
                  return const Text('');
                },
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
                interval: 20,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 2,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: const Color(0xFF1A237E), // Navy
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: const Color(0xFFFFD700), // Gold
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF1A237E),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF1A237E).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
