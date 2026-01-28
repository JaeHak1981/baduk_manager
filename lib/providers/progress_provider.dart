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
  Future<void> loadAcademyProgress(
    String academyId, {
    required String ownerId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allProgress = await _progressService.getAcademyProgress(
        academyId,
        ownerId: ownerId,
      );

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
      _errorMessage = '진도 데이터를 불러오지 못했습니다: $e';
    } finally {
      _isLoading = false;
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
        'DEBUG: assignVolume 시작 - studentId: $studentId, textbookId: ${textbook.id}, volume: $volumeNumber',
      );

      // 1. 중복 체크: 동일한 교재/권수가 이미 있는지 확인 (완료 여부 상관없이)
      final existingProgress = _studentProgressMap[studentId]
          ?.where(
            (p) =>
                p.textbookId == textbook.id && p.volumeNumber == volumeNumber,
          )
          .toList();

      if (existingProgress != null && existingProgress.isNotEmpty) {
        // 이미 있으므로 신규 할당 없이 업데이트만 수행 (상태 리셋 포함)
        await _progressService.updateVolumeAndResetStatus(
          existingProgress.first.id,
          volumeNumber,
        );
      } else {
        // 2-1. 동일 시리즈 이전 권수 자동 완료 처리
        await _progressService.completePreviousVolumes(
          studentId,
          textbook.id,
          volumeNumber,
          ownerId: ownerId,
        );

        // 2-2. 신규 할당
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

        final newId = await _progressService.startProgress(progress);
        print('DEBUG: startProgress 성공 - New ID: $newId');
      }

      // 3. 개별 학생 정보 즉시 리프레시
      // await loadStudentProgress(studentId, ownerId: ownerId);
      // [FIX] 로컬 데이터 즉시 갱신 (네트워크 지연 대응)
      await loadStudentProgress(studentId, ownerId: ownerId);

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
    bool isCompleted, {
    String? ownerId,
  }) async {
    try {
      await _progressService.updateStatus(progressId, isCompleted);

      // [FIX] 로컬 데이터 즉시 업데이트
      if (_studentProgressMap.containsKey(studentId)) {
        final list = _studentProgressMap[studentId]!;
        final index = list.indexWhere((p) => p.id == progressId);
        if (index != -1) {
          list[index] = list[index].copyWith(
            isCompleted: isCompleted,
            updatedAt: DateTime.now(),
            endDate: isCompleted ? DateTime.now() : null,
          );
        }
      }

      notifyListeners();

      // [FIX] 서버 데이터 동기화 지연 (레이스 컨디션 방지)
      // Firestore 소프트 삭제 후 즉시 조회 시 간혹 이전 데이터가 오는 경우가 있음
      Future.delayed(const Duration(milliseconds: 500), () {
        loadStudentProgress(studentId, ownerId: ownerId);
      });

      return true;
    } catch (e) {
      print('DEBUG: updateVolumeStatus 실패: $e');
      _errorMessage = '진도 업데이트 실패: $e';
      notifyListeners();
      return false;
    }
  }

  /// 진도 기록 삭제 (Soft Delete)
  Future<bool> removeProgress(
    String progressId,
    String studentId, {
    String? ownerId,
  }) async {
    try {
      debugPrint('🔥🔥🔥 [SUPER_DEBUG] ProgressProvider.removeProgress START');
      debugPrint('🔥🔥🔥 [SUPER_DEBUG] progressId: $progressId');
      debugPrint('🔥🔥🔥 [SUPER_DEBUG] studentId: $studentId');
      debugPrint('🔥🔥🔥 [SUPER_DEBUG] ownerId: $ownerId');

      await _progressService.deleteProgress(progressId);
      debugPrint('🔥🔥🔥 [SUPER_DEBUG] ProgressService.deleteProgress SUCCESS');

      // [FIX] 로컬 데이터에서 즉시 삭제
      if (_studentProgressMap.containsKey(studentId)) {
        final initialCount = _studentProgressMap[studentId]!.length;
        _studentProgressMap[studentId]!.removeWhere((p) => p.id == progressId);
        debugPrint(
          '🔥🔥🔥 [SUPER_DEBUG] Local data removed. Count: $initialCount -> ${_studentProgressMap[studentId]!.length}',
        );
      } else {
        debugPrint(
          '🔥🔥🔥 [SUPER_DEBUG] NO studentId in local map: $studentId',
        );
      }

      notifyListeners();

      // [FIX] 서버 데이터 동기화 지연
      Future.delayed(const Duration(milliseconds: 800), () {
        debugPrint('🔥🔥🔥 [SUPER_DEBUG] Running background refresh');
        loadStudentProgress(studentId, ownerId: ownerId);
      });

      return true;
    } catch (e, stack) {
      debugPrint('❌❌❌ [SUPER_DEBUG] ProgressProvider.removeProgress ERROR: $e');
      debugPrint('❌❌❌ [SUPER_DEBUG] STACK: $stack');
      _errorMessage = '기록 삭제 실패: $e';
      notifyListeners();
      return false;
    }
  }

  /// 진도 기록 복원 (완료 -> 진행 중)
  Future<bool> restoreProgress(
    String progressId,
    String studentId, {
    String? ownerId,
  }) async {
    try {
      await _progressService.restoreProgress(progressId);
      await loadStudentProgress(studentId, ownerId: ownerId);
      return true;
    } catch (e) {
      _errorMessage = '진도 복원 실패: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// 진도 권수 수정
  Future<bool> updateVolume(
    String progressId,
    String studentId,
    int newVolume, {
    String? ownerId,
  }) async {
    try {
      await _progressService.updateVolume(progressId, newVolume);

      // [FIX] 로컬 데이터 즉시 업데이트
      if (_studentProgressMap.containsKey(studentId)) {
        final list = _studentProgressMap[studentId]!;
        final index = list.indexWhere((p) => p.id == progressId);
        if (index != -1) {
          list[index] = list[index].copyWith(
            volumeNumber: newVolume,
            updatedAt: DateTime.now(),
          );
        }
      }

      notifyListeners();
      await loadStudentProgress(studentId, ownerId: ownerId);
      return true;
    } catch (e) {
      _errorMessage = '권수 수정 실패: $e';
      notifyListeners();
      return false;
    }
  }

  /// 에러 메시지 초기화
  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }
}
