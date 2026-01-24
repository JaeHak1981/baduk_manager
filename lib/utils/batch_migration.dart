import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';

final List<Map<String, dynamic>> migratedStudents = [
  // 1부 (6교시)
  {
    'name': '안영준',
    'grade': 1,
    'classNumber': '1',
    'studentNumber': '7',
    'session': 1,
  },
  {
    'name': '강건우',
    'grade': 1,
    'classNumber': '2',
    'studentNumber': '1',
    'session': 1,
  },
  {
    'name': '최이준',
    'grade': 1,
    'classNumber': '4',
    'studentNumber': '16',
    'session': 1,
  },
  {
    'name': '정의로운',
    'grade': 1,
    'classNumber': '4',
    'studentNumber': '13',
    'session': 1,
  },
  {
    'name': '김우진',
    'grade': 1,
    'classNumber': '4',
    'studentNumber': '4',
    'session': 1,
  },
  {
    'name': '이채준',
    'grade': 2,
    'classNumber': '1',
    'studentNumber': '14',
    'session': 1,
  },
  {
    'name': '김지윤',
    'grade': 2,
    'classNumber': '2',
    'studentNumber': '4',
    'session': 1,
  },
  {
    'name': '김도율',
    'grade': 2,
    'classNumber': '3',
    'studentNumber': '4',
    'session': 1,
  },
  {
    'name': '장강빈',
    'grade': 2,
    'classNumber': '3',
    'studentNumber': '16',
    'session': 1,
  },
  {
    'name': '박서준',
    'grade': 2,
    'classNumber': '4',
    'studentNumber': '8',
    'session': 1,
  },
  {
    'name': '백서율',
    'grade': 2,
    'classNumber': '5',
    'studentNumber': '10',
    'session': 1,
  },
  {
    'name': '전지안',
    'grade': 2,
    'classNumber': '3',
    'studentNumber': '17',
    'session': 1,
  },

  // 2부 (7교시)
  {
    'name': '방현민',
    'grade': 2,
    'classNumber': '1',
    'studentNumber': '9',
    'session': 2,
  },
  {
    'name': '박시후',
    'grade': 1,
    'classNumber': '4',
    'studentNumber': '7',
    'session': 2,
  },
  {
    'name': '이선',
    'grade': 2,
    'classNumber': '1',
    'studentNumber': '12',
    'session': 2,
  },
  {
    'name': '박서하',
    'grade': 2,
    'classNumber': '4',
    'studentNumber': '9',
    'session': 2,
  },
  {
    'name': '김주환',
    'grade': 2,
    'classNumber': '4',
    'studentNumber': '6',
    'session': 2,
  },
  {
    'name': '윤재우',
    'grade': 2,
    'classNumber': '5',
    'studentNumber': '19',
    'session': 2,
  },
  {
    'name': '유하준',
    'grade': 2,
    'classNumber': '3',
    'studentNumber': '11',
    'session': 2,
  },

  // 3부 (8교시)
  {
    'name': '조우빈',
    'grade': 3,
    'classNumber': '1',
    'studentNumber': '17',
    'session': 3,
  },
  {
    'name': '최시온',
    'grade': 3,
    'classNumber': '2',
    'studentNumber': '15',
    'session': 3,
  },
  {
    'name': '윤하진',
    'grade': 3,
    'classNumber': '5',
    'studentNumber': '9',
    'session': 3,
  },
  {
    'name': '안지한',
    'grade': 3,
    'classNumber': '5',
    'studentNumber': '6',
    'session': 3,
  },
  {
    'name': '박도현',
    'grade': 4,
    'classNumber': '4',
    'studentNumber': '7',
    'session': 3,
  },
  {
    'name': '강지우',
    'grade': 5,
    'classNumber': '5',
    'studentNumber': '2',
    'session': 3,
  },
  {
    'name': '방승환',
    'grade': 3,
    'classNumber': '3',
    'studentNumber': '5',
    'session': 3,
  },
  {
    'name': '김도하',
    'grade': 4,
    'classNumber': '5',
    'studentNumber': '4',
    'session': 3,
  },
];

Future<void> seedMigratedStudents(String academyId) async {
  final service = StudentService();
  final batch = FirebaseFirestore.instance.batch();
  final collection = FirebaseFirestore.instance.collection('students');

  for (final data in migratedStudents) {
    final docRef = collection.doc();
    final student = StudentModel(
      id: docRef.id,
      academyId: academyId,
      ownerId: 'migrated', // 배치 마이그레이션용 임시 ID
      name: data['name'],
      grade: data['grade'],
      classNumber: data['classNumber'],
      studentNumber: data['studentNumber'],
      session: data['session'],
      level: 30, // Default level
      createdAt: DateTime.now(),
    );
    batch.set(docRef, student.toFirestore());
  }

  await batch.commit();
}
