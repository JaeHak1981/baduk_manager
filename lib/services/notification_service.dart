import 'package:url_launcher/url_launcher.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';

/// 알림 및 문자 전송 서비스
class NotificationService {
  /// 출결 알림 문자 전송 (SMS 앱 열기)
  Future<void> sendAttendanceSms({
    required StudentModel student,
    required AttendanceType type,
    required DateTime timestamp,
  }) async {
    if (student.parentPhone == null || student.parentPhone!.isEmpty) {
      throw Exception('학부모 연락처가 없습니다.');
    }

    final String statusStr = _getStatusString(type);
    final String timeStr =
        "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";

    // 메시지 템플릿
    final String message =
        "[바둑학원] ${student.name} 학생이 $timeStr에 $statusStr 하였습니다.";

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: student.parentPhone,
      queryParameters: <String, String>{'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      throw Exception('SMS 앱을 열 수 없습니다.');
    }
  }

  String _getStatusString(AttendanceType type) {
    switch (type) {
      case AttendanceType.present:
        return '출석';
      case AttendanceType.absent:
        return '결석';
      case AttendanceType.late:
        return '지각';
      case AttendanceType.manual:
        return '등원';
    }
  }
}
