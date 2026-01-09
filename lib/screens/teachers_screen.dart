import 'package:class_attendance_system/database/database_helper.dart';
import 'package:class_attendance_system/models/course.dart';
import 'package:flutter/material.dart';
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
  final _latController = TextEditingController(text: '3.8480');
  final _longController = TextEditingController(text: '11.5021');
  final _radiusController = TextEditingController(text: '50');
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = DatabaseHelper.instance.getAllCourses();
  }

  void _reload() {
    setState(() {
      _coursesFuture = DatabaseHelper.instance.getAllCourses();
    });
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final course = Course(
      courseName: _courseController.text.trim(),
      latitude: double.parse(_latController.text.trim()),
      longitude: double.parse(_longController.text.trim()),
      radius: double.parse(_radiusController.text.trim()),
    );

    await DatabaseHelper.instance.createCourse(course);
    if (!mounted) return;

    _courseController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Course saved. QR ready to share.')),
    );
    _reload();
  }

  void _showQr(Course course) {
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
              'Lat: ${course.latitude.toStringAsFixed(4)} | Long: ${course.longitude.toStringAsFixed(4)} | Radius: ${course.radius}m',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCourse(Course course) async {
    await DatabaseHelper.instance.deleteCourse(course.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${course.courseName}')));
    _reload();
  }

  @override
  void dispose() {
    _courseController.dispose();
    _latController.dispose();
    _longController.dispose();
    _radiusController.dispose();
    super.dispose();
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
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                          validator: _validateDouble,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _longController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                          validator: _validateDouble,
                        ),
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
                      child: ListTile(
                        title: Text(course.courseName),
                        subtitle: Text(
                          'Lat ${course.latitude}, Long ${course.longitude}, ${course.radius}m radius',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code),
                              tooltip: 'Show QR',
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
