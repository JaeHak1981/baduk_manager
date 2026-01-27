import 'package:cloud_firestore/cloud_firestore.dart';

class AcademyScheduleModel {
  final String id;
  final String academyId;
  final int year;
  final int month;
  // 날짜별 휴강 사유 (Key: day (1~31), Value: reason)
  final Map<int, String> holidays;
  final DateTime? updatedAt;

  AcademyScheduleModel({
    required this.id,
    required this.academyId,
    required this.year,
    required this.month,
    required this.holidays,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'academyId': academyId,
      'year': year,
      'month': month,
      'holidays': holidays,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory AcademyScheduleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return AcademyScheduleModel(
      id: snapshot.id,
      academyId: data['academyId'] as String,
      year: data['year'] as int,
      month: data['month'] as int,
      holidays: Map<int, String>.from(data['holidays'] ?? {}),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  AcademyScheduleModel copyWith({
    String? id,
    String? academyId,
    int? year,
    int? month,
    Map<int, String>? holidays,
    DateTime? updatedAt,
  }) {
    return AcademyScheduleModel(
      id: id ?? this.id,
      academyId: academyId ?? this.academyId,
      year: year ?? this.year,
      month: month ?? this.month,
      holidays: holidays ?? this.holidays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
