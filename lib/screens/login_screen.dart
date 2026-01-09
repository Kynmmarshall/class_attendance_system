import 'package:class_attendance_system/screens/admin_screen.dart';
import 'package:class_attendance_system/screens/students_screen.dart';
import 'package:class_attendance_system/screens/teachers_screen.dart';
import 'package:flutter/material.dart';

enum UserRole { student, teacher, admin }

extension on UserRole {
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    debugPrint('🔐 [LoginScreen] Continue tapped name=$name role=$_role');
    late Widget destination;

    switch (_role) {
      case UserRole.student:
        destination = StudentDashboard(studentName: name);
        break;
      case UserRole.teacher:
        destination = TeacherScreen(teacherName: name);
        break;
      case UserRole.admin:
        destination = AdminScreen(adminName: name);
        break;
    }

    debugPrint('🔐 [LoginScreen] Navigating to ${destination.runtimeType}');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Attendance',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan QR codes, validate with geofencing, and monitor in real time.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Display name / email',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<UserRole>(
                          decoration: const InputDecoration(
                            labelText: 'I am logging in as',
                          ),
                          // ignore: deprecated_member_use
                          value: _role,
                          items: UserRole.values
                              .map(
                                (role) => DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text(role.label),
                                ),
                              )
                              .toList(),
                          onChanged: (role) {
                            if (role != null) {
                              debugPrint(
                                '🔐 [LoginScreen] Role changed -> $role',
                              );
                              setState(() => _role = role);
                            }
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleContinue,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
