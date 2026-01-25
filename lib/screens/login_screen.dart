import 'package:class_attendance_system/screens/admin_screen.dart';
import 'package:class_attendance_system/screens/register_screen.dart';
import 'package:class_attendance_system/screens/students_screen.dart';
import 'package:class_attendance_system/screens/teachers_screen.dart';
import 'package:class_attendance_system/services/user_auth_service.dart';
import 'package:class_attendance_system/widgets/aurora_background.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _rememberDevice = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final account = await UserAuthService.instance.authenticate(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final destination = _resolveDestination(
        name: account.fullName,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => destination.widget),
      );
      if (destination.message != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(destination.message!)));
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  _Destination _resolveDestination({required String name, required String code}) {
    final normalized = code.toUpperCase();
    if (normalized == UserAuthService.adminPasscode) {
      return _Destination(
        widget: AdminScreen(adminName: name),
        message: 'Admin console unlocked.',
      );
    }
    if (normalized == UserAuthService.teacherPasscode) {
      return _Destination(
        widget: TeacherScreen(teacherName: name),
        message: 'Lecturer workspace unlocked.',
      );
    }
    final fallbackMessage = code.isEmpty
        ? null
        : 'Guarded console code invalid. Entering student view.';
    return _Destination(
      widget: StudentDashboard(studentName: name),
      message: fallbackMessage,
    );
  }

  Future<void> _openRegister() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (email != null && email.trim().isNotEmpty) {
      _emailController.text = email.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: Colors.white.withValues(alpha: .92),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 40,
                        offset: Offset(0, 30),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Smart attendance hub',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Register once. Unlock lecturer/admin consoles with secure codes.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) =>
                                value == null || value.isEmpty
                                    ? 'Password is required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'Admin / Lecturer code (optional)',
                              prefixIcon: const Icon(Icons.key_outlined),
                              suffixIcon: IconButton(
                                tooltip: 'Reveal preset codes',
                                icon: const Icon(Icons.info_outline),
                                onPressed: () {
                                  final info =
                                      'Lecturer: ${UserAuthService.teacherPasscode}\nAdmin: ${UserAuthService.adminPasscode}';
                                  showDialog<void>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Guarded console codes'),
                                      content: Text(info),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _rememberDevice,
                            onChanged: (value) => setState(() => _rememberDevice = value),
                            title: const Text('Remember this device'),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _handleLogin,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(_loading ? 'Authenticating...' : 'Enter campus'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Need an account?'),
                              TextButton(
                                onPressed: _loading ? null : _openRegister,
                                child: const Text('Create one'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  final Widget widget;
  final String? message;

  const _Destination({required this.widget, this.message});
}
