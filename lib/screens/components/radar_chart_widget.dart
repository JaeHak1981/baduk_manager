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
    final radius = min(size.width, size.height) / 2 * 0.75;
    final angleStep = (2 * pi) / 5;

    final labels = ['집중력', '응용력', '정확도', '과제수행', '창의성'];

    // 1. 배경 그리드 (다각형 쉐이드)
    final gridPaint = Paint()
      ..color = Colors.indigo.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final gridStrokePaint = Paint()
      ..color = Colors.indigo.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 5; i >= 1; i--) {
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
      if (i % 2 == 0) canvas.drawPath(path, gridPaint);
      canvas.drawPath(path, gridStrokePaint);
    }

    // 축 라인
    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        ),
        gridStrokePaint,
      );
    }

    // 2. 과거 데이터 (있을 경우)
    if (previousScores != null) {
      _drawScorePath(
        canvas,
        center,
        radius,
        angleStep,
        previousScores!,
        Colors.grey.withOpacity(0.2),
        isFilled: true,
      );
    }

    // 3. 현재 데이터 (그라데이션 필 및 강조)
    final values = [
      scores.focus,
      scores.application,
      scores.accuracy,
      scores.task,
      scores.creativity,
    ];
    final scorePath = Path();
    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;
      final value = (values[i] / 100.0).clamp(0.1, 1.0);
      final point = Offset(
        center.dx + radius * value * cos(angle),
        center.dy + radius * value * sin(angle),
      );
      if (i == 0)
        scorePath.moveTo(point.dx, point.dy);
      else
        scorePath.lineTo(point.dx, point.dy);
    }
    scorePath.close();

    // 그라데이션 필 (농도 대폭 축소: 0.3/0.2 -> 0.15/0.1)
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.indigo.withOpacity(0.15), Colors.teal.withOpacity(0.1)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(scorePath, fillPaint);

    // 스트로크 강조 (더 연하게: 2.0 -> 1.5, 0.5 -> 0.25)
    final strokePaint = Paint()
      ..color = Colors.indigo.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(scorePath, strokePaint);

    // 데이터 포인트 (점)
    final pointPaint = Paint()..color = Colors.white;
    final pointShadowPaint = Paint()..color = Colors.indigo.withOpacity(0.25);
    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;
      final value = (values[i] / 100.0).clamp(0.1, 1.0);
      final point = Offset(
        center.dx + radius * value * cos(angle),
        center.dy + radius * value * sin(angle),
      );
      canvas.drawCircle(point, 3, pointShadowPaint);
      canvas.drawCircle(point, 1.5, pointPaint);
    }

    // 4. 라벨 (Chip 스타일)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: Colors.indigo.shade900.withOpacity(0.6),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();

      final labelRadius = radius + 25;
      final labelCenter = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );

      // Chip 배경 (더 투명하게: 0.7 -> 0.15)
      final chipRect = Rect.fromCenter(
        center: labelCenter,
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      );
      final chipPaint = Paint()
        ..color = Colors.indigo.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, const Radius.circular(12)),
        chipPaint,
      );

      // 텍스트 위치
      final textOffset = Offset(
        labelCenter.dx - textPainter.width / 2,
        labelCenter.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawScorePath(
    Canvas canvas,
    Offset center,
    double radius,
    double angleStep,
    AchievementScores s,
    Color color, {
    bool isFilled = true,
  }) {
    final values = [s.focus, s.application, s.accuracy, s.task, s.creativity];
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = i * angleStep - pi / 2;
      final value = (values[i] / 100.0).clamp(0.1, 1.0);
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
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) => true;
}
