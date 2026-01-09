import 'dart:convert';
import 'dart:io';

import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:class_attendance_system/models/student_attendance_status.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/forms/v1.dart' as forms;
import 'package:googleapis_auth/auth_io.dart';

class GoogleFormService {
  GoogleFormService._();

  static final GoogleFormService instance = GoogleFormService._();

  static const String _envJsonKey = 'GOOGLE_SERVICE_ACCOUNT_JSON';
  static const String _envPathKey = 'GOOGLE_SERVICE_ACCOUNT_PATH';
  static const String _jsonFromDefine =
      String.fromEnvironment(_envJsonKey, defaultValue: '');
  static const String _pathFromDefine =
      String.fromEnvironment(_envPathKey, defaultValue: '');

  Future<String?> createCourseAttendanceForm({
    required Course course,
    required Session session,
    required List<StudentAttendanceStatus> statuses,
  }) async {
    if (kIsWeb) {
      debugPrint('🧾 [GoogleFormService] Google Forms export is unavailable on web.');
      return null;
    }

    if (statuses.isEmpty) {
      debugPrint('🧾 [GoogleFormService] Skipping form creation, no roster data.');
      return null;
    }

    final credentials = await _loadCredentials();
    if (credentials == null) {
      debugPrint(
        '🧾 [GoogleFormService] Missing Google service account credentials. '
        'Set $_envJsonKey or $_envPathKey to enable exports.',
      );
      return null;
    }

    final scopes = <String>[
      forms.FormsApi.formsBodyScope,
      forms.FormsApi.formsResponsesReadonlyScope,
      'https://www.googleapis.com/auth/drive.file',
    ];

    final client = await clientViaServiceAccount(credentials, scopes);
    try {
      final api = forms.FormsApi(client);
      final title =
          '${course.courseName} Attendance ${_formatDate(session.startTime)}';
      final info = forms.Info()
        ..title = title
        ..documentTitle = '$title (${session.id ?? 'session'})';
      final createdForm = await api.forms.create(forms.Form(info: info));
      final summary = statuses
          .map((status) => '${status.studentName}: ${status.statusLabel}')
          .join('\n');
      final request = forms.BatchUpdateFormRequest(requests: [
        forms.Request(
          createItem: forms.CreateItemRequest(
            item: forms.Item(
              title: 'Attendance Summary',
              description: summary,
            ),
            location: forms.Location(index: 0),
          ),
        ),
      ]);
      await api.forms.batchUpdate(request, createdForm.formId!);
      debugPrint(
        '🧾 [GoogleFormService] Created Google Form at '
        '${createdForm.responderUri ?? createdForm.formId}',
      );
      return createdForm.responderUri ?? createdForm.formId;
    } catch (error, stackTrace) {
      debugPrint('🧾 [GoogleFormService] Failed to create form: $error');
      debugPrint('$stackTrace');
      return null;
    } finally {
      client.close();
    }
  }

  Future<ServiceAccountCredentials?> _loadCredentials() async {
    final inlineJson = _jsonFromDefine.isNotEmpty
        ? _jsonFromDefine
        : Platform.environment[_envJsonKey];
    if (inlineJson != null && inlineJson.trim().isNotEmpty) {
      return ServiceAccountCredentials.fromJson(
        jsonDecode(inlineJson) as Map<String, dynamic>,
      );
    }

    final path = _pathFromDefine.isNotEmpty
        ? _pathFromDefine
        : Platform.environment[_envPathKey];
    if (path != null && path.trim().isNotEmpty) {
      final file = File(path.trim());
      if (await file.exists()) {
        final content = await file.readAsString();
        return ServiceAccountCredentials.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
      }
      debugPrint('🧾 [GoogleFormService] Credential file not found at $path.');
    }

    return null;
  }

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }
}
