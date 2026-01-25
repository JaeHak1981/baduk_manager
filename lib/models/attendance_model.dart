import 'package:cloud_firestore/cloud_firestore.dart';

/// 출결 상태 구분
enum AttendanceType {
  present, // 출석
  absent, // 결석
  late, // 지각
  manual, // 직접 입력 (기타)
}

/// 출결 기록 모델
class AttendanceRecord {
  final String id;
  final String studentId;
  final String academyId;
  final String ownerId;
  final DateTime timestamp;
  final AttendanceType type;
  final String? note;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.academyId,
    required this.ownerId,
    required this.timestamp,
    required this.type,
    this.note,
  });

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'academyId': academyId,
      'ownerId': ownerId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
      'note': note,
    };
  }

  /// Firestore 문서에서 생성
  factory AttendanceRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return AttendanceRecord(
      id: snapshot.id,
      studentId: data['studentId'] as String,
      academyId: data['academyId'] as String,
      ownerId: data['ownerId'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: AttendanceType.values.byName(data['type'] as String? ?? 'present'),
      note: data['note'] as String?,
    );
  }

  /// 특정 날짜의 시작 시간으로 변환된 날짜 문자열 (YYYY-MM-DD)
  String get dateString =>
      "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}";

  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? academyId,
    String? ownerId,
    DateTime? timestamp,
    AttendanceType? type,
    String? note,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      academyId: academyId ?? this.academyId,
      ownerId: ownerId ?? this.ownerId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      note: note ?? this.note,
    );
  }
}
