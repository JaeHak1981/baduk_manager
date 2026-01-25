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
  bool _isAssigning = false;
  String? _errorMessage;

  List<TextbookModel> get allOwnerTextbooks => _allOwnerTextbooks;
  bool get isLoading => _isLoading;
  bool get isAssigning => _isAssigning;
  String? get errorMessage => _errorMessage;

  /// 선생님별 교재 목록 로드
  Future<void> loadOwnerTextbooks(String ownerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final textbooks = await _textbookService.getOwnerTextbooks(ownerId);
      // 메모리에서 정렬
      textbooks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _allOwnerTextbooks = textbooks;
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

  /// 기관의 모든 학생 진도 로드 (Bulk Load)
  Future<void> loadAcademyProgress(String academyId) async {
    // 이미 로딩 중이면 스킵? 아니면 강제 리로드? -> 강제 리로드 필요
    // _isLoading = true; // 부분 로딩 시 UI 깜빡임 방지 위해 true로 설정 안 할 수도 있음
    // notifyListeners();

    try {
      final allProgress = await _progressService.getAcademyProgress(academyId);

      // Map 초기화
      final Map<String, List<StudentProgressModel>> newMap = {};

      for (var p in allProgress) {
        if (!newMap.containsKey(p.studentId)) {
          newMap[p.studentId] = [];
        }
        newMap[p.studentId]!.add(p);
      }

      // 각 학생별 진도 리스트를 날짜순 정렬
      for (var studentId in newMap.keys) {
        newMap[studentId]!.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }

      _studentProgressMap = newMap;
    } catch (e) {
      print('진도 데이터 로드 실패: $e');
      // _errorMessage = ... (Global error triggers snackbar usually)
    } finally {
      notifyListeners();
    }
  }

  /// 학생별 진도 목록 로드 (개별 리프레시용)
  Future<void> loadStudentProgress(String studentId, {String? ownerId}) async {
    try {
      final progressList = await _progressService.getStudentProgress(
        studentId,
        ownerId,
      );
      // 메모리에서 정렬 (Firestore 인덱스 이슈 방지)
      progressList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _studentProgressMap[studentId] = progressList;
    } catch (e) {
      print('loadStudentProgress 에러: $e');
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
  }) async {
    _isAssigning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print(
        'DEBUG: assignVolume 시작 - studentId: $studentId, textbook: ${textbook.name}',
      );
      final progress = StudentProgressModel(
        id: '',
        studentId: studentId,
        academyId: academyId,
        ownerId: ownerId,
        textbookId: textbook.id,
        textbookName: textbook.name,
        volumeNumber: volumeNumber,
        totalVolumes: textbook.totalVolumes,
        startDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _progressService.startProgress(progress);
      print('DEBUG: startProgress 성공');

      await loadStudentProgress(studentId, ownerId: ownerId);
      print('DEBUG: loadStudentProgress 성공');

      return true;
    } catch (e) {
      print('DEBUG: assignVolume 실패: $e');
      _errorMessage = '교재 할당에 실패했습니다: $e';
      return false;
    } finally {
      _isAssigning = false;
      notifyListeners();
    }
  }

  /// 진도 상태 업데이트 (완료 여부)
  Future<bool> updateVolumeStatus(
    String progressId,
    String studentId,
    bool isCompleted,
  ) async {
    try {
      await _progressService.updateStatus(progressId, isCompleted);
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

  /// 진도 권수 수정
  Future<bool> updateVolume(
    String progressId,
    String studentId,
    int newVolume,
  ) async {
    try {
      await _progressService.updateVolume(progressId, newVolume);
      await loadStudentProgress(studentId);
      return true;
    } catch (e) {
      _errorMessage = '권수 수정 실패: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// 에러 메시지 초기화
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }
}
