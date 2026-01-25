class HolidayHelper {
  static final Map<String, String> _holidays2026 = {
    '01-01': '신정',
    '02-16': '설날',
    '02-17': '설날',
    '02-18': '설날',
    '03-01': '삼일절',
    '03-02': '대체공휴일(삼일절)',
    '05-05': '어린이날',
    '05-24': '부처님오신날',
    '05-25': '대체공휴일(부처님오신날)',
    '06-06': '현충일',
    '08-15': '광복절',
    '09-24': '추석',
    '09-25': '추석',
    '09-26': '추석',
    '09-28': '대체공휴일(추석)',
    '10-03': '개천절',
    '10-09': '한글날',
    '12-25': '성탄절',
  };

  /// 특정 날짜가 공휴일인지 확인하고 공휴일명을 반환 (없으면 null)
  static String? getHolidayName(DateTime date) {
    // 2026년 데이터만 하드코딩 (필요시 연도별 확장 가능)
    if (date.year != 2026) {
      // 2026년이 아니면 기본 공휴일만 (매년 고정)
      final fixedKey =
          "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final fixedHolidays = {
        '01-01': '신정',
        '03-01': '삼일절',
        '05-05': '어린이날',
        '06-06': '현충일',
        '08-15': '광복절',
        '10-03': '개천절',
        '10-09': '한글날',
        '12-25': '성탄절',
      };
      return fixedHolidays[fixedKey];
    }

    final key =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _holidays2026[key];
  }

  static bool isHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }
}
