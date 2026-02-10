import '../models/student_model.dart';
import '../services/student_service.dart';
import '../utils/error_handler.dart';
import 'base_provider.dart';

/// 학생 상태 관리 Provider
class StudentProvider extends BaseProvider {
  final StudentService _studentService = StudentService();

  List<StudentModel> _students = [];
  bool _showDeleted = false; // 종료생 보기 여부

  // 마이그레이션 중복 실행 방지를 위한 캐시
  static final Set<String> _migratedAcademies = {};

  List<StudentModel> get students => _showDeleted
      ? _students.where((s) => s.isDeleted).toList()
      : _students.where((s) => !s.isDeleted).toList();

  List<StudentModel> get allStudents => _students;
  bool get showDeleted => _showDeleted;

  /// 종료생 보기 토글
  void toggleShowDeleted() {
    _showDeleted = !_showDeleted;
    notifyListeners();
  }

  /// 특정 기관의 학생 목록 로드
  Future<void> loadStudents(String academyId, {String? ownerId}) async {
    await runAsync(() async {
      // 1. 기존 데이터 마이그레이션 체크 및 실행 (세션당 학원별 1회만)
      if (!_migratedAcademies.contains(academyId)) {
        await _studentService.migrateHistoryData(
          academyId,
          ownerId: ownerId ?? '',
        );
        _migratedAcademies.add(academyId);
      }

      // 2. 학생 목록 로드
      _students = await _studentService.getStudentsByAcademy(
        academyId,
        ownerId: ownerId,
      );
    });
  }

  /// 학생 등록
  Future<void> addStudent(StudentModel student) async {
    await runAsync(() async {
      try {
        await _studentService.createStudent(student);
        await loadStudents(student.academyId, ownerId: student.ownerId);
        AppErrorHandler.showSnackBar('학생이 등록되었습니다.', isError: false);
      } catch (e) {
        AppErrorHandler.handle(
          e,
          customMessage: '학생 등록에 실패했습니다.',
          onRetry: () => addStudent(student),
        );
      }
    });
  }

  /// 학생 정보 수정
  Future<void> updateStudent(StudentModel student) async {
    await runAsync(() async {
      try {
        await _studentService.updateStudent(student);
        await loadStudents(student.academyId, ownerId: student.ownerId);
        AppErrorHandler.showSnackBar('학생 정보가 수정되었습니다.', isError: false);
      } catch (e) {
        AppErrorHandler.handle(
          e,
          customMessage: '학생 정보 수정에 실패했습니다.',
          onRetry: () => updateStudent(student),
        );
      }
    });
  }

  /// 학생 삭제
  Future<bool> deleteStudent(
    String studentId, {
    required String academyId,
    required String ownerId,
  }) async {
    return await runAsync(() async {
          try {
            await _studentService.deleteStudent(studentId);
            await loadStudents(academyId, ownerId: ownerId);
            AppErrorHandler.showSnackBar('학생이 삭제되었습니다.', isError: false);
            return true;
          } catch (e) {
            AppErrorHandler.handle(
              e,
              customMessage: '학생 삭제에 실패했습니다.',
              onRetry: () => deleteStudent(
                studentId,
                academyId: academyId,
                ownerId: ownerId,
              ),
            );
            return false;
          }
        }) ??
        false;
  }

  /// 학생 일괄 삭제
  Future<bool> deleteStudents(
    List<String> studentIds, {
    required String academyId,
    required String ownerId,
  }) async {
    return await runAsync(() async {
          try {
            await _studentService.deleteStudents(studentIds);
            await loadStudents(academyId, ownerId: ownerId);
            AppErrorHandler.showSnackBar('선택한 학생이 삭제되었습니다.', isError: false);
            return true;
          } catch (e) {
            AppErrorHandler.handle(e, customMessage: '학생 일괄 삭제에 실패했습니다.');
            return false;
          }
        }) ??
        false;
  }

  /// 학생 일괄 이동
  Future<bool> moveStudents(
    List<String> studentIds,
    int targetSession, {
    required String academyId,
    required String ownerId,
  }) async {
    return await runAsync(() async {
          try {
            await _studentService.moveStudents(studentIds, targetSession);
            await loadStudents(academyId, ownerId: ownerId);
            final sessionName = targetSession == 0 ? "미배정" : "$targetSession부";
            AppErrorHandler.showSnackBar(
              '학생들이 $sessionName로 이동되었습니다.',
              isError: false,
            );
            return true;
          } catch (e) {
            AppErrorHandler.handle(e, customMessage: '학생 이동에 실패했습니다.');
            return false;
          }
        }) ??
        false;
  }

  /// 학생 일괄 처리 (등록/수정/종료)
  Future<bool> batchProcessStudents({
    List<StudentModel>? toUpdate,
    List<StudentModel>? toAdd,
    List<String>? toDelete,
    required String academyId,
    required String ownerId,
  }) async {
    return await runAsync(() async {
          try {
            await _studentService.batchProcessStudents(
              toUpdate: toUpdate,
              toAdd: toAdd,
              toDelete: toDelete,
            );
            await loadStudents(academyId, ownerId: ownerId);
            AppErrorHandler.showSnackBar('일괄 처리가 완료되었습니다.', isError: false);
            return true;
          } catch (e) {
            AppErrorHandler.handle(e, customMessage: '일괄 처리에 실패했습니다.');
            return false;
          }
        }) ??
        false;
  }

  /// 학생 복구 (Simple Restore)
  Future<bool> restoreStudent(
    String studentId, {
    required String academyId,
    required String ownerId,
  }) async {
    return await runAsync(() async {
          try {
            await _studentService.restoreStudent(studentId);
            await loadStudents(academyId, ownerId: ownerId);
            AppErrorHandler.showSnackBar('학생이 복구되었습니다.', isError: false);
            return true;
          } catch (e) {
            AppErrorHandler.handle(e, customMessage: '학생 복구에 실패했습니다.');
            return false;
          }
        }) ??
        false;
  }

  /// 학생 재등록 (이력 기반 복구)
  Future<bool> reEnrollStudent(
    String studentId, {
    required String academyId,
    required String ownerId,
    required DateTime startDate,
  }) async {
    return await runAsync(() async {
          try {
            await _studentService.reEnrollStudent(studentId, startDate);
            await loadStudents(academyId, ownerId: ownerId);
            AppErrorHandler.showSnackBar('학생이 재등록되었습니다.', isError: false);
            return true;
          } catch (e) {
            AppErrorHandler.handle(e, customMessage: '학생 재등록에 실패했습니다.');
            return false;
          }
        }) ??
        false;
  }
}
