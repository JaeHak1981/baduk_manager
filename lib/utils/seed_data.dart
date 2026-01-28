import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 초기 교재 데이터 시딩 함수
Future<void> seedTextbooks() async {
  final firestore = FirebaseFirestore.instance;
  final textbooks = firestore.collection('textbooks');

  try {
    // 이미 데이터가 있는지 확인
    final snapshot = await textbooks.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      print('교재 데이터가 이미 존재합니다. 시딩을 건너뜁니다.');
      return;
    }

    final List<Map<String, dynamic>> initialData = [
      {
        'name': '바둑 입문 1단계',
        'totalPages': 40,
        'targetLevel': 30,
        'publisher': '바둑교육사',
        'ownerId': 'common',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': '바둑 입문 2단계',
        'totalPages': 40,
        'targetLevel': 28,
        'publisher': '바둑교육사',
        'ownerId': 'common',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': '초보 바둑 전술',
        'totalPages': 60,
        'targetLevel': 25,
        'publisher': '기원출판',
        'ownerId': 'common',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': '정석의 기초 1',
        'totalPages': 80,
        'targetLevel': 18,
        'publisher': '현대바둑',
        'ownerId': 'common',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (var data in initialData) {
      await textbooks.add(data);
    }
    print('교재 데이터 시딩 완료!');
  } catch (e) {
    if (e.toString().contains('permission-denied')) {
      // 권한 오류는 로그만 남기고 조용히 처리 (로그인 전일 수 있음)
      debugPrint('ℹ️ [seedTextbooks] 권한 대기 중 (로그인 후 다시 시도 권장)');
    } else {
      debugPrint('❌ [seedTextbooks] 에러 발생: $e');
    }
  }
}
