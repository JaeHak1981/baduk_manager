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
      // Firestore 맵의 키는 반드시 String이어야 하므로 변환
      'holidays': holidays.map((key, value) => MapEntry(key.toString(), value)),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory AcademyScheduleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    final rawHolidays = data['holidays'] as Map<String, dynamic>? ?? {};

    return AcademyScheduleModel(
      id: snapshot.id,
      academyId: data['academyId'] as String,
      year: data['year'] as int,
      month: data['month'] as int,
      // 문자열로 저장된 키를 다시 int로 복구
      holidays: rawHolidays.map(
        (key, value) => MapEntry(int.parse(key), value as String),
      ),
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
