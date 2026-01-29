import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/education_report_model.dart';

class RadarChartWidget extends StatelessWidget {
  final AchievementScores scores;
  final AchievementScores? previousScores;

  const RadarChartWidget({
    super.key,
    required this.scores,
    this.previousScores,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: RadarChartPainter(
          scores: scores,
          previousScores: previousScores,
          colors: [
            Colors.purple.withOpacity(0.4),
            Colors.blue.withOpacity(0.3),
          ],
        ),
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final AchievementScores scores;
  final AchievementScores? previousScores;
  final List<Color> colors;

  RadarChartPainter({
    required this.scores,
    this.previousScores,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.8;
    final angleStep = (2 * pi) / 5;

    final labels = ['집중력', '응용력', '정확도', '과제수행', '창의성'];

    // 1. 가이드 라인 (그리드) 그리기
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 5; i++) {
      final r = radius * (i / 5);
      final path = Path();
      for (var j = 0; j < 5; j++) {
        final angle = j * angleStep - pi / 2;
        final point = Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle),
        );
        if (j == 0)
          path.moveTo(point.dx, point.dy);
        else
          path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 축 라인 및 라벨
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;
      final outerPoint = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, outerPoint, gridPaint);

      // 라벨 그리기
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      final labelOffset = Offset(
        center.dx + (radius + 15) * cos(angle) - textPainter.width / 2,
        center.dy + (radius + 15) * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    }

    // 2. 과거 데이터 (있을 경우) 그리기 - 연한 회색/점선 느낌
    if (previousScores != null) {
      _drawScorePath(
        canvas,
        center,
        radius,
        angleStep,
        previousScores!,
        Colors.grey.withOpacity(0.3),
        isFilled: true,
      );
    }

    // 3. 현재 데이터 그리기 - 메인 색상
    _drawScorePath(
      canvas,
      center,
      radius,
      angleStep,
      scores,
      Colors.purple.withOpacity(0.6),
      isFilled: true,
    );
    _drawScorePath(
      canvas,
      center,
      radius,
      angleStep,
      scores,
      Colors.purple,
      isFilled: false,
      strokeWidth: 2,
    );
  }

  void _drawScorePath(
    Canvas canvas,
    Offset center,
    double radius,
    double angleStep,
    AchievementScores s,
    Color color, {
    bool isFilled = true,
    double strokeWidth = 1,
  }) {
    final values = [s.focus, s.application, s.accuracy, s.task, s.creativity];
    final path = Path();

    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;
      final value = values[i] / 100.0;
      final point = Offset(
        center.dx + radius * value * cos(angle),
        center.dy + radius * value * sin(angle),
      );

      if (i == 0)
        path.moveTo(point.dx, point.dy);
      else
        path.lineTo(point.dx, point.dy);
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.scores != scores ||
        oldDelegate.previousScores != previousScores;
  }
}
