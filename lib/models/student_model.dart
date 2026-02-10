import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_extensions.dart';

/// 수강 기간 정보
class EnrollmentPeriod {
  final DateTime startDate;
  final DateTime? endDate;

  EnrollmentPeriod({required this.startDate, this.endDate});

  Map<String, dynamic> toFirestore() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    };
  }

  factory EnrollmentPeriod.fromMap(Map<String, dynamic> map) {
    return EnrollmentPeriod(
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
    );
  }
}

/// 부(Session) 이동 이력
class SessionHistory {
  final DateTime effectiveDate;
  final int sessionId;

  SessionHistory({required this.effectiveDate, required this.sessionId});

  Map<String, dynamic> toFirestore() {
    return {
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'sessionId': sessionId,
    };
  }

  factory SessionHistory.fromMap(Map<String, dynamic> map) {
    return SessionHistory(
      effectiveDate: (map['effectiveDate'] as Timestamp).toDate(),
      sessionId: map['sessionId'] as int,
    );
  }
}

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
  final int? session; // 현재 부 (Legacy 호환용)
  final List<SessionHistory> sessionHistory; // 부 이동 이력
  final List<EnrollmentPeriod> enrollmentHistory; // 수강 이력 (입학/퇴원)
  final int? grade; // 학년
  final String? classNumber; // 반
  final String? studentNumber; // 번호
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted; // 삭제 여부 (Legacy 호환용)
  final DateTime? deletedAt; // 삭제 일시

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
    this.sessionHistory = const [],
    this.enrollmentHistory = const [],
    this.grade,
    this.classNumber,
    this.studentNumber,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
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
      'sessionHistory': sessionHistory.map((e) => e.toFirestore()).toList(),
      'enrollmentHistory': enrollmentHistory
          .map((e) => e.toFirestore())
          .toList(),
      'grade': grade,
      'classNumber': classNumber,
      'studentNumber': studentNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  /// Firestore 문서에서 생성
  factory StudentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;

    var sHistory = <SessionHistory>[];
    if (data['sessionHistory'] != null) {
      sHistory = (data['sessionHistory'] as List)
          .map((e) => SessionHistory.fromMap(e as Map<String, dynamic>))
          .toList();
      sHistory.sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    }

    var eHistory = <EnrollmentPeriod>[];
    if (data['enrollmentHistory'] != null) {
      eHistory = (data['enrollmentHistory'] as List)
          .map((e) => EnrollmentPeriod.fromMap(e as Map<String, dynamic>))
          .toList();
      eHistory.sort((a, b) => a.startDate.compareTo(b.startDate));
    }

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
      sessionHistory: sHistory,
      enrollmentHistory: eHistory,
      grade: data['grade'] as int?,
      classNumber: data['classNumber'] as String?,
      studentNumber: data['studentNumber'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: data['deletedAt'] != null
          ? (data['deletedAt'] as Timestamp).toDate()
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
    List<SessionHistory>? sessionHistory,
    List<EnrollmentPeriod>? enrollmentHistory,
    int? grade,
    String? classNumber,
    String? studentNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
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
      sessionHistory: sessionHistory ?? this.sessionHistory,
      enrollmentHistory: enrollmentHistory ?? this.enrollmentHistory,
      grade: grade ?? this.grade,
      classNumber: classNumber ?? this.classNumber,
      studentNumber: studentNumber ?? this.studentNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// 특정 날짜에 이 학생이 수강 중인지 확인
  bool isEnrolledAt(DateTime date) {
    final target = date.startOfDay;

    // 이력이 없는 경우 (마이그레이션 전) 기존 로직(isDeleted) 참고
    if (enrollmentHistory.isEmpty) {
      if (isDeleted && deletedAt != null) {
        return target.isBefore(deletedAt!.startOfDay);
      }
      return true; // 삭제 안 됐으면 수강 중으로 간주
    }

    for (var period in enrollmentHistory) {
      final start = period.startDate.startOfDay;
      final end = period.endDate?.startOfDay;

      if (!target.isBefore(start)) {
        if (end == null || !target.isAfter(end)) {
          return true;
        }
      }
    }
    return false;
  }

  /// 특정 날짜에 이 학생이 속한 부(Session)를 반환 (Fallback 로직 포함)
  int? getSessionAt(DateTime date) {
    final target = date.startOfDay;

    if (sessionHistory.isEmpty) return session;

    // 해당 날짜 이전 기록 중 가장 최근의 유효한 기록 찾기 (Fallback)
    SessionHistory? latestMatch;
    for (var history in sessionHistory) {
      if (!target.isBefore(history.effectiveDate.startOfDay)) {
        if (latestMatch == null ||
            history.effectiveDate.isAfter(latestMatch.effectiveDate)) {
          latestMatch = history;
        }
      }
    }

    return latestMatch?.sessionId ?? session;
  }

  /// 예약 상태 라벨 반환 ([신입], [퇴원예정] 등)
  String? getStatusLabelAt(DateTime targetMonth) {
    // 1. 신입 예정 체크 (현재 달보다 미래에 수강 시작)
    if (enrollmentHistory.isNotEmpty) {
      final firstStart = enrollmentHistory.first.startDate;
      if (firstStart.year == targetMonth.year &&
          firstStart.month == targetMonth.month) {
        // 이번 달에 시작하는 경우 (신입)
        // 만약 아주 예전에 생성된 거라면 신입이 아닐 수 있음 (여기서는 단순 날짜 비교)
        if (firstStart.isAfter(
          DateTime.now().subtract(const Duration(days: 30)),
        )) {
          return '[신입]';
        }
      }
    }

    // 2. 퇴원 예정 체크 (이번 달 내에 수강 종료일이 있는 경우)
    for (var period in enrollmentHistory) {
      if (period.endDate != null) {
        if (period.endDate!.year == targetMonth.year &&
            period.endDate!.month == targetMonth.month) {
          return '[퇴원예정]';
        }
      }
    }

    return null;
  }

  /// 명단에 표시할 미래 예약 이벤트 라벨 (예: [3/2 재등록], [2/28 퇴원예정])
  String? get nextEventLabel {
    final now = DateTime.now().startOfDay;

    // 1. 퇴원 예약 체크 (현재 이후의 종료일이 있는 경우)
    for (var period in enrollmentHistory) {
      if (period.endDate != null) {
        final end = period.endDate!.startOfDay;
        if (!end.isBefore(now)) {
          return '[${end.month}/${end.day} 퇴원]';
        }
      }
    }

    // 2. 재등록 예약 체크 (현재 이후의 시작일이 있는 경우)
    for (var period in enrollmentHistory) {
      final start = period.startDate.startOfDay;
      if (start.isAfter(now)) {
        return '[${start.month}/${start.day} 재등록]';
      }
    }

    return null;
  }

  /// 상세 예약 정보 (날짜 + 몇 부 이동인지 포함)
  String get reservationDetail {
    final now = DateTime.now().startOfDay;

    // 1. 퇴원 예약 체크 (가장 가까운 미래의 종료일 찾기)
    DateTime? nearestRetire;
    for (var period in enrollmentHistory) {
      if (period.endDate != null) {
        final end = period.endDate!.startOfDay;
        if (!end.isBefore(now)) {
          if (nearestRetire == null || end.isBefore(nearestRetire)) {
            nearestRetire = end;
          }
        }
      }
    }

    // 2. 미래 이벤트(재등록/부이동) 체크
    DateTime? nearestMove;
    int? targetSession;
    String moveType = '재등록';

    // 2-1. 수강 시작일 기준 검색
    for (var period in enrollmentHistory) {
      final start = period.startDate.startOfDay;
      if (start.isAfter(now)) {
        if (nearestMove == null || start.isBefore(nearestMove)) {
          nearestMove = start;
          moveType = '재등록';

          // 해당 날짜에 배정된 부 찾기
          for (var sess in sessionHistory) {
            if (sess.effectiveDate.isSameDay(start)) {
              targetSession = sess.sessionId;
              break;
            }
          }
        }
      }
    }

    // 2-2. 부 이동 이력 기준 검색 (수강 기간 내에서의 부 변경 포함)
    for (var sess in sessionHistory) {
      final effective = sess.effectiveDate.startOfDay;
      if (effective.isAfter(now)) {
        // 이미 더 빠른 수강 시작일 예약이 있다면 무시
        if (nearestMove == null || effective.isBefore(nearestMove)) {
          nearestMove = effective;
          targetSession = sess.sessionId;
          moveType = '부 이동';
        }
      }
    }

    // 3. 우선순위 결정 (가장 가까운 날짜)
    if (nearestRetire != null &&
        (nearestMove == null || nearestRetire.isBefore(nearestMove))) {
      return '${nearestRetire.month}/${nearestRetire.day} 퇴원';
    }

    if (nearestMove != null) {
      final sessionLabel = targetSession != null
          ? (targetSession == 0 ? '(미배정)' : '(${targetSession}부)')
          : '';
      return '${nearestMove.month}/${nearestMove.day}$sessionLabel $moveType';
    }

    // 4. 현재 수강 중 여부 판단
    if (!isDeleted) {
      for (var period in enrollmentHistory) {
        final start = period.startDate.startOfDay;
        final end = period.endDate?.startOfDay;
        if (!start.isAfter(now) && (end == null || !end.isBefore(now))) {
          // 부(Session)가 배정되지 않은 경우 '미배정'으로 표시 (사용자 요청)
          if (session == null || session == 0) {
            return '미배정';
          }
          return '수강 중';
        }
      }
    }

    return '미배정';
  }

  /// 급수 표시 문자열 (예: 30급, 1단)
  String get levelDisplayName {
    // level이 0이거나 데이터가 없는 기존 데이터에 대해 30급을 기본값으로 처리
    if (level == 0) return '30급';

    if (level > 0) {
      return '$level급';
    } else {
      return '${level.abs() + 1}단';
    }
  }
}
