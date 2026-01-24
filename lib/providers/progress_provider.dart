import 'package:flutter/material.dart';
import '../models/textbook_model.dart';
import '../models/student_progress_model.dart';
import '../services/textbook_service.dart';
import '../services/progress_service.dart';

/// 교재 및 진도 상태 관리 Provider (커스텀 데이터 대응)
class ProgressProvider with ChangeNotifier {
  final TextbookService _textbookService = TextbookService();
  final ProgressService _progressService = ProgressService();

  List<TextbookModel> _allOwnerTextbooks = [];
  Map<String, List<StudentProgressModel>> _studentProgressMap =
      {}; // Key: studentId

  bool _isLoading = false;
  String? _errorMessage;

  List<TextbookModel> get allOwnerTextbooks => _allOwnerTextbooks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 선생님별 교재 목록 로드
  Future<void> loadOwnerTextbooks(String ownerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allOwnerTextbooks = await _textbookService.getOwnerTextbooks(ownerId);
    } catch (e) {
      _errorMessage = '교재 목록을 불러오지 못했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 새로운 교재 시리즈 등록 (선생님 소유)
  Future<bool> registerTextbook({
    required String ownerId,
    required String name,
    required int totalVolumes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final textbook = TextbookModel(
        id: '',
        ownerId: ownerId,
        name: name,
        totalVolumes: totalVolumes,
        createdAt: DateTime.now(),
      );

      await _textbookService.createTextbook(textbook);
      await loadOwnerTextbooks(ownerId);
      return true;
    } catch (e) {
      print('교재 등록 에러 상세: $e');
      _errorMessage = '교재 등록 실패: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 기존 교재 수정
  Future<bool> editTextbook({
    required String textbookId,
    required String ownerId,
    required String name,
    required int totalVolumes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _textbookService.updateTextbook(textbookId, {
        'name': name,
        'totalVolumes': totalVolumes,
      });
      await loadOwnerTextbooks(ownerId);
      return true;
    } catch (e) {
      _errorMessage = '교재 수정 실패: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 교재 삭제
  Future<bool> deleteAcademyTextbook(String textbookId, String ownerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _textbookService.deleteTextbook(textbookId);
      await loadOwnerTextbooks(ownerId);
      return true;
    } catch (e) {
      _errorMessage = '교재 삭제 실패: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 학생별 진도 목록 로드
  Future<void> loadStudentProgress(String studentId, {String? ownerId}) async {
    try {
      final progressList = await _progressService.getStudentProgress(
        studentId,
        ownerId,
      );
      _studentProgressMap[studentId] = progressList;
    } catch (e) {
      _errorMessage = '학생 진도 정보를 불러오지 못했습니다: $e';
    } finally {
      notifyListeners();
    }
  }

  List<StudentProgressModel> getProgressForStudent(String studentId) {
    return _studentProgressMap[studentId] ?? [];
  }

  /// 특정 권수 할당
  Future<bool> assignVolume({
    required String studentId,
    required String academyId,
    required String ownerId,
    required TextbookModel textbook,
    required int volumeNumber,
    required int totalPages,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final progress = StudentProgressModel(
        id: '',
        studentId: studentId,
        academyId: academyId,
        ownerId: ownerId,
        textbookId: textbook.id,
        textbookName: textbook.name,
        volumeNumber: volumeNumber,
        currentPage: 0,
        totalPages: totalPages,
        startDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _progressService.startProgress(progress);
      await loadStudentProgress(studentId, ownerId: ownerId);
      return true;
    } catch (e) {
      _errorMessage = '교재 할당에 실패했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 진도 업데이트
  Future<bool> updateCurrentPage(
    String progressId,
    String studentId,
    int newPage,
    int totalPages,
  ) async {
    try {
      final isCompleted = newPage >= totalPages;
      await _progressService.updateProgress(progressId, newPage, isCompleted);
      await loadStudentProgress(studentId);
      return true;
    } catch (e) {
      _errorMessage = '진도 업데이트 실패: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// 진도 기록 삭제
  Future<bool> removeProgress(String progressId, String studentId) async {
    try {
      await _progressService.deleteProgress(progressId);
      await loadStudentProgress(studentId);
      return true;
    } catch (e) {
      _errorMessage = '기록 삭제 실패: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }
}
