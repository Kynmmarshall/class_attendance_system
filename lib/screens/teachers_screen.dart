import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:class_attendance_system/models/roster_entry.dart';
import 'package:class_attendance_system/models/session.dart';
import 'package:class_attendance_system/services/google_form_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeacherScreen extends StatefulWidget {
  final String teacherName;

  const TeacherScreen({super.key, required this.teacherName});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _radiusController = TextEditingController(text: '50');
  late Future<List<Course>> _coursesFuture;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🧑‍🏫 [TeacherScreen] init for ${widget.teacherName}');
    _coursesFuture = DatabaseHelper.instance.getAllCourses();
    _captureLocation();
  }

  @override
  void dispose() {
    _courseController.dispose();
    _latController.dispose();
    _longController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _reloadCourses() {
    debugPrint('🧑‍🏫 [TeacherScreen] Reloading courses');
    setState(() {
      _coursesFuture = DatabaseHelper.instance.getAllCourses();
    });
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latController.text.trim().isEmpty ||
        _longController.text.trim().isEmpty) {
      await _captureLocation();
      if (_latController.text.trim().isEmpty ||
          _longController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location is required to create a course.'),
            ),
          );
        }
        return;
      }
    }

    final course = Course(
      courseName: _courseController.text.trim(),
      latitude: double.parse(_latController.text.trim()),
      longitude: double.parse(_longController.text.trim()),
      radius: double.parse(_radiusController.text.trim()),
    );

    try {
      await DatabaseHelper.instance.createCourse(course);
      if (!mounted) return;
      _courseController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${course.courseName} saved. QR ready.')),
      );
      _reloadCourses();
    } catch (error) {
      debugPrint('🧑‍🏫 [TeacherScreen] Failed to save course: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save course: $error')),
        );
      }
    }
  }

  void _showQr(Course course) {
    debugPrint('🧑‍🏫 [TeacherScreen] Showing QR for course ${course.id}');
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              course.courseName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: course.buildQrPayload(),
              version: QrVersions.auto,
              size: 220,
            ),
            const SizedBox(height: 12),
            Text(
              'Lat: ${course.latitude.toStringAsFixed(4)} • '
              'Long: ${course.longitude.toStringAsFixed(4)} • '
              'Radius: ${course.radius.toStringAsFixed(1)}m',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCourse(Course course) async {
    if (course.id == null) return;
    debugPrint('🧑‍🏫 [TeacherScreen] Deleting course ${course.id}');
    await DatabaseHelper.instance.deleteCourse(course.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${course.courseName}.')),
    );
    _reloadCourses();
  }

  Future<void> _captureLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Location permission denied';
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _latController.text = position.latitude.toStringAsFixed(6);
      _longController.text = position.longitude.toStringAsFixed(6);
      debugPrint(
        '🧑‍🏫 [TeacherScreen] Captured lat=${position.latitude}, long=${position.longitude}',
      );
    } catch (error) {
      debugPrint('🧑‍🏫 [TeacherScreen] Failed to capture location: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to fetch location: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hello, ${widget.teacherName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Course & QR',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _courseController,
                    decoration: const InputDecoration(
                      labelText: 'Course title (e.g., ICT 101)',
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Latitude (auto)',
                          ),
                          validator: _validateDouble,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _longController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Longitude (auto)',
                          ),
                          validator: _validateDouble,
                        ),
                      ),
                      IconButton(
                        icon: _isLocating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        tooltip: 'Use current location',
                        onPressed: _isLocating ? null : _captureLocation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radius (meters)',
                    ),
                    validator: _validateDouble,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveCourse,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Course'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Published Courses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Course>>(
              future: _coursesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint(
                    '🧑‍🏫 [TeacherScreen] Error loading courses ${snapshot.error}',
                  );
                  return Text('Unable to load courses: ${snapshot.error}');
                }

                final courses = snapshot.data ?? [];
                if (courses.isEmpty) {
                  return const Text(
                    'No courses yet. Add one above to generate a QR.',
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: courses.length,
                  itemBuilder: (_, index) {
                    final course = courses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(course.courseName),
                              subtitle: Text(
                                'Lat ${course.latitude.toStringAsFixed(5)}, '
                                'Long ${course.longitude.toStringAsFixed(5)}, '
                                '${course.radius.toStringAsFixed(1)}m radius',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code),
                                    tooltip: 'Show geofence QR',
                                    onPressed: () => _showQr(course),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete course',
                                    onPressed: () => _deleteCourse(course),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            _SessionControl(course: course),
                            const SizedBox(height: 16),
                            _RosterViewer(course: course),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _validateDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return double.tryParse(value.trim()) == null
        ? 'Enter a valid number'
        : null;
  }
}

class _SessionControl extends StatefulWidget {
  final Course course;

  const _SessionControl({required this.course});

  @override
  State<_SessionControl> createState() => _SessionControlState();
}

class _SessionControlState extends State<_SessionControl> {
  Session? _session;
  bool _loading = true;
  bool _busy = false;
  int _durationMinutes = 90;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    if (widget.course.id == null) return;
    final latest = await DatabaseHelper.instance.getLatestSessionForCourse(
      widget.course.id!,
    );
    if (!mounted) return;
    setState(() {
      _session = latest;
      _loading = false;
    });
  }

  Future<void> _startSession() async {
    if (widget.course.id == null) return;
    setState(() => _busy = true);
    try {
      final sessionId = await DatabaseHelper.instance.startSession(
        courseId: widget.course.id!,
        durationMinutes: _durationMinutes,
      );
      final fresh = await DatabaseHelper.instance.getSessionById(sessionId);
      if (!mounted) return;
      setState(() => _session = fresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session started for ${widget.course.courseName}. Share the live QR now.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('🧑‍🏫 [TeacherSession] Start failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start session: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _endSession() async {
    final sessionId = _session?.id;
    if (sessionId == null) return;
    setState(() => _busy = true);
    try {
      await DatabaseHelper.instance.endSession(sessionId);
      final sessionAfterEnd = await DatabaseHelper.instance.getSessionById(sessionId);
      final sessionForExport = sessionAfterEnd ?? _session;
      String? formUrl;
      if (sessionForExport != null) {
        formUrl = await _exportAttendanceSummary(sessionForExport);
        if (formUrl != null) {
          await DatabaseHelper.instance.updateSessionFormUrl(
            sessionForExport.id!,
            formUrl,
          );
        }
      }
      final refreshed = await DatabaseHelper.instance.getSessionById(sessionId);
      if (!mounted) return;
      setState(() => _session = refreshed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            formUrl != null
                ? 'Session ended and attendance form generated for ${widget.course.courseName}.'
                : 'Session ended. Final QR unlocked for ${widget.course.courseName}.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('🧑‍🏫 [TeacherSession] End failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to end session: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _exportAttendanceSummary(Session session) async {
    final courseId = widget.course.id;
    final currentSessionId = session.id;
    if (courseId == null || currentSessionId == null) {
      debugPrint('🧑‍🏫 [TeacherSession] Skipping export, missing IDs.');
      return null;
    }

    try {
      final statuses = await DatabaseHelper.instance.getStudentStatusesForSession(
        courseId: courseId,
        sessionId: currentSessionId,
      );
      if (statuses.isEmpty) {
        debugPrint('🧑‍🏫 [TeacherSession] No roster data to export for course=$courseId.');
        return null;
      }
      return await GoogleFormService.instance.createCourseAttendanceForm(
        course: widget.course,
        session: session,
        statuses: statuses,
      );
    } catch (error) {
      debugPrint('🧑‍🏫 [TeacherSession] Google Form export failed: $error');
      return null;
    }
  }

  Future<void> _openFormUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      debugPrint('🧑‍🏫 [TeacherSession] Invalid form url: $url');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      debugPrint('🧑‍🏫 [TeacherSession] Unable to open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseId = widget.course.id;
    if (courseId == null) {
      return const Text('Save course to enable sessions.');
    }

    final isActive = _session?.isActive == true;
    final hasHistory = _session != null && _session!.id != null;
    final hasFormLink = (_session?.formUrl ?? '').isNotEmpty;
    final startLabel = _session?.startTime != null
        ? _formatTime(_session!.startTime)
        : null;
    final plannedEnd = _session?.startTime != null
        ? _formatTime(
            _session!.startTime.add(
              Duration(minutes: _session!.durationMinutes),
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Session Control',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isActive)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(label: Text('Active')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator()
        else ...[
          if (!isActive)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _durationMinutes,
                    items: const [45, 60, 90, 120, 150, 180]
                        .map(
                          (minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text('$minutes min'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _durationMinutes = value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'Planned duration',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _startSession,
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text('Start'),
                ),
              ],
            ),
          if (isActive && _session?.id != null) ...[
            const SizedBox(height: 8),
            if (startLabel != null && plannedEnd != null)
              Text('Started $startLabel • Ends $plannedEnd'),
            const SizedBox(height: 4),
            Text(
              'Share this live QR for check-in:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: widget.course.buildQrPayload(
                  sessionId: _session!.id,
                  phase: 'start',
                ),
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _endSession,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End Session'),
              ),
            ),
          ],
          if (!isActive && hasHistory && _session?.endTime != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Final QR — students must scan before leaving:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    data: widget.course.buildQrPayload(
                      sessionId: _session!.id,
                      phase: 'end',
                    ),
                    version: QrVersions.auto,
                    size: 200,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ended at ${_formatTime(_session!.endTime!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _startSession,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Start new session'),
                ),
                if (hasFormLink) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openFormUrl(_session!.formUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Attendance Form'),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }
}

class _RosterViewer extends StatelessWidget {
  final Course course;

  const _RosterViewer({required this.course});

  @override
  Widget build(BuildContext context) {
    if (course.id == null) {
      return const Text('Save the course to view enrolled students.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roster (students self-register)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<RosterEntry>>(
          future: DatabaseHelper.instance.getRosterEntries(course.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              debugPrint('🧑‍🏫 [Roster] Load error ${snapshot.error}');
              return Text('Unable to load roster: ${snapshot.error}');
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const Text('No students enrolled yet.');
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (_, index) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(entries[index].studentName),
              ),
            );
          },
        ),
      ],
    );
  }
}

