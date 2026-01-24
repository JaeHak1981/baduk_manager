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
  final DateTime createdAt;
  final DateTime? updatedAt;

  AcademyModel({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    this.phoneNumber,
    this.address,
    required this.createdAt,
    this.updatedAt,
  });

  /// Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'ownerId': ownerId,
      'phoneNumber': phoneNumber,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Firestore 문서에서 생성
  factory AcademyModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return AcademyModel(
      id: snapshot.id,
      name: data['name'] as String,
      type: AcademyType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AcademyType.academy,
      ),
      ownerId: data['ownerId'] as String,
      phoneNumber: data['phoneNumber'] as String?,
      address: data['address'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ownerId: ownerId ?? this.ownerId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
