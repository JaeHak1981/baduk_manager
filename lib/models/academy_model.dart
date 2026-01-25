import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 기관 타입
enum AcademyType {
  academy, // 학원
  school, // 학교
  tutoring, // 교습소
}

/// 기관 타입 확장 - 한글 이름 및 아이콘
extension AcademyTypeExtension on AcademyType {
  String get displayName {
    switch (this) {
      case AcademyType.academy:
        return '학원';
      case AcademyType.school:
        return '학교';
      case AcademyType.tutoring:
        return '교습소';
    }
  }

  IconData get icon {
    switch (this) {
      case AcademyType.academy:
        return Icons.school;
      case AcademyType.school:
        return Icons.account_balance;
      case AcademyType.tutoring:
        return Icons.menu_book;
    }
  }
}

/// 기관 모델
class AcademyModel {
  final String id;
  final String name;
  final AcademyType type;
  final String ownerId;
  final String? phoneNumber;
  final String? address;
  final int totalSessions; // 총 운영 부수 (예: 1~4부)
  final List<int> lessonDays; // 수업 요일 (1:월, ..., 7:일)
  final List<String> usingTextbookIds; // 사용 중인 교재 ID 목록
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted; // 삭제 여부 (Soft Delete)
  final DateTime? deletedAt; // 삭제 일시

  AcademyModel({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    this.phoneNumber,
    this.address,
    this.totalSessions = 1,
    this.lessonDays = const [],
    this.usingTextbookIds = const [],
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'ownerId': ownerId,
      'phoneNumber': phoneNumber,
      'address': address,
      'totalSessions': totalSessions,
      'lessonDays': lessonDays,
      'usingTextbookIds': usingTextbookIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  /// Firestore 문서에서 생성
  factory AcademyModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    final type = AcademyType.values.firstWhere(
      (e) => e.name == data['type'],
      orElse: () => AcademyType.academy,
    );
    return AcademyModel(
      id: snapshot.id,
      name: data['name'] as String,
      type: type,
      ownerId: data['ownerId'] as String,
      phoneNumber: data['phoneNumber'] as String?,
      address: data['address'] as String?,
      totalSessions:
          data['totalSessions'] as int? ?? (type == AcademyType.school ? 4 : 1),
      lessonDays: List<int>.from(data['lessonDays'] ?? []),
      usingTextbookIds: List<String>.from(data['usingTextbookIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isDeleted: data['isDeleted'] ?? false,
      deletedAt: data['deletedAt'] != null
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// 복사본 생성
  AcademyModel copyWith({
    String? id,
    String? name,
    AcademyType? type,
    String? ownerId,
    String? phoneNumber,
    String? address,
    int? totalSessions,
    List<int>? lessonDays,
    List<String>? usingTextbookIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return AcademyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ownerId: ownerId ?? this.ownerId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      totalSessions: totalSessions ?? this.totalSessions,
      lessonDays: lessonDays ?? this.lessonDays,
      usingTextbookIds: usingTextbookIds ?? this.usingTextbookIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
