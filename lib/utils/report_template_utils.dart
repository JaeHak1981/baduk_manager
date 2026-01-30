import '../models/education_report_model.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ReportTemplateUtils {
  /// 선택된 테마에 맞춰 HTML 생성
  static String generateHtml({
    required EducationReportModel report,
    required String studentName,
    required List<String> textbookNames,
    String? academyLogoUrl,
    String? academyName,
  }) {
    final scores = report.scores;
    final radarSvg = _generateRadarSvg(scores);
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
    final periodStr =
        "${DateFormat('yyyy.MM').format(report.startDate)} ~ ${DateFormat('yyyy.MM').format(report.endDate)}";

    String primaryColor = '#1a237e'; // Classic Navy

    return """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;700&display=swap');
        body {
            font-family: 'Noto Sans KR', sans-serif;
            margin: 0;
            padding: 40px;
            color: #333;
            line-height: 1.6;
        }
        .container {
            width: 100%;
            max-width: 800px;
            margin: 0 auto;
            border: 5px double $primaryColor;
            padding: 40px;
            position: relative;
            background-color: white;
        }
        .header {
            text-align: center;
            border-bottom: 2px solid $primaryColor;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            color: $primaryColor;
            font-size: 32px;
            margin: 0;
            letter-spacing: 5px;
        }
        .student-info {
            display: flex;
            justify-content: space-between;
            margin-bottom: 30px;
            font-size: 18px;
        }
        .section {
            margin-bottom: 40px;
        }
        .section-title {
            font-weight: bold;
            font-size: 20px;
            color: $primaryColor;
            margin-bottom: 15px;
            border-left: 5px solid $primaryColor;
            padding-left: 10px;
        }
        .chart-container {
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 20px 0;
        }
        .score-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        .score-table th, .score-table td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: center;
        }
        .score-table th {
            background-color: #f8f9fa;
            color: $primaryColor;
        }
        .comment-box {
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            padding: 20px;
            min-height: 150px;
            white-space: pre-wrap;
            border-radius: 8px;
        }
        .footer {
            margin-top: 50px;
            text-align: center;
            font-size: 14px;
            color: #777;
        }
        .stamp {
            position: absolute;
            bottom: 60px;
            right: 60px;
            width: 80px;
            height: 80px;
            border: 3px double #d32f2f;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
            color: #d32f2f;
            font-weight: bold;
            transform: rotate(-15deg);
            opacity: 0.8;
            font-size: 24px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>교 육 통 지 표</h1>
            <p style="margin-top: 10px; font-weight: bold;">$periodStr</p>
        </div>

        <div class="student-info">
            <div>학생명: <strong>$studentName</strong></div>
            <div>발행일: $dateStr</div>
        </div>

        <div class="section">
            <div class="section-title">종합 성취도 분석</div>
            <div class="chart-container">
                $radarSvg
            </div>
            <table class="score-table">
                <tr>
                    <th>집중력</th>
                    <th>응용력</th>
                    <th>정확도</th>
                    <th>과제수행</th>
                    <th>창의성</th>
                </tr>
                <tr>
                    <td>${scores.focus}</td>
                    <td>${scores.application}</td>
                    <td>${scores.accuracy}</td>
                    <td>${scores.task}</td>
                    <td>${scores.creativity}</td>
                </tr>
            </table>
        </div>

        <div class="section">
            <div class="section-title">학습 현황 통계</div>
            <p>• 출석 현황: 총 ${report.totalClasses}회 중 <strong>${report.attendanceCount}회</strong> 출석 (${(report.attendanceCount / (report.totalClasses == 0 ? 1 : report.totalClasses) * 100).toStringAsFixed(0)}%)</p>
            <p>• 진도 교재: ${textbookNames.isEmpty ? '정보 없음' : textbookNames.join(', ')}</p>
        </div>

        <div class="section">
            <div class="section-title">지도 교사 총평</div>
            <div class="comment-box">${report.teacherComment}</div>
        </div>

        <div class="footer">
            <p>위와 같이 교육 성취도를 보고합니다.</p>
            <h2 style="color: $primaryColor; margin-top: 10px;">${academyName ?? '지능형 바둑 아카데미'}</h2>
        </div>
        
        <div class="stamp">인</div>
    </div>
</body>
</html>
""";
  }

  static String _generateRadarSvg(AchievementScores scores) {
    const double size = 300;
    const double center = size / 2;
    const double radius = size * 0.4;
    final values = [
      scores.focus,
      scores.application,
      scores.accuracy,
      scores.task,
      scores.creativity,
    ];

    String gridStr = "";
    // Draw 5 levels of Grid
    for (int i = 1; i <= 5; i++) {
      double currentR = radius * (i / 5);
      List<String> gridPoints = [];
      for (int j = 0; j < 5; j++) {
        double angle = (j * 72 - 90) * math.pi / 180;
        gridPoints.add(
          "${center + currentR * math.cos(angle)},${center + currentR * math.sin(angle)}",
        );
      }
      gridStr +=
          '<polygon points="${gridPoints.join(' ')}" fill="none" stroke="#ddd" stroke-width="0.5" />';
    }

    // Draw Score Path
    List<String> scorePoints = [];
    for (int j = 0; j < 5; j++) {
      double angle = (j * 72 - 90) * math.pi / 180;
      double val = values[j].toDouble().clamp(0, 100);
      double currentR = radius * (val / 100);
      scorePoints.add(
        "${center + currentR * math.cos(angle)},${center + currentR * math.sin(angle)}",
      );
    }
    String pointsStr = scorePoints.join(' ');

    return '''
    <svg width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">
      $gridStr
      <!-- Axis lines -->
      ${List.generate(5, (j) {
      double angle = (j * 72 - 90) * math.pi / 180;
      return '<line x1="$center" y1="$center" x2="${center + radius * math.cos(angle)}" y2="${center + radius * math.sin(angle)}" stroke="#ddd" stroke-width="0.5" />';
    }).join('\\n')}
      <polygon points="$pointsStr" fill="rgba(26, 35, 126, 0.4)" stroke="rgb(26, 35, 126)" stroke-width="2" />
      <!-- Labels -->
      <text x="150" y="20" text-anchor="middle" font-size="12" font-weight="bold">집중력</text>
      <text x="280" y="125" text-anchor="start" font-size="12" font-weight="bold">응용력</text>
      <text x="240" y="285" text-anchor="middle" font-size="12" font-weight="bold">정확도</text>
      <text x="60" y="285" text-anchor="middle" font-size="12" font-weight="bold">과제수행</text>
      <text x="20" y="125" text-anchor="end" font-size="12" font-weight="bold">창의성</text>
    </svg>
    ''';
  }
}
