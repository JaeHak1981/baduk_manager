import 'package:flutter/material.dart';
import '../models/academy_schedule_model.dart';
import '../services/schedule_service.dart';

class ScheduleProvider with ChangeNotifier {
  final ScheduleService _service = ScheduleService();

  AcademyScheduleModel? _currentMonthSchedule;
  bool _isLoading = false;

  AcademyScheduleModel? get currentMonthSchedule => _currentMonthSchedule;
  bool get isLoading => _isLoading;

  /// 특정 월의 스케줄 로드
  Future<void> loadSchedule({
    required String academyId,
    required int year,
    required int month,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentMonthSchedule = await _service.getMonthlySchedule(
        academyId: academyId,
        year: year,
        month: month,
      );
    } catch (e) {
      debugPrint('Error loading schedule: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 휴강 설정/해제
  Future<void> toggleHoliday({
    required String academyId,
    required int year,
    required int month,
    required int day,
    String reason = '휴강', // 기본 사유
  }) async {
    // 낙관적 업데이트 (Optimistic Update)
    Map<int, String> newHolidays;
    if (_currentMonthSchedule != null) {
      newHolidays = Map<int, String>.from(_currentMonthSchedule!.holidays);
    } else {
      newHolidays = {};
    }

    if (newHolidays.containsKey(day)) {
      newHolidays.remove(day);
    } else {
      newHolidays[day] = reason;
    }

    // 임시 객체로 즉시 반영
    _currentMonthSchedule =
        _currentMonthSchedule?.copyWith(holidays: newHolidays) ??
        AcademyScheduleModel(
          id: '', // 임시 ID
          academyId: academyId,
          year: year,
          month: month,
          holidays: newHolidays,
        );
    notifyListeners();

    try {
      // 실제 DB 업데이트 (토글 로직)
      // 위에서 이미 낙관적 업데이트를 했으므로, newHolidays를 기준으로 판단
      final isHoliday = newHolidays.containsKey(day);

      await _service.setHoliday(
        academyId: academyId,
        year: year,
        month: month,
        day: day,
        reason: isHoliday ? reason : null,
      );

      // DB와 동기화를 위해 다시 로드 (안전하게)
      await loadSchedule(academyId: academyId, year: year, month: month);
    } catch (e) {
      debugPrint('Error toggling holiday: $e');
      // 에러 시 롤백 로직이 필요할 수 있음
      await loadSchedule(academyId: academyId, year: year, month: month);
    }
  }

  /// 특정 날짜가 휴강인지 확인
  bool isHoliday(int day) {
    return _currentMonthSchedule?.holidays.containsKey(day) ?? false;
  }

  /// 특정 날짜가 휴강인지 확인 (DateTime)
  bool isDateHoliday(DateTime date) {
    if (_currentMonthSchedule == null) return false;
    if (_currentMonthSchedule!.year != date.year ||
        _currentMonthSchedule!.month != date.month)
      return false;
    return _currentMonthSchedule!.holidays.containsKey(date.day);
  }
}
