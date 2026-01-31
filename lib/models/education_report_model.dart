import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 교육 통지표에서 사용하는 평가 항목 점수 모델
class AchievementScores {
  final int focus; // 집중력
  final int application; // 응용력
  final int accuracy; // 정확도
  final int task; // 과제수행
  final int creativity; // 창의성

  AchievementScores({
    this.focus = 80,
    this.application = 80,
    this.accuracy = 80,
    this.task = 80,
    this.creativity = 80,
  });

  Map<String, dynamic> toMap() {
    return {
      'focus': focus,
      'application': application,
      'accuracy': accuracy,
      'task': task,
      'creativity': creativity,
    };
  }

  factory AchievementScores.fromMap(Map<String, dynamic> map) {
    return AchievementScores(
      focus: map['focus'] as int? ?? 80,
      application: map['application'] as int? ?? 80,
      accuracy: map['accuracy'] as int? ?? 80,
      task: map['task'] as int? ?? 80,
      creativity: map['creativity'] as int? ?? 80,
    );
  }

  AchievementScores copyWith({
    int? focus,
    int? application,
    int? accuracy,
    int? task,
    int? creativity,
  }) {
    return AchievementScores(
      focus: focus ?? this.focus,
      application: application ?? this.application,
      accuracy: accuracy ?? this.accuracy,
      task: task ?? this.task,
      creativity: creativity ?? this.creativity,
    );
  }
}

/// 위젯의 위치와 크기 정보를 담는 모델
class WidgetLayout {
  final double top;
  final double left;
  final double? width;
  final double? height;

  WidgetLayout({
    required this.top,
    required this.left,
    this.width,
    this.height,
  });

  Map<String, dynamic> toMap() {
    return {'top': top, 'left': left, 'width': width, 'height': height};
  }

  factory WidgetLayout.fromMap(Map<String, dynamic> map) {
    return WidgetLayout(
      top: (map['top'] as num).toDouble(),
      left: (map['left'] as num).toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
    );
  }

  WidgetLayout copyWith({
    double? top,
    double? left,
    double? width,
    double? height,
  }) {
    return WidgetLayout(
      top: top ?? this.top,
      left: left ?? this.left,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// 교육 통지표 메인 모델
enum ReportTemplateType { classic }

extension ReportTemplateTypeExtension on ReportTemplateType {
  String get displayName {
    switch (this) {
      case ReportTemplateType.classic:
        return '클래식 스탠다드';
    }
  }
}

enum BalanceChartType { radar, line, barVertical, barHorizontal, doughnut }

extension BalanceChartTypeExtension on BalanceChartType {
  String get displayName {
    switch (this) {
      case BalanceChartType.radar:
        return '레이더'; // 🕸️
      case BalanceChartType.line:
        return '꺾은선'; // 📈
      case BalanceChartType.barVertical:
        return '세로막대'; // 📊
      case BalanceChartType.barHorizontal:
        return '가로막대'; //
      case BalanceChartType.doughnut:
        return '도넛'; // 🍩
    }
  }

  IconData get icon {
    switch (this) {
      case BalanceChartType.radar:
        return Icons.hexagon_outlined; // 오각형 느낌
      case BalanceChartType.line:
        return Icons.show_chart;
      case BalanceChartType.barVertical:
        return Icons.bar_chart;
      case BalanceChartType.barHorizontal:
        return Icons.notes; // 가로 막대 느낌 (혹은 menu) - notes가 비슷함
      case BalanceChartType.doughnut:
        return Icons.donut_large;
    }
  }
}

enum DetailViewType { progressBar, table, gridCards }

extension DetailViewTypeExtension on DetailViewType {
  String get displayName {
    switch (this) {
      case DetailViewType.progressBar:
        return '막대형';
      case DetailViewType.table:
        return '표 형';
      case DetailViewType.gridCards:
        return '카드형';
    }
  }

  IconData get icon {
    switch (this) {
      case DetailViewType.progressBar:
        return Icons.linear_scale;
      case DetailViewType.table:
        return Icons.table_chart;
      case DetailViewType.gridCards:
        return Icons.grid_view;
    }
  }
}

class EducationReportModel {
  final String id;
  final String academyId;
  final String ownerId;
  final String studentId;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> textbookIds;
  final AchievementScores scores;
  final AchievementScores? previousScores; // 성장 추이 비교를 위한 이전 데이터
  final int attendanceCount;
  final int totalClasses;
  final String teacherComment;
  final Map<String, WidgetLayout>? layouts; // 위젯 ID -> 위치/크기 정보
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReportTemplateType templateType;
  final BalanceChartType balanceChartType;
  final DetailViewType detailViewType;

  EducationReportModel({
    required this.id,
    required this.academyId,
    required this.ownerId,
    required this.studentId,
    required this.startDate,
    required this.endDate,
    required this.textbookIds,
    required this.scores,
    this.previousScores,
    required this.attendanceCount,
    required this.totalClasses,
    required this.teacherComment,
    this.layouts,
    required this.createdAt,
    required this.updatedAt,
    this.templateType = ReportTemplateType.classic,
    this.balanceChartType = BalanceChartType.radar,
    this.detailViewType = DetailViewType.progressBar,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'academyId': academyId,
      'ownerId': ownerId,
      'studentId': studentId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'textbookIds': textbookIds,
      'scores': scores.toMap(),
      'previousScores': previousScores?.toMap(),
      'attendanceCount': attendanceCount,
      'totalClasses': totalClasses,
      'teacherComment': teacherComment,
      'layouts': layouts?.map((key, value) => MapEntry(key, value.toMap())),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'templateType': templateType.name,
      'balanceChartType': balanceChartType.name,
      'detailViewType': detailViewType.name,
    };
  }

  factory EducationReportModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return EducationReportModel(
      id: data['id'] as String,
      academyId: data['academyId'] as String,
      ownerId: data['ownerId'] as String,
      studentId: data['studentId'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      textbookIds: List<String>.from(data['textbookIds'] ?? []),
      scores: AchievementScores.fromMap(data['scores'] as Map<String, dynamic>),
      previousScores: data['previousScores'] != null
          ? AchievementScores.fromMap(
              data['previousScores'] as Map<String, dynamic>,
            )
          : null,
      attendanceCount: data['attendanceCount'] as int? ?? 0,
      totalClasses: data['totalClasses'] as int? ?? 0,
      teacherComment: data['teacherComment'] as String? ?? '',
      layouts: data['layouts'] != null
          ? (data['layouts'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                WidgetLayout.fromMap(value as Map<String, dynamic>),
              ),
            )
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      templateType: ReportTemplateType.classic,
      balanceChartType: _parseChartType(data['balanceChartType'] as String?),
      detailViewType: _parseDetailViewType(data['detailViewType'] as String?),
    );
  }

  static BalanceChartType _parseChartType(String? value) {
    if (value == null) return BalanceChartType.radar;
    // 구 버전 데이터 호환성 처리
    if (value == 'bar') return BalanceChartType.barHorizontal;
    if (value == 'column') return BalanceChartType.barVertical;

    return BalanceChartType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BalanceChartType.radar,
    );
  }

  static DetailViewType _parseDetailViewType(String? value) {
    if (value == null) return DetailViewType.progressBar;
    return DetailViewType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DetailViewType.progressBar,
    );
  }

  EducationReportModel copyWith({
    AchievementScores? scores,
    String? teacherComment,
    ReportTemplateType? templateType,
    BalanceChartType? balanceChartType,
    DetailViewType? detailViewType,
    Map<String, WidgetLayout>? layouts,
    DateTime? updatedAt,
  }) {
    return EducationReportModel(
      id: this.id,
      academyId: this.academyId,
      ownerId: this.ownerId,
      studentId: this.studentId,
      startDate: this.startDate,
      endDate: this.endDate,
      textbookIds: this.textbookIds,
      scores: scores ?? this.scores,
      previousScores: this.previousScores,
      attendanceCount: this.attendanceCount,
      totalClasses: this.totalClasses,
      teacherComment: teacherComment ?? this.teacherComment,
      templateType: templateType ?? this.templateType,
      balanceChartType: balanceChartType ?? this.balanceChartType,
      layouts: layouts ?? this.layouts,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      detailViewType: detailViewType ?? this.detailViewType,
    );
  }
}

/// 총평 문구 템플릿 모델
class CommentTemplateModel {
  final String id;
  final String academyId; // 특정 학원에서 추가한 경우
  final String? ownerId; // 소유자 ID (보안용)
  final String category; // 칭찬, 지도, 성실 등
  final String content; // {{name}}, {{textbook}} 태그 포함 가능
  final bool isCustom; // 사용자가 직접 추가한 것인지 여부
  final int? level; // 수준 (1: 입문/기초, 2: 초급, 3: 중고급)

  CommentTemplateModel({
    required this.id,
    this.academyId = 'system',
    this.ownerId,
    required this.category,
    required this.content,
    this.isCustom = false,
    this.level,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'academyId': academyId,
      'ownerId': ownerId,
      'category': category,
      'content': content,
      'isCustom': isCustom,
      'level': level,
    };
  }

  factory CommentTemplateModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return CommentTemplateModel(
      id: data['id'] as String,
      academyId: data['academyId'] as String? ?? 'system',
      ownerId: data['ownerId'] as String?,
      category: data['category'] as String,
      content: data['content'] as String,
      isCustom: data['isCustom'] as bool? ?? false,
      level: data['level'] as int?,
    );
  }
}
