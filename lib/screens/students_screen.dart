import 'dart:async';

import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/models/attendance_record.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:class_attendance_system/services/geofencing.dart';
import 'package:class_attendance_system/theme/app_styles.dart';
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
  late Future<_CourseRosterBundle> _courseRosterFuture;
  final GeofenceService _geoService = GeofenceService();
  Timer? _presenceTimer;
  final Map<int, int> _outsideMinutes = {};
  final Set<int> _announcedSessions = {};
  static const int _maxRegistrations = 6;

  @override
  void initState() {
    super.initState();
    debugPrint('🎓 [StudentDashboard] init for ${widget.studentName}');
    _historyFuture = _buildHistoryFuture();
    _courseRosterFuture = _loadCourseRoster();
    _startPresenceHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceActiveSessions();
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  Future<List<AttendanceRecord>> _buildHistoryFuture() {
    return DatabaseHelper.instance.getAttendance(
      studentName: widget.studentName,
      includeInvalid: true,
    );
  }

  void _refreshHistory() {
    debugPrint(
      '🎓 [StudentDashboard] Refreshing history for ${widget.studentName}',
    );
    setState(() {
      _historyFuture = _buildHistoryFuture();
    });
  }

  void _refreshCourseRoster() {
    setState(() {
      _courseRosterFuture = _loadCourseRoster();
    });
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _runPresenceHeartbeat(),
    );
  }

  Future<_CourseRosterBundle> _loadCourseRoster() async {
    final courses = await DatabaseHelper.instance.getAllCourses();
    final registeredIds = await DatabaseHelper.instance
        .getRegisteredCourseIds(widget.studentName);
    return _CourseRosterBundle(
      courses: courses,
      registeredCourseIds: registeredIds.toSet(),
    );
  }

  Future<void> _handleFullRefresh() async {
    final historyFuture = _buildHistoryFuture();
    final rosterFuture = _loadCourseRoster();
    await DatabaseHelper.instance.purgeExpiredAttendance(
      const Duration(minutes: 15),
    );
    setState(() {
      _historyFuture = historyFuture;
      _courseRosterFuture = rosterFuture;
    });
    await Future.wait([historyFuture, rosterFuture]);
  }

  Future<void> _announceActiveSessions() async {
    try {
      final sessions = await DatabaseHelper.instance
          .getActiveSessionsForStudent(widget.studentName);
      for (final session in sessions) {
        final sessionId = session.id;
        if (sessionId == null || _announcedSessions.contains(sessionId)) {
          continue;
        }
        _announcedSessions.add(sessionId);
        final courseLabel = session.courseName ?? 'Course ${session.courseId}';
        debugPrint(
          '🎓 [StudentDashboard] Notification for session $sessionId ($courseLabel)',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$courseLabel session just started. Please scan in.',
              ),
            ),
          );
        }
      }
    } catch (error) {
      debugPrint('🎓 [StudentDashboard] Session notification failed: $error');
    }
  }

  Future<void> _runPresenceHeartbeat() async {
    if (!mounted) return;
    await _announceActiveSessions();
    try {
      final activeRecords = await DatabaseHelper.instance
          .getActiveAttendanceForStudent(widget.studentName);
      if (activeRecords.isEmpty) {
        _outsideMinutes.clear();
        return;
      }

      for (final record in activeRecords) {
        if (record.id == null) continue;
        final course = await DatabaseHelper.instance.getCourseById(
          record.courseId,
        );
        if (course == null) continue;

        final inRange = await _geoService.isStudentInRange(
          course.latitude,
          course.longitude,
          course.radius,
        );

        final recordId = record.id!;
        if (!inRange) {
          final updated = (_outsideMinutes[recordId] ?? 0) + 1;
          _outsideMinutes[recordId] = updated;
          final Session? session = record.sessionId != null
              ? await DatabaseHelper.instance.getSessionById(record.sessionId!)
              : null;
          final durationMinutes = session?.durationMinutes ?? 60;
          final thresholdMinutes = (durationMinutes / 4)
              .ceil()
              .clamp(1, durationMinutes)
              .toInt();
          await DatabaseHelper.instance.updateMinutesOutside(recordId, updated);
          if (updated >= thresholdMinutes) {
            await DatabaseHelper.instance.updateMinutesOutside(
              recordId,
              updated,
              closeRecord: true,
            );
            _outsideMinutes.remove(recordId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${course.courseName} attendance closed after leaving geofence for $updated minute(s).',
                  ),
                ),
              );
              _refreshHistory();
            }
          }
        } else if ((_outsideMinutes[recordId] ?? 0) != 0) {
          _outsideMinutes[recordId] = 0;
          await DatabaseHelper.instance.updateMinutesOutside(recordId, 0);
        }
      }
    } catch (error) {
      debugPrint('🎓 [StudentDashboard] Presence heartbeat error: $error');
    }
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

  Widget _buildCourseEnrollmentSection() {
    return FutureBuilder<_CourseRosterBundle>(
      future: _courseRosterFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: AppDecorations.glassCard(),
            padding: const EdgeInsets.all(24),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('🎓 [StudentDashboard] Course load error ${snapshot.error}');
          return Container(
            decoration: AppDecorations.glassCard(),
            padding: const EdgeInsets.all(20),
            child: Text('Unable to load courses: ${snapshot.error}'),
          );
        }

        final bundle = snapshot.data ??
          const _CourseRosterBundle(courses: [], registeredCourseIds: <int>{});
        final registeredCount = bundle.registeredCourseIds.length;

        return Container(
          decoration: AppDecorations.glassCard(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course enrollment',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Registered $registeredCount / $_maxRegistrations courses',
                style: Theme.of(context)
                    .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black.withValues(alpha: .6)),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap a course to enroll yourself. You can drop a course anytime before the session starts.',
                style: Theme.of(context)
                    .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black.withValues(alpha: .65)),
              ),
              const SizedBox(height: 16),
              if (bundle.courses.isEmpty)
                const Text('No published courses yet.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bundle.courses.length,
                  itemBuilder: (_, index) {
                    final course = bundle.courses[index];
                    final isRegistered =
                        course.id != null &&
                            bundle.registeredCourseIds.contains(course.id);
                    final actionLabel = isRegistered ? 'Registered' : 'Enroll';
                    final actionColor =
                        isRegistered ? Colors.green : Colors.blueAccent;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: AppDecorations.frostedPanel(opacity: .9),
                      child: ListTile(
                        title: Text(course.courseName),
                        subtitle: Text(
                          'Lat ${course.latitude.toStringAsFixed(4)} | Long ${course.longitude.toStringAsFixed(4)}',
                        ),
                        trailing: TextButton(
                          onPressed: () => _handleCourseToggle(
                            course,
                            !isRegistered,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: actionColor,
                          ),
                          child: Text(actionLabel),
                        ),
                        onTap: () => _handleCourseToggle(
                          course,
                          !isRegistered,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttendanceSection() {
    return FutureBuilder<List<AttendanceRecord>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: AppDecorations.glassCard(),
            padding: const EdgeInsets.all(24),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('🎓 [StudentDashboard] History error ${snapshot.error}');
          return Container(
            decoration: AppDecorations.glassCard(),
            padding: const EdgeInsets.all(20),
            child: Text('Unable to load attendance: ${snapshot.error}'),
          );
        }

        final records = snapshot.data ?? [];
        return Container(
          decoration: AppDecorations.glassCard(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance timeline',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 56,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No attendance logs yet. Tap the scanner icon to get started.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  itemBuilder: (_, index) => _AttendanceCard(
                    record: records[index],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCourseToggle(Course course, bool enroll) async {
    if (course.id == null) return;
    try {
      if (enroll) {
        final currentCount = await DatabaseHelper.instance
            .getRegistrationCount(widget.studentName);
        if (!mounted) return;
        if (currentCount >= _maxRegistrations) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have the maximum number of courses.'),
            ),
          );
          return;
        }
        await DatabaseHelper.instance.addRosterStudent(
          course.id!,
          widget.studentName,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrolled in ${course.courseName}.')),
        );
      } else {
        await DatabaseHelper.instance.removeRosterEntryByCourse(
          course.id!,
          widget.studentName,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${course.courseName} from your list.')),
        );
      }
      _refreshCourseRoster();
    } catch (error) {
      debugPrint('🎓 [StudentDashboard] Enrollment toggle failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update enrollment: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Welcome, ${widget.studentName}',style: const TextStyle(color: Colors.white),),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner,color: Colors.white,),
            tooltip: 'Scan QR',
            onPressed: _openScanner,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.royalTwilight),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.royalTwilight),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleFullRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  decoration: AppDecorations.glassCard(opacity: .85),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good to see you, ${widget.studentName}! 👋',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enroll into courses, stay inside the geofence, and lock in both QR scans to complete attendance.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.black.withValues(alpha: .65)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildCourseEnrollmentSection(),
                const SizedBox(height: 24),
                _buildAttendanceSection(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        backgroundColor: const Color.fromARGB(255, 226, 211, 250),
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
    final awaitingFinal = record.awaitingFinalConfirmation;
    final statusColor = awaitingFinal
        ? Colors.amber
        : record.isValid
        ? Colors.green
        : Colors.blueGrey;
    final statusText = awaitingFinal
        ? 'Awaiting final QR'
        : record.isValid
        ? 'Active'
        : 'Closed';
    final subtitle = StringBuffer(
      'Checked in at ${_formatTime(record.checkInTime)}',
    );
    if (record.checkOutTime != null) {
      subtitle.write(' • Checked out at ${_formatTime(record.checkOutTime!)}');
    }
    if (record.finalConfirmationTime != null) {
      subtitle.write(
        ' • Final QR ${_formatTime(record.finalConfirmationTime!)}',
      );
    }
    if (record.minutesOutside > 0) {
      subtitle.write(' • Outside ${record.minutesOutside} min');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppDecorations.frostedPanel(opacity: .92),
      child: ListTile(
        title: Text(
          record.courseName ?? 'Course ${record.courseId}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle.toString()),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              record.isValid ? Icons.verified : Icons.info,
              color: statusColor,
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
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

class _CourseRosterBundle {
  final List<Course> courses;
  final Set<int> registeredCourseIds;

  const _CourseRosterBundle({
    required this.courses,
    required this.registeredCourseIds,
  });
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
      debugPrint(
        '📷 [StudentScan] Parsed payload course=${payload.courseId} session=${payload.sessionId} phase=${payload.phase}',
      );
      final Course? course = await DatabaseHelper.instance.getCourseById(
        payload.courseId,
      );
      if (course == null) {
        debugPrint('📷 [StudentScan] Course ${payload.courseId} not found');
        throw const FormatException('Course not recognized');
      }

      final registered = await DatabaseHelper.instance.isStudentRegistered(
        payload.courseId,
        widget.studentName,
      );
      if (!registered) {
        debugPrint('📷 [StudentScan] ${widget.studentName} not in roster');
        await _showDialog(
          title: 'Not Registered',
          message:
              'You are not listed on the roster for ${course.courseName}. Contact your lecturer.',
        );
        return;
      }

      final inRange = await _geoService.isStudentInRange(
        course.latitude,
        course.longitude,
        course.radius,
      );
      debugPrint('📷 [StudentScan] Geofence validation result: $inRange');

      if (!inRange) {
        await _showDialog(
          title: 'Access Denied',
          message:
              'You are outside the classroom boundary. Attendance not recorded.',
        );
        return;
      }

      if (payload.phase == _QrPhase.finalize) {
        await _handleFinalScan(payload, course);
      } else {
        await _handleStartScan(payload, course);
      }
    } catch (error) {
      debugPrint('📷 [StudentScan] Error while scanning: $error');
      await _showDialog(
        title: 'Error',
        message: 'Invalid QR Code or permissions issue: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleStartScan(_QrPayload payload, Course course) async {
    final Session? session = payload.sessionId != null
        ? await DatabaseHelper.instance.getSessionById(payload.sessionId!)
        : await DatabaseHelper.instance.getActiveSessionForCourse(
            payload.courseId,
          );
    if (session == null || !(session.isActive)) {
      await _showDialog(
        title: 'Session Closed',
        message: 'No active class session for ${course.courseName}.',
      );
      return;
    }

    final alreadyChecked = await DatabaseHelper.instance.hasActiveAttendance(
      payload.courseId,
      widget.studentName,
      sessionId: session.id,
    );

    if (alreadyChecked) {
      await _showDialog(
        title: 'Already Checked In',
        message: 'You already have active attendance for ${course.courseName}.',
      );
      return;
    }

    await DatabaseHelper.instance.markAttendance(
      courseId: payload.courseId,
      student: widget.studentName,
      isValid: true,
      sessionId: session.id,
    );
    debugPrint('📷 [StudentScan] Attendance logged for ${widget.studentName}');

    await _showDialog(
      title: 'Success',
      message: 'Attendance marked for ${course.courseName}.',
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _handleFinalScan(_QrPayload payload, Course course) async {
    if (payload.sessionId == null) {
      throw const FormatException('Final QR missing session reference');
    }
    final Session? session = await DatabaseHelper.instance.getSessionById(
      payload.sessionId!,
    );
    if (session == null) {
      throw const FormatException('Session not found.');
    }
    if (session.isActive) {
      await _showDialog(
        title: 'Too Early',
        message: 'Final QR unlocks after the lecturer ends the session.',
      );
      return;
    }

    final expiresAt = session.finalQrExpiresAt;
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await _showDialog(
        title: 'QR Closed',
        message:
            'The final QR grace period has ended. Please speak with your lecturer.',
      );
      return;
    }

    final record = await DatabaseHelper.instance.getActiveAttendanceRecord(
      courseId: payload.courseId,
      studentName: widget.studentName,
      sessionId: payload.sessionId,
    );

    if (record == null) {
      await _showDialog(
        title: 'No Active Attendance',
        message: 'We could not find your check-in for ${course.courseName}.',
      );
      return;
    }

    await DatabaseHelper.instance.recordFinalConfirmation(
      courseId: payload.courseId,
      sessionId: payload.sessionId!,
      studentName: widget.studentName,
    );
    await _showDialog(
      title: 'Class Complete',
      message: 'Final attendance confirmed for ${course.courseName}.',
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _showDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(title: Text(title), content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Scan QR', style: TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.emberGlow),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.emberGlow),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: MobileScanner(
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
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: true,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: AppDecorations.glassCard(opacity: .85),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hold steady inside the frame',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stay inside the classroom geofence while scanning both start and final QR codes.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                              ?.copyWith(color: Colors.black.withValues(alpha: .65)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isProcessing)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: AppDecorations.frostedPanel(opacity: .95),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(strokeWidth: 2),
                          SizedBox(width: 12),
                          Text('Validating geofence...'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrPayload {
  final int courseId;
  final int? sessionId;
  final _QrPhase phase;
  final double latitude;
  final double longitude;
  final double radius;

  _QrPayload({
    required this.courseId,
    required this.sessionId,
    required this.phase,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory _QrPayload.parse(String rawValue) {
    final segments = rawValue.split(',');
    final data = <String, String>{};
    for (final segment in segments) {
      final parts = segment.split(':');
      if (parts.length != 2) continue;
      data[parts[0].trim()] = parts[1].trim();
    }

    if (!data.containsKey('CourseID')) {
      throw const FormatException('Missing CourseID in QR payload');
    }

    final sessionId = data['SessionID'] != null
        ? int.tryParse(data['SessionID']!)
        : null;
    final phaseLabel = (data['Phase'] ?? 'start').toLowerCase();
    final phase = phaseLabel == 'end' || phaseLabel == 'final'
        ? _QrPhase.finalize
        : _QrPhase.start;

    double readDouble(String key) {
      final value = data[key];
      if (value == null) {
        throw FormatException('Missing $key in QR payload');
      }
      return double.parse(value);
    }

    final payload = _QrPayload(
      courseId: int.parse(data['CourseID']!),
      sessionId: sessionId,
      phase: phase,
      latitude: readDouble('Lat'),
      longitude: readDouble('Long'),
      radius: readDouble('Rad'),
    );
    debugPrint('📷 [StudentScan] Payload parsed -> $payload');
    return payload;
  }

  @override
  String toString() {
    return 'course:$courseId session:$sessionId phase:$phase';
  }
}

enum _QrPhase { start, finalize }
