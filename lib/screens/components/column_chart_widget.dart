import 'package:flutter/material.dart';
import '../../models/education_report_model.dart';

class ColumnChartWidget extends StatelessWidget {
  final AchievementScores scores;

  const ColumnChartWidget({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final data = [
      {'label': '집중', 'score': scores.focus, 'color': Colors.blue},
      {'label': '응용', 'score': scores.application, 'color': Colors.teal},
      {'label': '정확', 'score': scores.accuracy, 'color': Colors.orange},
      {'label': '과제', 'score': scores.task, 'color': Colors.purple},
      {'label': '창의', 'score': scores.creativity, 'color': Colors.pink},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((item) {
          final score = item['score'] as int;
          final color = item['color'] as Color;
          final label = item['label'] as String;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: (score / 100).clamp(0.05, 1.0),
                      widthFactor: 0.6,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [color, color.withOpacity(0.6)],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(2, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
