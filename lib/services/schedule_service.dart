import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academy_schedule_model.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 월별 스케줄 가져오기 (없으면 null 반환)
  Future<AcademyScheduleModel?> getMonthlySchedule({
    required String academyId,
    required int year,
    required int month,
  }) async {
    final snapshot = await _firestore
        .collection('academies')
        .doc(academyId)
        .collection('schedules')
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return AcademyScheduleModel.fromFirestore(snapshot.docs.first);
  }

  /// 스케줄 저장 (없으면 생성, 있으면 업데이트)
  Future<void> saveSchedule(AcademyScheduleModel schedule) async {
    final collection = _firestore
        .collection('academies')
        .doc(schedule.academyId)
        .collection('schedules');

    if (schedule.id.isEmpty) {
      // ID가 없으면 쿼리로 먼저 찾음 (중복 생성 방지)
      final existing = await getMonthlySchedule(
        academyId: schedule.academyId,
        year: schedule.year,
        month: schedule.month,
      );

      if (existing != null) {
        await collection.doc(existing.id).update(schedule.toFirestore());
      } else {
        await collection.add(schedule.toFirestore());
      }
    } else {
      await collection.doc(schedule.id).set(schedule.toFirestore());
    }
  }

  /// 특정 날짜 휴강 설정/해제
  Future<void> setHoliday({
    required String academyId,
    required int year,
    required int month,
    required int day,
    required String? reason, // null이면 휴강 해제
  }) async {
    final currentSchedule = await getMonthlySchedule(
      academyId: academyId,
      year: year,
      month: month,
    );

    final holidays = currentSchedule != null
        ? Map<int, String>.from(currentSchedule.holidays)
        : <int, String>{};

    if (reason == null) {
      holidays.remove(day);
    } else {
      holidays[day] = reason;
    }

    final newSchedule =
        currentSchedule?.copyWith(
          holidays: holidays,
          updatedAt: DateTime.now(),
        ) ??
        AcademyScheduleModel(
          id: '',
          academyId: academyId,
          year: year,
          month: month,
          holidays: holidays,
          updatedAt: DateTime.now(),
        );

    await saveSchedule(newSchedule);
  }

  /// 여러 날짜를 한 번에 휴강 설정/해제
  Future<void> setHolidayBatch({
    required String academyId,
    required List<DateTime> dates,
    required String? reason, // null이면 휴강 해제
  }) async {
    // 1. 월별로 날짜 그룹화
    final Map<String, List<int>> monthlyGroups = {}; // Key: "year_month"
    for (var date in dates) {
      final key = "${date.year}_${date.month}";
      monthlyGroups.putIfAbsent(key, () => []).add(date.day);
    }

    // 2. 각 월별로 처리
    for (var entry in monthlyGroups.entries) {
      final parts = entry.key.split('_');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final days = entry.value;

      final currentSchedule = await getMonthlySchedule(
        academyId: academyId,
        year: year,
        month: month,
      );

      final holidays = currentSchedule != null
          ? Map<int, String>.from(currentSchedule.holidays)
          : <int, String>{};

      for (var day in days) {
        if (reason == null) {
          holidays.remove(day);
        } else {
          holidays[day] = reason;
        }
      }

      final newSchedule =
          currentSchedule?.copyWith(
            holidays: holidays,
            updatedAt: DateTime.now(),
          ) ??
          AcademyScheduleModel(
            id: '',
            academyId: academyId,
            year: year,
            month: month,
            holidays: holidays,
            updatedAt: DateTime.now(),
          );

      await saveSchedule(newSchedule);
    }
  }
}
