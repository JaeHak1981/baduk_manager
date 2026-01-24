import 'package:cloud_firestore/cloud_firestore.dart';

/// 학생별 진도 기록 모델
class StudentProgressModel {
  final String id;
  final String studentId; // 학생 ID
  final String academyId; // 기관 ID
  final String ownerId; // 관리자(선생님) ID - 권한 확인용
  final String textbookId; // 교재 시리즈 ID
  final String textbookName; // 표시용 교재 이름
  final int volumeNumber; // 현재 학습 중인 권수 (시리즈 중 몇 권인지)
  final int currentPage; // 현재 학습 페이지
  final int totalPages; // 해당 권의 전체 페이지
  final bool isCompleted; // 완료 여부
  final DateTime startDate; // 학습 시작일
  final DateTime? endDate; // 학습 완료일
  final DateTime updatedAt; // 마지막 기록일

  StudentProgressModel({
    required this.id,
    required this.studentId,
    required this.academyId,
    required this.ownerId,
    required this.textbookId,
    required this.textbookName,
    required this.volumeNumber,
    required this.currentPage,
    required this.totalPages,
    this.isCompleted = false,
    required this.startDate,
    this.endDate,
    required this.updatedAt,
  });

  double get progressPercentage =>
      (currentPage / totalPages * 100).clamp(0, 100);

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'academyId': academyId,
      'ownerId': ownerId,
      'textbookId': textbookId,
      'textbookName': textbookName,
      'volumeNumber': volumeNumber,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'isCompleted': isCompleted,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory StudentProgressModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return StudentProgressModel(
      id: snapshot.id,
      studentId: data['studentId'] as String,
      academyId: data['academyId'] as String,
      ownerId: data['ownerId'] as String? ?? '', // 기존 데이터 호환
      textbookId: data['textbookId'] as String,
      textbookName: data['textbookName'] as String? ?? '알 수 없는 교재',
      volumeNumber: data['volumeNumber'] as int? ?? 1,
      currentPage: data['currentPage'] as int? ?? 0,
      totalPages: data['totalPages'] as int? ?? 1,
      isCompleted: data['isCompleted'] as bool? ?? false,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  StudentProgressModel copyWith({
    int? volumeNumber,
    int? currentPage,
    bool? isCompleted,
    DateTime? endDate,
    DateTime? updatedAt,
  }) {
    return StudentProgressModel(
      id: id,
      studentId: studentId,
      academyId: academyId,
      ownerId: ownerId,
      textbookId: textbookId,
      textbookName: textbookName,
      volumeNumber: volumeNumber ?? this.volumeNumber,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages,
      isCompleted: isCompleted ?? this.isCompleted,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
