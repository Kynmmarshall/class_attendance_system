import 'dart:convert';

import 'package:class_attendance_system/models/user_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class UserAuthService {
  UserAuthService._();

  static const String teacherPasscode = 'TCHR-2048';
  static const String adminPasscode = 'ADMN-4826';
  static const String _storageKey = 'cas.registered.users';

  static final UserAuthService instance = UserAuthService._();

  Future<void> register(UserAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _readUsers(prefs);
    final normalizedEmail = account.email.trim().toLowerCase();
    final alreadyRegistered = users.any(
      (user) => user.email.trim().toLowerCase() == normalizedEmail,
    );
    if (alreadyRegistered) {
      throw const AuthException('This email is already registered.');
    }
    final updated = [...users, account];
    await _persistUsers(prefs, updated);
  }

  Future<UserAccount> authenticate({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _readUsers(prefs);
    final normalizedEmail = email.trim().toLowerCase();
    final user = users.firstWhere(
      (candidate) => candidate.email.trim().toLowerCase() == normalizedEmail,
      orElse: () => throw const AuthException('No account found for that email.'),
    );
    if (user.password != password) {
      throw const AuthException('Incorrect password.');
    }
    return user;
  }

  Future<List<UserAccount>> _readUsers(SharedPreferences prefs) async {
    final stored = prefs.getStringList(_storageKey) ?? const <String>[];
    return stored.map((raw) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return UserAccount.fromMap(map);
      } catch (_) {
        return null;
      }
    }).whereType<UserAccount>().toList();
  }

  Future<void> _persistUsers(
    SharedPreferences prefs,
    List<UserAccount> users,
  ) async {
    final payload = users.map((user) => jsonEncode(user.toMap())).toList();
    await prefs.setStringList(_storageKey, payload);
  }
}
