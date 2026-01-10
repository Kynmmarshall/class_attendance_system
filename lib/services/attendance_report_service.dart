import 'dart:typed_data';

import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:class_attendance_system/models/student_attendance_status.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AttendanceReportService {
  AttendanceReportService._();

  static final AttendanceReportService instance = AttendanceReportService._();

  Future<Uint8List> buildSessionReport({
    required Course course,
    required Session session,
    required List<StudentAttendanceStatus> statuses,
  }) async {
    final document = pw.Document();
    final presentCount =
        statuses.where((status) => status.isPresent).length;
    final absentCount = statuses.length - presentCount;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(course, session, presentCount, absentCount),
          pw.SizedBox(height: 16),
          _buildRosterTable(statuses),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildHeader(
    Course course,
    Session session,
    int presentCount,
    int absentCount,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          course.courseName,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'Session ${session.id ?? '-'} • ${_formatDate(session.startTime)}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        if (session.endTime != null)
          pw.Text(
            'Ended ${_formatDate(session.endTime!)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Present: $presentCount • Absent: $absentCount • Total: ${statusCount(presentCount, absentCount)}',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.blueGrey800,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildRosterTable(List<StudentAttendanceStatus> statuses) {
    final rows = statuses.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final status = entry.value;
      return [
        '$index',
        status.studentName,
        status.isPresent ? 'Present' : 'Absent',
        status.checkInTime != null ? _formatTime(status.checkInTime!) : '—',
        status.finalConfirmationTime != null
            ? _formatTime(status.finalConfirmationTime!)
            : '—',
        status.minutesOutside > 0 ? '${status.minutesOutside} min' : '—',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: const [
        '#',
        'Student',
        'Status',
        'Check-in',
        'Final QR',
        'Outside',
      ],
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellHeight: 24,
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  int statusCount(int presentCount, int absentCount) => presentCount + absentCount;

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
