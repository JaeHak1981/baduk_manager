import 'package:flutter/foundation.dart';
import '../models/academy_model.dart';
import '../services/academy_service.dart';

/// 기관 관리 Provider
class AcademyProvider extends ChangeNotifier {
  final AcademyService _academyService = AcademyService();

  List<AcademyModel> _academies = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// 기관 목록
  List<AcademyModel> get academies => _academies;

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 기관 생성
  Future<bool> createAcademy({
    required String name,
    required AcademyType type,
    required String ownerId,
    int totalSessions = 1,
    List<int> lessonDays = const [],
    List<String> usingTextbookIds = const [],
    String? phoneNumber,
    String? address,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final academy = await _academyService.createAcademy(
        name: name,
        type: type,
        ownerId: ownerId,
        totalSessions: totalSessions,
        lessonDays: lessonDays,
        usingTextbookIds: usingTextbookIds,
        phoneNumber: phoneNumber,
        address: address,
      );

      _academies.insert(0, academy);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 소유자별 기관 목록 로드
  Future<void> loadAcademiesByOwner(String ownerId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final academies = await _academyService.getAcademiesByOwner(ownerId);
      // 메모리에서 정렬
      academies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _academies = academies;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 모든 기관 로드 (개발자용)
  Future<void> loadAllAcademies() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final academies = await _academyService.getAllAcademies();
      // 메모리에서 정렬
      academies.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _academies = academies;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 기관 수정
  Future<bool> updateAcademy(AcademyModel academy) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updated = await _academyService.updateAcademy(academy);

      final index = _academies.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _academies[index] = updated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 기관 삭제
  Future<bool> deleteAcademy(String academyId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _academyService.deleteAcademy(academyId);

      _academies.removeWhere((a) => a.id == academyId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
