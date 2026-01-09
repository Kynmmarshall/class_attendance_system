import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:class_attendance_system/models/student_attendance_status.dart';
import 'package:flutter/foundation.dart';

class GoogleFormService {
  GoogleFormService._();

  static final GoogleFormService instance = GoogleFormService._();

  Future<String?> createCourseAttendanceForm({
    required Course course,
    required Session session,
    required List<StudentAttendanceStatus> statuses,
  }) async {
    debugPrint(
      '🧾 [GoogleFormService] Google Forms export is only available on IO platforms. '
      'Skipped for ${course.courseName}.',
    );
    return null;
  }
}
