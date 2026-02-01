import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/education_report_model.dart';

class LocalStorageService {
  static const String _layoutKeyPrefix = 'student_layout_';
  static const String _chartTypeKeyPrefix = 'student_chart_type_';
  static const String _detailTypeKeyPrefix = 'student_detail_type_';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _getInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 특정 학생의 레이아웃 정보 저장
  Future<void> saveStudentLayout(
    String studentId,
    Map<String, WidgetLayout> layout,
  ) async {
    final prefs = await _getInstance;
    final key = '$_layoutKeyPrefix$studentId';

    // Map<String, WidgetLayout> -> Map<String, dynamic> -> JSON String
    final jsonMap = layout.map((k, v) => MapEntry(k, v.toMap()));
    final jsonString = jsonEncode(jsonMap);

    await prefs.setString(key, jsonString);
  }

  /// 특정 학생의 레이아웃 정보 로드
  Future<Map<String, WidgetLayout>> getStudentLayout(String studentId) async {
    final prefs = await _getInstance;
    final key = '$_layoutKeyPrefix$studentId';

    final jsonString = prefs.getString(key);
    if (jsonString == null) return {};

    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, WidgetLayout.fromMap(v as Map<String, dynamic>)),
      );
    } catch (e) {
      // 파싱 에러 시 빈 맵 반환 (데이터 손상 대비)
      return {};
    }
  }

  /// 특정 학생의 차트 타입 저장
  Future<void> saveStudentChartType(
    String studentId,
    BalanceChartType type,
  ) async {
    final prefs = await _getInstance;
    final key = '$_chartTypeKeyPrefix$studentId';
    await prefs.setString(key, type.name);
  }

  /// 특정 학생의 차트 타입 로드
  Future<BalanceChartType?> getStudentChartType(String studentId) async {
    final prefs = await _getInstance;
    final key = '$_chartTypeKeyPrefix$studentId';
    final name = prefs.getString(key);
    if (name == null) return null;

    try {
      return BalanceChartType.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 특정 학생의 상세 보기 타입 저장
  Future<void> saveStudentDetailType(
    String studentId,
    DetailViewType type,
  ) async {
    final prefs = await _getInstance;
    final key = '$_detailTypeKeyPrefix$studentId';
    await prefs.setString(key, type.name);
  }

  /// 특정 학생의 상세 보기 타입 로드
  Future<DetailViewType?> getStudentDetailType(String studentId) async {
    final prefs = await _getInstance;
    final key = '$_detailTypeKeyPrefix$studentId';
    final name = prefs.getString(key);
    if (name == null) return null;

    try {
      return DetailViewType.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 레이아웃 정보 삭제 (초기화 시 사용)
  Future<void> clearStudentLayout(String studentId) async {
    final prefs = await _getInstance;
    final key = '$_layoutKeyPrefix$studentId';
    await prefs.remove(key);
  }
}
