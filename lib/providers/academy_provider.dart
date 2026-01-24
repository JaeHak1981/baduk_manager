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

      _academies = await _academyService.getAcademiesByOwner(ownerId);

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

      _academies = await _academyService.getAllAcademies();

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

      await _academyService.updateAcademy(academy);

      final index = _academies.indexWhere((a) => a.id == academy.id);
      if (index != -1) {
        _academies[index] = academy;
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
