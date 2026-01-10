import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:class_attendance_system/models/student_attendance_status.dart';
import 'package:flutter/foundation.dart';

/// Legacy placeholder to keep conditional exports compiling on IO targets.
class GoogleFormService {
  GoogleFormService._();

  static final GoogleFormService instance = GoogleFormService._();

  Future<String?> createCourseAttendanceForm({
    required Course course,
    required Session session,
    required List<StudentAttendanceStatus> statuses,
  }) async {
    debugPrint(
      '🧾 [GoogleFormService] Google Form exports have been replaced by on-device PDFs. '
      'No external form will be created for ${course.courseName}.',
    );
    return null;
  }
}
