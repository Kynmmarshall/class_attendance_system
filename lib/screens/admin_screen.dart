import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/models/attendance_record.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminScreen extends StatefulWidget {
  final String adminName;

  const AdminScreen({super.key, required this.adminName});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late Future<List<AttendanceRecord>> _attendanceFuture;
  List<Course> _courses = [];
  int? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    debugPrint('🛡️ [AdminScreen] init for ${widget.adminName}');
    _attendanceFuture = _fetchAttendance();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final data = await _db.getAllCourses();
    if (!mounted) return;
    debugPrint('🛡️ [AdminScreen] Loaded ${data.length} course filters');
    setState(() => _courses = data);
  }

  Future<List<AttendanceRecord>> _fetchAttendance() {
    debugPrint(
      '🛡️ [AdminScreen] Fetching attendance for course=$_selectedCourseId',
    );
    return _db.getAttendance(
      courseId: _selectedCourseId,
      includeInvalid: true,
      requireFinalConfirmation: true,
    );
  }

  Future<void> _refreshAttendance() async {
    debugPrint('🛡️ [AdminScreen] Refresh requested');
    await _db.purgeExpiredAttendance(const Duration(minutes: 15));
    setState(() {
      _attendanceFuture = _fetchAttendance();
    });
  }

  Future<void> _forceCheckout(int attendanceId) async {
    debugPrint('🛡️ [AdminScreen] Force checkout id=$attendanceId');
    await _db.updateCheckoutTime(attendanceId);
    _refreshAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin • ${widget.adminName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by course',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All courses'),
                      ),
                      ..._courses.map(
                        (course) => DropdownMenuItem<int?>(
                          value: course.id,
                          child: Text(course.courseName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        debugPrint(
                          '🛡️ [AdminScreen] Filter changed -> $value',
                        );
                        _selectedCourseId = value;
                        _attendanceFuture = _fetchAttendance();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services_outlined),
                  tooltip: 'Purge 15+ min absences',
                  onPressed: _refreshAttendance,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAttendance,
              child: FutureBuilder<List<AttendanceRecord>>(
                future: _attendanceFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      '🛡️ [AdminScreen] Error loading attendance ${snapshot.error}',
                    );
                    return Center(
                      child: Text(
                        'Error loading attendance: ${snapshot.error}',
                      ),
                    );
                  }

                  final records = snapshot.data ?? [];
                  if (records.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 160),
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Center(child: Text('No attendance entries yet.')),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: records.length,
                    itemBuilder: (_, index) {
                      final record = records[index];
                      final isFinalized = record.finalConfirmationTime != null;
                      final hasFormLink = (record.formUrl ?? '').isNotEmpty;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(record.studentName),
                          subtitle: Text(_buildSubtitle(record)),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              if (hasFormLink)
                                IconButton(
                                  tooltip: 'Open attendance form',
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () =>
                                      _openFormUrl(record.formUrl!),
                                ),
                              if (isFinalized)
                                const Chip(label: Text('Finalized'))
                              else if (record.isValid)
                                TextButton(
                                  onPressed: () => _forceCheckout(record.id!),
                                  child: const Text('Check out'),
                                )
                              else
                                const Chip(label: Text('Closed')),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(AttendanceRecord record) {
    final inTime = _formatTime(record.checkInTime);
    final outTime = record.checkOutTime != null
        ? _formatTime(record.checkOutTime!)
        : '—';
    final courseLabel = record.courseName ?? 'Course ${record.courseId}';
    final hasFinal = record.finalConfirmationTime != null;
    final status = hasFinal
        ? 'Complete'
        : record.isValid
            ? 'Active'
            : 'Removed';
    final buffer = StringBuffer(
      '$courseLabel\nIn: $inTime | Out: $outTime\nStatus: $status',
    );
    if (record.finalConfirmationTime != null) {
      buffer.write('\nFinal QR: ${_formatTime(record.finalConfirmationTime!)}');
    } else if (record.awaitingFinalConfirmation) {
      buffer.write('\nFinal QR: pending');
    }
    if (record.minutesOutside > 0) {
      buffer.write('\nOutside: ${record.minutesOutside} min');
    }
    return buffer.toString();
  }

  Future<void> _openFormUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      debugPrint('🛡️ [AdminScreen] Invalid form url: $url');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      debugPrint('🛡️ [AdminScreen] Unable to open $url');
    }
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
