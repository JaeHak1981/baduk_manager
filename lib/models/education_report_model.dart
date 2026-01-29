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

/// 교육 통지표 메인 모델
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
  final String templateId; // 4종 중 선택된 템플릿 ID
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.templateId = 'classic',
    required this.createdAt,
    required this.updatedAt,
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
      'templateId': templateId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
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
      templateId: data['templateId'] as String? ?? 'classic',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  EducationReportModel copyWith({
    AchievementScores? scores,
    String? teacherComment,
    String? templateId,
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
      templateId: templateId ?? this.templateId,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

  CommentTemplateModel({
    required this.id,
    this.academyId = 'system',
    this.ownerId,
    required this.category,
    required this.content,
    this.isCustom = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'academyId': academyId,
      'ownerId': ownerId,
      'category': category,
      'content': content,
      'isCustom': isCustom,
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
    );
  }
}
