import 'package:flutter/material.dart';
import '../../models/education_report_model.dart';

class BarChartWidget extends StatelessWidget {
  final AchievementScores scores;

  const BarChartWidget({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final data = [
      {'label': '집중력', 'score': scores.focus, 'color': Colors.blue},
      {'label': '응용력', 'score': scores.application, 'color': Colors.teal},
      {'label': '정확도', 'score': scores.accuracy, 'color': Colors.orange},
      {'label': '과제수행', 'score': scores.task, 'color': Colors.purple},
      {'label': '창의성', 'score': scores.creativity, 'color': Colors.pink},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((item) {
          final score = item['score'] as int;
          final color = item['color'] as Color;
          final label = item['label'] as String;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: score / 100,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.7), color],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.end,
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

