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
  final int totalVolumes; // 전체 권수 (시리즈) - [ADDED] for progress calculation
  final bool
  isCompleted; // 완료 여부 (현재 권수가 마지막 권이고 완료되었을 때?) or simply "Current Volume Completed"?
  // For simplicity: False = In Progress, True = Completed (Waiting for next volume assignment or fully done)
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
    required this.totalVolumes,
    this.isCompleted = false,
    required this.startDate,
    this.endDate,
    required this.updatedAt,
  });

  // Calculate percentage based on Volumes
  // If volumeNumber is 1 (of 4), and not completed: 0%? Or 1/4?
  // Let's say: "Completed Volumes / Total Volumes"
  // If isCompleted is true, count current volume as done.
  // If false, count (volumeNumber - 1) as done.
  double get progressPercentage {
    if (totalVolumes <= 0) return 0.0;
    // 사용자의 요청: 4권 중 1권을 지급하면 25%가 나와야 함
    // 즉, 현재 배정된 권수 자체가 진도 지표가 됨
    return (volumeNumber / totalVolumes * 100).clamp(0, 100);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'academyId': academyId,
      'ownerId': ownerId,
      'textbookId': textbookId,
      'textbookName': textbookName,
      'volumeNumber': volumeNumber,
      'totalVolumes': totalVolumes,
      'isCompleted': isCompleted,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory StudentProgressModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    try {
      final data = snapshot.data()!;
      return StudentProgressModel(
        id: snapshot.id,
        studentId: data['studentId'] as String? ?? '',
        academyId: data['academyId'] as String? ?? '',
        ownerId: data['ownerId'] as String? ?? '',
        textbookId: data['textbookId'] as String? ?? '',
        textbookName: data['textbookName'] as String? ?? '알 수 없는 교재',
        volumeNumber: data['volumeNumber'] as int? ?? 1,
        totalVolumes: data['totalVolumes'] as int? ?? 1,
        isCompleted: data['isCompleted'] as bool? ?? false,
        startDate: (data['startDate'] as Timestamp).toDate(),
        endDate: data['endDate'] != null
            ? (data['endDate'] as Timestamp).toDate()
            : null,
        updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      );
    } catch (e) {
      print(
        'StudentProgressModel.fromFirestore 파싱 에러 (ID: ${snapshot.id}): $e',
      );
      // 최소한의 데이터로 복구하여 리스트 깨짐 방지
      return StudentProgressModel(
        id: snapshot.id,
        studentId: '',
        academyId: '',
        ownerId: '',
        textbookId: '',
        textbookName: '데이터 오류 교재',
        volumeNumber: 1,
        totalVolumes: 1,
        startDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  StudentProgressModel copyWith({
    int? volumeNumber,
    int? totalVolumes,
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
      totalVolumes: totalVolumes ?? this.totalVolumes,
      isCompleted: isCompleted ?? this.isCompleted,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
