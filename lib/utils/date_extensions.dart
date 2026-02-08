import 'package:intl/intl.dart';

/// DateTime 관련 기능 확장을 위한 익스텐션
extension DateTimeRefactoring on DateTime {
  /// Firestore 문서 ID 생성용 (YYYYMMDD)
  /// 예: 2024년 2월 8일 -> "20240208"
  /// 기존 로직과의 정합성을 위해 padLeft(2, '0')를 사용합니다.
  String toId() {
    return "${year}${month.toString().padLeft(2, '0')}${day.toString().padLeft(2, '0')}";
  }

  /// 화면 표시용 문자열 변환 (YYYY-MM-DD)
  String toDisplayString() {
    return DateFormat('yyyy-MM-dd').format(this);
  }

  /// 화면 표시용 문자열 변환 (MM월 DD일)
  String toKoreanDisplay() {
    return DateFormat('M월 d일').format(this);
  }

  /// 같은 날짜인지 확인 (연, 월, 일만 비교)
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// 해당 날짜의 시작 시간(00:00:00) 반환
  DateTime get startOfDay => DateTime(year, month, day);
}
