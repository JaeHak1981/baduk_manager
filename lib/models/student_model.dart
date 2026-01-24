import 'package:cloud_firestore/cloud_firestore.dart';

/// 학생 모델
class StudentModel {
  final String id;
  final String academyId; // 소속 기관 ID
  final String ownerId; // 소유자 ID 추가 (보안 규칙용)
  final String name; // 학생 이름
  final String? birthDate; // 생년월일 (YYYY-MM-DD)
  final String? parentPhone; // 보호자 연락처
  final int level; // 바둑 급수 (예: 30 ~ 1, 숫자가 낮을수록 고수/단)
  final String? note; // 관리자 메모
  final int? session; // 부 (1~4부)
  final int? grade; // 학년
  final String? classNumber; // 반
  final String? studentNumber; // 번호
  final DateTime createdAt;
  final DateTime? updatedAt;

  StudentModel({
    required this.id,
    required this.academyId,
    required this.ownerId,
    required this.name,
    this.birthDate,
    this.parentPhone,
    this.level = 30, // 기본 30급
    this.note,
    this.session,
    this.grade,
    this.classNumber,
    this.studentNumber,
    required this.createdAt,
    this.updatedAt,
  });

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'academyId': academyId,
      'ownerId': ownerId,
      'name': name,
      'birthDate': birthDate,
      'parentPhone': parentPhone,
      'level': level,
      'note': note,
      'session': session,
      'grade': grade,
      'classNumber': classNumber,
      'studentNumber': studentNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Firestore 문서에서 생성
  factory StudentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return StudentModel(
      id: snapshot.id,
      academyId: data['academyId'] as String,
      ownerId: data['ownerId'] as String? ?? '', // 기본값 처리
      name: data['name'] as String,
      birthDate: data['birthDate'] as String?,
      parentPhone: data['parentPhone'] as String?,
      level: data['level'] as int? ?? 30,
      note: data['note'] as String?,
      session: data['session'] as int?,
      grade: data['grade'] as int?,
      classNumber: data['classNumber'] as String?,
      studentNumber: data['studentNumber'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// 복사본 생성
  StudentModel copyWith({
    String? id,
    String? academyId,
    String? ownerId,
    String? name,
    String? birthDate,
    String? parentPhone,
    int? level,
    String? note,
    int? session,
    int? grade,
    String? classNumber,
    String? studentNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      academyId: academyId ?? this.academyId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      parentPhone: parentPhone ?? this.parentPhone,
      level: level ?? this.level,
      note: note ?? this.note,
      session: session ?? this.session,
      grade: grade ?? this.grade,
      classNumber: classNumber ?? this.classNumber,
      studentNumber: studentNumber ?? this.studentNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 급수 표시 문자열 (예: 30급, 1단)
  String get levelDisplayName {
    if (level > 0) {
      return '$level급';
    } else {
      // 0 이하인 경우 단으로 표시 (1단부터 시작하도록 처리)
      // 내부적으로 0 -> 1단, -1 -> 2단 ... 으로 저장
      return '${level.abs() + 1}단';
    }
  }
}
