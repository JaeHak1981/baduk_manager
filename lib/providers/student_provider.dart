import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/student_service.dart';

/// 학생 상태 관리 Provider
class StudentProvider with ChangeNotifier {
  final StudentService _studentService = StudentService();

  List<StudentModel> _students = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<StudentModel> get students => _students;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 특정 기관의 학생 목록 로드
  Future<void> loadStudents(String academyId, {String? ownerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _students = await _studentService.getStudentsByAcademy(
        academyId,
        ownerId: ownerId,
      );
    } catch (e) {
      _errorMessage = '학생 목록을 불러오지 못했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 학생 등록 (객체 기반)
  Future<void> addStudent(StudentModel student) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _studentService.createStudent(student);
      await loadStudents(
        student.academyId,
        ownerId: student.ownerId,
      ); // 목록 새로고침
    } catch (e) {
      _errorMessage = '학생 등록에 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 학생 정보 수정 (객체 기반)
  Future<void> updateStudent(StudentModel student) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _studentService.updateStudent(student);
      await loadStudents(
        student.academyId,
        ownerId: student.ownerId,
      ); // 목록 새로고침
    } catch (e) {
      _errorMessage = '학생 정보 수정에 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 학생 삭제
  Future<bool> deleteStudent(
    String studentId, {
    required String academyId,
    required String ownerId,
  }) async {
    try {
      await _studentService.deleteStudent(studentId);
      await loadStudents(academyId, ownerId: ownerId);
      return true;
    } catch (e) {
      _errorMessage = '학생 삭제에 실패했습니다: $e';
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// 학생 일괄 삭제
  Future<bool> deleteStudents(
    List<String> studentIds, {
    required String academyId,
    required String ownerId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _studentService.deleteStudents(studentIds);
      await loadStudents(academyId, ownerId: ownerId); // 목록 새로고침
      return true;
    } catch (e) {
      _errorMessage = '일괄 삭제에 실패했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 학생 일괄 이동
  Future<bool> moveStudents(
    List<String> studentIds,
    int targetSession, {
    required String academyId,
    required String ownerId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _studentService.moveStudents(studentIds, targetSession);
      await loadStudents(academyId, ownerId: ownerId); // 목록 새로고침
      return true;
    } catch (e) {
      _errorMessage = '학생 이동에 실패했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
