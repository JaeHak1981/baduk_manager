class HolidayHelper {
  // 매년 고정된 공휴일
  static const Map<String, String> _fixedHolidays = {
    '01-01': '신정',
    '03-01': '삼일절',
    '05-05': '어린이날',
    '06-06': '현충일',
    '08-15': '광복절',
    '10-03': '개천절',
    '10-09': '한글날',
    '12-25': '성탄절',
  };

  // 연도별 변동 공휴일 (설날, 추석, 대체공휴일 등)
  static final Map<int, Map<String, String>> _variableHolidays = {
    2024: {
      '02-09': '설날',
      '02-10': '설날',
      '02-11': '설날',
      '02-12': '대체공휴일',
      '04-10': '국회의원선거',
      '05-06': '대체공휴일',
      '05-15': '부처님오신날',
      '09-16': '추석',
      '09-17': '추석',
      '09-18': '추석',
    },
    2025: {
      '01-28': '설날',
      '01-29': '설날',
      '01-30': '설날',
      '03-03': '대체공휴일',
      '05-05': '부처님오신날',
      '05-06': '대체공휴일',
      '10-05': '추석',
      '10-06': '추석',
      '10-07': '추석',
      '10-08': '대체공휴일',
    },
    2026: {
      '02-16': '설날',
      '02-17': '설날',
      '02-18': '설날',
      '03-02': '대체공휴일',
      '05-24': '부처님오신날',
      '05-25': '대체공휴일',
      '09-24': '추석',
      '09-25': '추석',
      '09-26': '추석',
      '09-28': '대체공휴일',
    },
  };

  /// 특정 날짜가 공휴일인지 확인하고 공휴일명을 반환 (없으면 null)
  static String? getHolidayName(DateTime date) {
    final key =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 1. 고정 공휴일 체크
    if (_fixedHolidays.containsKey(key)) {
      return _fixedHolidays[key];
    }

    // 2. 변동 공휴일 체크
    if (_variableHolidays.containsKey(date.year)) {
      if (_variableHolidays[date.year]!.containsKey(key)) {
        return _variableHolidays[date.year]![key];
      }
    }

    return null;
  }

  static bool isHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }
}
