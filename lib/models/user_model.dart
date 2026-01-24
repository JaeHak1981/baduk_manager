import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 역할
enum UserRole {
  developer, // 개발자 (모든 데이터 읽기 전용)
  owner, // 학원 소유자
  teacher, // 선생님
}

/// 사용자 모델
class UserModel {
  final String uid;
  final String email;
  final UserRole role;
  final String? academyId; // 학원 소유자/선생님인 경우
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.academyId,
    required this.createdAt,
    this.updatedAt,
  });

  /// Firestore 문서에서 UserModel 생성
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String,
      role: _parseRole(data['role'] as String),
      academyId: data['academyId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// UserModel을 Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role.name,
      'academyId': academyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// 문자열을 UserRole로 변환
  static UserRole _parseRole(String roleString) {
    switch (roleString) {
      case 'developer':
        return UserRole.developer;
      case 'owner':
        return UserRole.owner;
      case 'teacher':
        return UserRole.teacher;
      default:
        throw Exception('Unknown role: $roleString');
    }
  }

  /// 개발자 여부 확인
  bool get isDeveloper => role == UserRole.developer;

  /// 학원 소유자 여부 확인
  bool get isOwner => role == UserRole.owner;

  /// 선생님 여부 확인
  bool get isTeacher => role == UserRole.teacher;

  /// UserModel 복사 (일부 필드 변경)
  UserModel copyWith({
    String? uid,
    String? email,
    UserRole? role,
    String? academyId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      academyId: academyId ?? this.academyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
