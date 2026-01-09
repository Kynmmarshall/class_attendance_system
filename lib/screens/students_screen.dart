import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/models/attendance_record.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/services/geofencing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StudentDashboard extends StatefulWidget {
  final String studentName;

  const StudentDashboard({super.key, required this.studentName});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  late Future<List<AttendanceRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('🎓 [StudentDashboard] init for ${widget.studentName}');
    _refreshHistory();
  }

  void _refreshHistory() {
    debugPrint(
      '🎓 [StudentDashboard] Refreshing history for ${widget.studentName}',
    );
    setState(() {
      _historyFuture = DatabaseHelper.instance.getAttendance(
        studentName: widget.studentName,
        includeInvalid: true,
      );
    });
  }

  Future<void> _openScanner() async {
    debugPrint(
      '🎓 [StudentDashboard] Opening scanner for ${widget.studentName}',
    );
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StudentScanScreen(studentName: widget.studentName),
      ),
    );

    if (updated == true) {
      debugPrint(
        '🎓 [StudentDashboard] Scanner reported updates; purging expired attendance',
      );
      await DatabaseHelper.instance.purgeExpiredAttendance(
        const Duration(minutes: 15),
      );
      _refreshHistory();
    }
    debugPrint('🎓 [StudentDashboard] Scanner closed updated=$updated');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.studentName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR',
            onPressed: _openScanner,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await DatabaseHelper.instance.purgeExpiredAttendance(
            const Duration(minutes: 15),
          );
          _refreshHistory();
        },
        child: FutureBuilder<List<AttendanceRecord>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              debugPrint(
                '🎓 [StudentDashboard] History error ${snapshot.error}',
              );
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text('Unable to load history: ${snapshot.error}'),
                  ),
                ],
              );
            }

            final records = snapshot.data ?? [];
            if (records.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No attendance logs yet. Tap the scanner icon to get started.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (_, index) =>
                  _AttendanceCard(record: records[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.qr_code_2_outlined),
        label: const Text('Scan Now'),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;

  const _AttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final statusColor = record.isValid ? Colors.green : Colors.orange;
    final statusText = record.isValid ? 'Active' : 'Closed';
    final subtitle = StringBuffer(
      'Checked in at ${_formatTime(record.checkInTime)}',
    );
    if (record.checkOutTime != null) {
      subtitle.write(' • Checked out at ${_formatTime(record.checkOutTime!)}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(record.courseName ?? 'Course ${record.courseId}'),
        subtitle: Text(subtitle.toString()),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              record.isValid ? Icons.verified : Icons.info,
              color: statusColor,
            ),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }
}

class StudentScanScreen extends StatefulWidget {
  final String studentName;

  const StudentScanScreen({super.key, required this.studentName});

  @override
  State<StudentScanScreen> createState() => _StudentScanScreenState();
}

class _StudentScanScreenState extends State<StudentScanScreen> {
  final GeofenceService _geoService = GeofenceService();
  bool _isProcessing = false;

  Future<void> _handleScan(String rawData) async {
    if (_isProcessing) return;
    debugPrint('📷 [StudentScan] Handling QR payload: $rawData');
    setState(() => _isProcessing = true);

    try {
      final payload = _QrPayload.parse(rawData);
      debugPrint('📷 [StudentScan] Parsed payload course=${payload.courseId}');
      final Course? course = await DatabaseHelper.instance.getCourseById(
        payload.courseId,
      );
      if (course == null) {
        debugPrint('📷 [StudentScan] Course ${payload.courseId} not found');
        throw const FormatException('Course not recognized');
      }

      final inRange = await _geoService.isStudentInRange(
        course.latitude,
        course.longitude,
        course.radius,
      );
      debugPrint('📷 [StudentScan] Geofence validation result: $inRange');

      if (!inRange) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Access Denied'),
            content: Text(
              'You are outside the classroom boundary. Attendance not recorded.',
            ),
          ),
        );
        return;
      }

      final alreadyChecked = await DatabaseHelper.instance.hasActiveAttendance(
        payload.courseId,
        widget.studentName,
      );

      if (alreadyChecked) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Already Checked In'),
            content: Text(
              'You already have active attendance for ${course.courseName}.',
            ),
          ),
        );
        return;
      }

      await DatabaseHelper.instance.markAttendance(
        payload.courseId,
        widget.studentName,
        true,
      );
      debugPrint(
        '📷 [StudentScan] Attendance logged for ${widget.studentName}',
      );

      if (!mounted) return;
      final title = 'Success';
      final message = 'Attendance marked for ${course.courseName}.';

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(title: Text(title), content: Text(message)),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('📷 [StudentScan] Error while scanning: $error');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('Invalid QR Code or permissions issue: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final payload = barcode.rawValue;
                if (payload != null) {
                  debugPrint(
                    '📷 [StudentScan] Barcode detected, forwarding to handler',
                  );
                  _handleScan(payload);
                  break;
                }
              }
            },
          ),
          if (_isProcessing)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 12),
                        Text('Validating geofence...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QrPayload {
  final int courseId;
  final double latitude;
  final double longitude;
  final double radius;

  _QrPayload({
    required this.courseId,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory _QrPayload.parse(String rawValue) {
    final segments = rawValue.split(',');
    if (segments.length < 4) {
      throw const FormatException('Unexpected QR payload');
    }
    debugPrint('📷 [StudentScan] Raw segments: $segments');

    int readCourseId() {
      final part = segments[0].split(':');
      if (part.length != 2) throw const FormatException('Missing course id');
      return int.parse(part[1]);
    }

    double readDouble(int index) {
      final part = segments[index].split(':');
      if (part.length != 2) throw const FormatException('Malformed value');
      return double.parse(part[1]);
    }

    final payload = _QrPayload(
      courseId: readCourseId(),
      latitude: readDouble(1),
      longitude: readDouble(2),
      radius: readDouble(3),
    );
    debugPrint('📷 [StudentScan] Payload parsed -> course=${payload.courseId}');
    return payload;
  }
}
