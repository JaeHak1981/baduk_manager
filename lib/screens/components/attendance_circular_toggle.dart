import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../config/app_theme.dart';

class AttendanceCircularToggle extends StatelessWidget {
  final AttendanceProvider provider;
  final String studentId;
  final String academyId;
  final String ownerId;
  final DateTime date;
  final AttendanceRecord? record;

  const AttendanceCircularToggle({
    super.key,
    required this.provider,
    required this.studentId,
    required this.academyId,
    required this.ownerId,
    required this.date,
    this.record,
  });

  @override
  Widget build(BuildContext context) {
    bool isPresent = record?.type == AttendanceType.present;
    bool isAbsent = record?.type == AttendanceType.absent;

    Widget child;
    if (isPresent) {
      child = const Icon(Icons.panorama_fish_eye, color: Colors.blue, size: 20);
    } else if (isAbsent) {
      child = const Text(
        '/',
        style: TextStyle(
          color: Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      child = const SizedBox();
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        provider.toggleStatus(
          studentId: studentId,
          academyId: academyId,
          ownerId: ownerId,
          date: date,
        );
      },
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor, width: 1.0),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Center(child: child),
      ),
    );
  }
}
