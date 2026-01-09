import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/models/attendance_record.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:flutter/material.dart';

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
    _attendanceFuture = _fetchAttendance();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final data = await _db.getAllCourses();
    if (!mounted) return;
    setState(() => _courses = data);
  }

  Future<List<AttendanceRecord>> _fetchAttendance() {
    return _db.getAttendance(courseId: _selectedCourseId, includeInvalid: true);
  }

  Future<void> _refreshAttendance() async {
    await _db.purgeExpiredAttendance(const Duration(minutes: 15));
    setState(() {
      _attendanceFuture = _fetchAttendance();
    });
  }

  Future<void> _forceCheckout(int attendanceId) async {
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
                    value: _selectedCourseId,
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(record.studentName),
                          subtitle: Text(_buildSubtitle(record)),
                          trailing: record.isValid
                              ? TextButton(
                                  onPressed: () => _forceCheckout(record.id!),
                                  child: const Text('Check out'),
                                )
                              : const Chip(label: Text('Closed')),
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
    final status = record.isValid ? 'Present' : 'Removed';
    return '$courseLabel\nIn: $inTime | Out: $outTime\nStatus: $status';
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
