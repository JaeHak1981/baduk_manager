import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student_model.dart';
import '../utils/date_extensions.dart';

/// 학생 관리 서비스
class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'students';

  /// 학생 등록
  Future<String> createStudent(StudentModel student) async {
    final docRef = await _firestore
        .collection(_collection)
        .add(student.toFirestore());
    return docRef.id;
  }

  /// 특정 기관의 학생 목록 조회
  Future<List<StudentModel>> getStudentsByAcademy(
    String academyId, {
    String? ownerId,
    bool includeDeleted = false,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId);

    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    final snapshot = await query.orderBy('name').get();
    return snapshot.docs.map((doc) => StudentModel.fromFirestore(doc)).toList();
  }

  /// 특정 기관의 학생 목록 스트림 (실시간 업데이트)
  Stream<List<StudentModel>> getStudentsStream(
    String academyId, {
    String? ownerId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId);

    if (ownerId != null) {
      query = query.where('ownerId', isEqualTo: ownerId);
    }

    return query
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentModel.fromFirestore(doc))
              .where((s) => s.isDeleted != true) // 인 메모리 필터링
              .toList(),
        );
  }

  /// 학생 정보 수정
  Future<void> updateStudent(StudentModel student) async {
    await _firestore
        .collection(_collection)
        .doc(student.id)
        .update(student.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  /// 학생 삭제 (Soft Delete)
  Future<void> deleteStudent(String studentId) async {
    await _firestore.collection(_collection).doc(studentId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 학생 일괄 업데이트 및 삭제 처리 [NEW]
  Future<void> _batchProcessStudents(
    WriteBatch batch, {
    List<StudentModel>? toUpdate,
    List<StudentModel>? toAdd,
    List<String>? toDelete,
    bool isPermanent = false,
    Map<String, Map<String, dynamic>>?
    textbookAssignments, // [NEW] { studentName_grade_class: {textbookName, volumeNumber, ownerId} }
  }) async {
    // 미리 교재 목록 로드 (이름 기반 매칭용)
    // 이 부분은 서비스 외부에서 처리해서 넘겨받는 것이 더 효율적일 수 있으나,
    // 우선은 내부에서 최소한의 쿼리로 처리합니다.

    // 1. 수정 대상 처리
    if (toUpdate != null) {
      for (var s in toUpdate) {
        batch.update(
          _firestore.collection(_collection).doc(s.id),
          s.copyWith(updatedAt: DateTime.now()).toFirestore(),
        );

        // 교재 할당 처리 (기존 학생)
        if (textbookAssignments != null &&
            textbookAssignments.containsKey(s.id)) {
          // 이 부분은 기존 진도 데이터 확인이 필요하므로 트랜잭션 수준에서 처리하거나
          // 아래에서 별도로 처리하는 것이 안전합니다.
          // 여기서는 '신규 등록' 시의 교재 할당에 집중하고,
          // 수정 시에는 별도의 로직을 타거나 우선순위를 낮춥니다.
        }
      }
    }

    // 2. 추가 대상 처리
    if (toAdd != null) {
      for (var s in toAdd) {
        final studentDoc = _firestore.collection(_collection).doc();
        batch.set(studentDoc, s.toFirestore());

        // 교재 할당 처리 (신규 학생) - Map 키로 학생 이름 등을 사용
        final key = "${s.name}_${s.grade}_${s.classNumber}";
        if (textbookAssignments != null &&
            textbookAssignments.containsKey(key)) {
          final assignment = textbookAssignments[key]!;
          final progressDoc = _firestore.collection('studentProgress').doc();

          batch.set(progressDoc, {
            'studentId': studentDoc.id,
            'academyId': s.academyId,
            'ownerId': s.ownerId,
            'textbookId': assignment['textbookId'],
            'textbookName': assignment['textbookName'],
            'volumeNumber': assignment['volumeNumber'],
            'totalVolumes': assignment['totalVolumes'],
            'isCompleted': false,
            'startDate': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'isDeleted': false,
          });
        }
      }
    }

    // 3. 삭제(수강종료) 대상 처리
    if (toDelete != null) {
      for (var id in toDelete) {
        final docRef = _firestore.collection(_collection).doc(id);
        if (isPermanent) {
          batch.delete(docRef);
        } else {
          batch.update(docRef, {
            'isDeleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  /// 학생 일괄 업데이트 및 삭제 처리
  Future<void> batchProcessStudents({
    List<StudentModel>? toUpdate,
    List<StudentModel>? toAdd,
    List<String>? toDelete,
    bool isPermanent = false,
    Map<String, Map<String, dynamic>>? textbookAssignments, // [NEW]
  }) async {
    final batch = _firestore.batch();
    await _batchProcessStudents(
      batch,
      toUpdate: toUpdate,
      toAdd: toAdd,
      toDelete: toDelete,
      isPermanent: isPermanent,
      textbookAssignments: textbookAssignments,
    );
    await batch.commit();
  }

  /// 학생 일괄 삭제 (Soft Delete & 이력 종료)
  Future<void> deleteStudents(List<String> studentIds) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (var id in studentIds) {
      final docRef = _firestore.collection(_collection).doc(id);
      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final historyData = data['enrollmentHistory'] as List? ?? [];
        final List<EnrollmentPeriod> history = historyData
            .map((e) => EnrollmentPeriod.fromMap(e as Map<String, dynamic>))
            .toList();

        // 마지막 이력이 열려있다면 오늘로 닫아줌
        if (history.isNotEmpty && history.last.endDate == null) {
          final last = history.last;
          history[history.length - 1] = EnrollmentPeriod(
            startDate: last.startDate,
            endDate: now,
          );
        }

        batch.update(docRef, {
          'isDeleted': true,
          'deletedAt': Timestamp.fromDate(now),
          'enrollmentHistory': history.map((e) => e.toFirestore()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  /// 학생 일괄 이력 업데이트 (재등록 또는 퇴원 예약)
  Future<void> bulkUpdateEnrollmentHistory(
    List<String> studentIds, {
    DateTime? startDate,
    DateTime? endDate,
    int? sessionId,
    bool replaceAll = false, // [NEW] 기존 이력을 무시하고 덮어쓸지 여부
  }) async {
    final batch = _firestore.batch();

    for (var id in studentIds) {
      final docRef = _firestore.collection(_collection).doc(id);
      final snapshot = await docRef.get();
      if (!snapshot.exists) continue;

      final data = snapshot.data()!;

      // 1. 수강 이력(enrollmentHistory) 업데이트
      final historyData = data['enrollmentHistory'] as List? ?? [];
      final List<EnrollmentPeriod> history = historyData
          .map((e) => EnrollmentPeriod.fromMap(e as Map<String, dynamic>))
          .toList();

      if (startDate != null) {
        if (replaceAll) {
          // [NEW] 기존 이력을 모두 지우고 새 시작일로 초기화 (최초 등록 보정용)
          history.clear();
          history.add(EnrollmentPeriod(startDate: startDate));
        } else {
          // [MODIFIED] 이전 이력이 열려있다면 새 시작일 전날로 닫아줌 (데이터 정합성)
          if (history.isNotEmpty && history.last.endDate == null) {
            final last = history.last;
            // 새 시작일이 기존 시작일보다 빠르거나 같으면 기존 것을 덮어씀 (무의미한 1일 미만 이력 발생 방지)
            if (!last.startDate.isBefore(startDate)) {
              history[history.length - 1] = EnrollmentPeriod(
                startDate: startDate,
              );
            } else {
              history[history.length - 1] = EnrollmentPeriod(
                startDate: last.startDate,
                endDate: startDate.subtract(const Duration(days: 1)),
              );
              history.add(EnrollmentPeriod(startDate: startDate));
            }
          } else {
            history.add(EnrollmentPeriod(startDate: startDate));
          }
        }
      } else if (endDate != null) {
        if (history.isEmpty) {
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          history.add(EnrollmentPeriod(startDate: createdAt, endDate: endDate));
        } else {
          final last = history.last;
          history[history.length - 1] = EnrollmentPeriod(
            startDate: last.startDate,
            endDate: endDate,
          );
        }
      }

      // 2. 부 이동 이력(sessionHistory) 업데이트
      final sessionHistoryData = data['sessionHistory'] as List? ?? [];
      final List<SessionHistory> sessionHistory = sessionHistoryData
          .map((e) => SessionHistory.fromMap(e as Map<String, dynamic>))
          .toList();

      Map<String, dynamic> updates = {
        'isDeleted': false,
        'deletedAt': null,
        'enrollmentHistory': history.map((e) => e.toFirestore()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (startDate != null && (sessionId != null || replaceAll)) {
        if (replaceAll) {
          // [NEW] 시작일 정정 시 부 이력도 해당 날짜로 초기화
          sessionHistory.clear();
        }
        final targetSession = sessionId ?? data['session'] as int? ?? 0;
        sessionHistory.add(
          SessionHistory(effectiveDate: startDate, sessionId: targetSession),
        );
        updates['sessionHistory'] = sessionHistory
            .map((e) => e.toFirestore())
            .toList();
        updates['session'] = targetSession;
      }

      batch.update(docRef, updates);
    }

    await batch.commit();
  }

  /// 학생 복구 (Simple Restore)
  Future<void> restoreStudent(String studentId) async {
    await _firestore.collection(_collection).doc(studentId).update({
      'isDeleted': false,
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 학생 재등록 (이력 동반 복구)
  Future<void> reEnrollStudent(String studentId, DateTime startDate) async {
    final docRef = _firestore.collection(_collection).doc(studentId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final historyData = data['enrollmentHistory'] as List? ?? [];

    // 신규 수강 기간 생성
    final newPeriod = EnrollmentPeriod(startDate: startDate).toFirestore();
    final updatedHistory = List.from(historyData)..add(newPeriod);

    await docRef.update({
      'isDeleted': false,
      'deletedAt': null,
      'enrollmentHistory': updatedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 학생 일괄 이동 (부 이동)
  Future<void> moveStudents(
    List<String> studentIds,
    int targetSession, {
    DateTime? effectiveDate,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final effective = (effectiveDate ?? now).startOfDay;

    for (var id in studentIds) {
      final docRef = _firestore.collection(_collection).doc(id);
      final snapshot = await docRef.get();
      if (!snapshot.exists) continue;

      final data = snapshot.data()!;
      final historyData = data['sessionHistory'] as List? ?? [];
      final history = historyData
          .map((e) => SessionHistory.fromMap(e as Map<String, dynamic>))
          .toList();

      // 동일한 일자에 이미 기록이 있다면 업데이트, 없으면 추가
      final existingIndex = history.indexWhere(
        (h) => h.effectiveDate.startOfDay.isAtSameMomentAs(effective),
      );

      if (existingIndex >= 0) {
        history[existingIndex] = SessionHistory(
          effectiveDate: effective,
          sessionId: targetSession,
        );
      } else {
        history.add(
          SessionHistory(effectiveDate: effective, sessionId: targetSession),
        );
      }

      // 날짜 순으로 정렬 유지
      history.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

      batch.update(docRef, {
        'session': targetSession,
        'sessionHistory': history.map((e) => e.toFirestore()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// 30일이 지난 삭제된 학생 데이터 영구 삭제
  Future<void> purgeOldDeletedStudents() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await _firestore
        .collection(_collection)
        .where('isDeleted', isEqualTo: true)
        .where('deletedAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// 기존 데이터 이력 기반 마이그레이션 (EnrollmentHistory, SessionHistory 초기화)
  Future<int> migrateHistoryData(
    String academyId, {
    required String ownerId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('academyId', isEqualTo: academyId)
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final batch = _firestore.batch();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final eHistory = data['enrollmentHistory'] as List?;

      final currentSession = data['session'] as int? ?? 0;
      final sessionHistoryData = data['sessionHistory'] as List? ?? [];

      // 1. 수강 이력이 아예 없는 경우 초기화
      if (eHistory == null || eHistory.isEmpty) {
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2024, 1, 1);
        final isDeleted = data['isDeleted'] as bool? ?? false;
        final deletedAt = (data['deletedAt'] as Timestamp?)?.toDate();

        // [CRITICAL FIX] 세션 이력이 있다면 무조건 그 중 가장 빠른 날짜를 수강 시작일로 사용
        DateTime enrollmentStart = createdAt;
        if (sessionHistoryData.isNotEmpty) {
          final sortedSessions = List.from(sessionHistoryData);
          sortedSessions.sort(
            (a, b) => (a['effectiveDate'] as Timestamp).compareTo(
              b['effectiveDate'] as Timestamp,
            ),
          );

          final firstSessionDate =
              (sortedSessions.first['effectiveDate'] as Timestamp).toDate();

          // 세션 이력에 존재하는 날짜(미래 시작일 등)를 신뢰함
          enrollmentStart = firstSessionDate;
        }

        final enrollment = [
          {
            'startDate': Timestamp.fromDate(enrollmentStart),
            'endDate': isDeleted
                ? (deletedAt != null ? Timestamp.fromDate(deletedAt) : null)
                : null,
          },
        ];

        final sessions = [
          {
            'effectiveDate': Timestamp.fromDate(enrollmentStart),
            'sessionId': currentSession,
          },
        ];

        batch.update(doc.reference, {
          'enrollmentHistory': enrollment,
          'sessionHistory': sessions,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
      // 2. 이력이 이미 있는 경우, 현재 시점(오늘) 기준의 정확한 부 정보를 'session' 필드에 캐싱
      else {
        var student = StudentModel.fromFirestore(doc);

        // [CLEANUP] 이전 마이그레이션 실수 및 중복 데이터 보정
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          DateTime? futureStart;

          // 세션 이력 중 가장 빠른 미래 날짜 탐색
          final sortedSess = List<SessionHistory>.from(student.sessionHistory);
          sortedSess.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
          for (var s in sortedSess) {
            if (s.effectiveDate.isAfter(createdAt)) {
              futureStart = s.effectiveDate;
              break;
            }
          }

          if (futureStart != null) {
            // 수강 이력이 오늘 날짜로 잘못 잡혀 있다면 교정/삭제
            var newEnroll = List<EnrollmentPeriod>.from(
              student.enrollmentHistory,
            );
            bool modified = false;
            final bogusIdx = newEnroll.indexWhere(
              (e) => e.startDate.isSameDay(createdAt),
            );

            if (bogusIdx != -1) {
              if (newEnroll.length == 1) {
                newEnroll[0] = newEnroll[0].copyWith(startDate: futureStart);
              } else {
                newEnroll.removeAt(bogusIdx);
              }
              modified = true;
            }

            if (modified) {
              batch.update(doc.reference, {
                'enrollmentHistory': newEnroll
                    .map((e) => e.toFirestore())
                    .toList(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              count++;
              student = student.copyWith(enrollmentHistory: newEnroll);
            }
          }
        }

        final correctSession = student.getSessionAt(DateTime.now()) ?? 0;
        bool needsUpdate = (currentSession != correctSession);

        if (!needsUpdate && sessionHistoryData.isNotEmpty) {
          final lastSessionData =
              sessionHistoryData.last as Map<String, dynamic>;
          final lastSessionId =
              (lastSessionData['sessionId'] as num?)?.toInt() ?? 0;
          if (lastSessionId != currentSession && currentSession != 0) {
            needsUpdate = true;
          }
        }

        if (needsUpdate) {
          final now = DateTime.now();
          final updatedSessions = List.from(sessionHistoryData);

          // 오늘 날짜 기준의 실제 세션이 이력의 마지막과 다르면 업데이트/추가
          final today = DateTime(now.year, now.month, now.day);
          bool foundToday = false;
          for (int i = 0; i < updatedSessions.length; i++) {
            final date = (updatedSessions[i]['effectiveDate'] as Timestamp)
                .toDate();
            if (date.year == today.year &&
                date.month == today.month &&
                date.day == today.day) {
              updatedSessions[i]['sessionId'] = correctSession;
              foundToday = true;
              break;
            }
          }

          if (!foundToday && correctSession != 0) {
            updatedSessions.add({
              'effectiveDate': Timestamp.fromDate(now),
              'sessionId': correctSession,
            });
          }

          batch.update(doc.reference, {
            'session': correctSession, // 캐싱: 최상위 필드 업데이트
            'sessionHistory': updatedSessions,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          count++;
        }
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('이력 마이그레이션 완료: $count 명의 학생 데이터 최신화됨');
    }
    return count;
  }
}
